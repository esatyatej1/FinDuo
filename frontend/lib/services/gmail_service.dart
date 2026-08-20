import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/gmail/v1.dart' as gmail;
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Result of parsing a PhonePe/bank email
class GmailTransaction {
  final double amount;
  final String date; // YYYY-MM-DD
  final String merchant;
  final String refNo;
  final String subject;
  final String rawBody;
  bool selected;

  GmailTransaction({
    required this.amount,
    required this.date,
    required this.merchant,
    required this.refNo,
    required this.subject,
    required this.rawBody,
    this.selected = true,
  });
}

class _GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();
  _GoogleAuthClient(this._headers);
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }
}

class GmailService {
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [gmail.GmailApi.gmailReadonlyScope],
  );

  static GoogleSignInAccount? _currentUser;

  static bool get isSignedIn => _currentUser != null;

  /// Sign in with Google — returns true on success
  static Future<bool> signIn() async {
    try {
      _currentUser = await _googleSignIn.signIn();
      return _currentUser != null;
    } catch (e) {
      return false;
    }
  }

  static Future<void> signOut() async {
    await _googleSignIn.signOut();
    _currentUser = null;
  }

  static Future<bool> tryRestoreSession() async {
    _currentUser = await _googleSignIn.signInSilently();
    return _currentUser != null;
  }

  /// Fetch PhonePe + bank alert emails and parse transactions
  static Future<List<GmailTransaction>> fetchTransactions({
    required DateTime from,
    required DateTime to,
  }) async {
    if (_currentUser == null) return [];

    final auth = await _currentUser!.authentication;
    final client = _GoogleAuthClient({
      'Authorization': 'Bearer ${auth.accessToken}',
    });
    final gmailApi = gmail.GmailApi(client);

    final fromTs = from.millisecondsSinceEpoch ~/ 1000;
    final toTs = to.millisecondsSinceEpoch ~/ 1000;

    // Search query: PhonePe emails + bank UPI alerts
    const query =
        '(from:noreply@phonepe.com OR from:no-reply@hdfcbank.net OR '
        'from:alerts@axisbank.com OR from:SBIePay OR "PhonePe" OR "UPI") '
        'subject:(payment OR debit OR "money sent" OR "paid")';

    final results = <GmailTransaction>[];

    try {
      final listResult = await gmailApi.users.messages.list(
        'me',
        q: '$query after:$fromTs before:$toTs',
        maxResults: 200,
      );

      final messages = listResult.messages ?? [];

      for (final msg in messages) {
        try {
          final full = await gmailApi.users.messages.get(
            'me',
            msg.id!,
            format: 'full',
          );
          final parsed = _parseEmail(full);
          if (parsed != null) results.add(parsed);
        } catch (_) {}
      }
    } catch (_) {}

    client.close();
    results.sort((a, b) => b.date.compareTo(a.date));
    return results;
  }

  static GmailTransaction? _parseEmail(gmail.Message message) {
    final headers = message.payload?.headers ?? [];
    final subject =
        headers
            .firstWhere(
              (h) => h.name == 'Subject',
              orElse: () => gmail.MessagePartHeader(),
            )
            .value ??
        '';
    final from =
        headers
            .firstWhere(
              (h) => h.name == 'From',
              orElse: () => gmail.MessagePartHeader(),
            )
            .value ??
        '';
    final dateHeader =
        headers
            .firstWhere(
              (h) => h.name == 'Date',
              orElse: () => gmail.MessagePartHeader(),
            )
            .value ??
        '';

    // Only debit / payment emails
    final subjectLower = subject.toLowerCase();
    if (!subjectLower.contains('debit') &&
        !subjectLower.contains('payment') &&
        !subjectLower.contains('paid') &&
        !subjectLower.contains('sent') &&
        !subjectLower.contains('money'))
      return null;

    final body = _extractBody(message.payload);
    if (body.isEmpty) return null;

    final amount = _extractAmount(body.isEmpty ? subject : body);
    if (amount == null || amount <= 0) return null;

    final date = _parseDate(dateHeader);
    final merchant = _extractMerchant(body, subject);
    final ref = _extractRef(body);

    return GmailTransaction(
      amount: amount,
      date: date,
      merchant: merchant,
      refNo: ref,
      subject: subject,
      rawBody: body.length > 500 ? '${body.substring(0, 500)}...' : body,
    );
  }

  static String _extractBody(gmail.MessagePart? part) {
    if (part == null) return '';
    if (part.body?.data != null) {
      try {
        final decoded = utf8.decode(
          base64Url.decode(
            part.body!.data!.replaceAll('-', '+').replaceAll('_', '/'),
          ),
        );
        // Strip HTML tags
        return decoded
            .replaceAll(RegExp(r'<[^>]*>'), ' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
      } catch (_) {}
    }
    // Recurse into parts
    for (final subPart in (part.parts ?? [])) {
      final text = _extractBody(subPart);
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  static double? _extractAmount(String text) {
    final patterns = [
      RegExp(
        r'(?:INR|Rs\.?|₹)\s*([0-9,]+(?:\.[0-9]{1,2})?)',
        caseSensitive: false,
      ),
      RegExp(
        r'([0-9,]+(?:\.[0-9]{1,2})?)\s*(?:INR|Rs\.?)',
        caseSensitive: false,
      ),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(text);
      if (m != null) {
        final val = double.tryParse(m.group(1)?.replaceAll(',', '') ?? '');
        if (val != null && val > 0) return val;
      }
    }
    return null;
  }

  static String _parseDate(String dateHeader) {
    try {
      // RFC 2822 date parse
      final dt = DateTime.parse(
        dateHeader.replaceAll(RegExp(r'\s+\([A-Z]+\)$'), '').trim(),
      );
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      final now = DateTime.now();
      return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    }
  }

  static String _extractMerchant(String body, String subject) {
    final patterns = [
      RegExp(
        r'(?:to|paid to|payment to)\s+([A-Za-z0-9 &\-_]{2,40}?)(?:\s+(?:on|via|ref|for)|[\.,]|$)',
        caseSensitive: false,
      ),
      RegExp(r'VPA[:\s]+([^\s,\.@]+)', caseSensitive: false),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(body);
      if (m != null) {
        final v = m.group(1)?.trim() ?? '';
        if (v.length > 2) return v;
      }
    }
    // Fall back to subject
    final subj = subject
        .replaceAll(
          RegExp(
            r'(?:payment|debit|sent|paid|money|successful|of|INR|Rs|₹|[0-9,.])',
            caseSensitive: false,
          ),
          '',
        )
        .trim();
    return subj.length > 2 ? subj : 'PhonePe/UPI';
  }

  static String _extractRef(String body) {
    final p = RegExp(
      r'(?:UPI Ref|Ref No|Transaction ID|Txn ID|Ref)[:\s#]+([0-9A-Za-z]{6,25})',
      caseSensitive: false,
    );
    final m = p.firstMatch(body);
    return m?.group(1) ?? '';
  }
}
