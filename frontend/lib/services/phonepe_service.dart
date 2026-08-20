import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:permission_handler/permission_handler.dart';

/// Parsed PhonePe (or bank UPI) transaction from SMS
class PhonePeTransaction {
  final double amount;
  final String date; // "YYYY-MM-DD"
  final String rawSms;
  final String sender;
  final String merchant; // payee name if extractable
  final String refNo;
  bool selected; // for batch import UI

  PhonePeTransaction({
    required this.amount,
    required this.date,
    required this.rawSms,
    required this.sender,
    required this.merchant,
    required this.refNo,
    this.selected = true,
  });
}

class PhonePeService {
  final SmsQuery _query = SmsQuery();

  /// Request SMS permission and return whether granted
  Future<bool> requestPermission() async {
    final status = await Permission.sms.request();
    return status.isGranted;
  }

  Future<bool> hasPermission() async {
    return await Permission.sms.isGranted;
  }

  /// Read SMS inbox and return parsed PhonePe/UPI debit transactions
  Future<List<PhonePeTransaction>> fetchPhonePeTransactions({
    int daysBack = 90,
  }) async {
    if (!await hasPermission()) return [];

    final messages = await _query.querySms(kinds: [SmsQueryKind.inbox]);

    final cutoff = DateTime.now().subtract(Duration(days: daysBack));
    final results = <PhonePeTransaction>[];

    for (final sms in messages) {
      final body = sms.body ?? '';
      final sender = sms.sender ?? '';
      final date = sms.dateSent ?? sms.date ?? DateTime.now();

      if (date.isBefore(cutoff)) continue;

      // Only process if message looks like a UPI/PhonePe debit
      if (!_isPhonePeDebit(body, sender)) continue;

      final parsed = _parse(body, sender, date);
      if (parsed != null) results.add(parsed);
    }

    // Sort newest first
    results.sort((a, b) => b.date.compareTo(a.date));
    return results;
  }

  bool _isPhonePeDebit(String body, String sender) {
    final b = body.toLowerCase();
    final s = sender.toLowerCase();

    // Must contain PhonePe reference OR be from a known bank about UPI debit
    final hasPhonePe =
        b.contains('phonepe') || s.contains('phonepe') || s.contains('ppye');
    final hasUpi = b.contains('upi') || b.contains('imps');
    final hasDebit =
        b.contains('debited') ||
        b.contains('debit') ||
        b.contains('paid') ||
        b.contains('sent');
    final hasBankSender = RegExp(
      r'(hdfc|axis|sbi|icici|kotak|pnb|bob|canara|union|idfc|yesbank|indusind)',
      caseSensitive: false,
    ).hasMatch(s);

    if (hasPhonePe && hasDebit) return true;
    if (hasBankSender && hasUpi && hasDebit) return true;
    return false;
  }

  PhonePeTransaction? _parse(String body, String sender, DateTime date) {
    // Extract amount
    double? amount = _extractAmount(body);
    if (amount == null || amount <= 0) return null;

    // Extract date from SMS or fall back to received date
    final txnDate = _extractDate(body) ?? _formatDate(date);

    // Extract merchant/payee
    final merchant = _extractMerchant(body);

    // Extract ref
    final ref = _extractRef(body);

    return PhonePeTransaction(
      amount: amount,
      date: txnDate,
      rawSms: body,
      sender: sender,
      merchant: merchant,
      refNo: ref,
    );
  }

  double? _extractAmount(String body) {
    // Patterns: INR 1,234.56 | Rs.500 | Rs 500 | ₹500 | INR500
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
      final m = p.firstMatch(body);
      if (m != null) {
        final str = m.group(1)?.replaceAll(',', '') ?? '';
        final val = double.tryParse(str);
        if (val != null && val > 0) return val;
      }
    }
    return null;
  }

  String? _extractDate(String body) {
    // DD-MM-YY or DD-MM-YYYY or DD/MM/YY or DD/MM/YYYY
    final patterns = [
      RegExp(r'(\d{2})[-/](\d{2})[-/](\d{2,4})'),
      RegExp(r'(\d{2})-([A-Za-z]{3})-(\d{2,4})'),
    ];
    final months = {
      'jan': 1,
      'feb': 2,
      'mar': 3,
      'apr': 4,
      'may': 5,
      'jun': 6,
      'jul': 7,
      'aug': 8,
      'sep': 9,
      'oct': 10,
      'nov': 11,
      'dec': 12,
    };

    for (final p in patterns) {
      final m = p.firstMatch(body);
      if (m != null) {
        try {
          int day = int.parse(m.group(1)!);
          int month;
          int year;
          final m2 = m.group(2)!;
          final m3 = m.group(3)!;
          if (RegExp(r'[a-zA-Z]').hasMatch(m2)) {
            month = months[m2.toLowerCase()] ?? 1;
          } else {
            month = int.parse(m2);
          }
          year = int.parse(m3);
          if (year < 100) year += 2000;
          return '${year.toString()}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
        } catch (_) {}
      }
    }
    return null;
  }

  String _extractMerchant(String body) {
    // "to [Merchant]" or "at [Merchant]" or "PaymentTo:[Merchant]"
    final patterns = [
      RegExp(
        r'(?:to|at)\s+([A-Za-z0-9 &_\-]{2,30}?)(?:\s+on|\s+via|\s+ref|\s*\.|$)',
        caseSensitive: false,
      ),
      RegExp(r'PaymentTo[:\s]+([^\s,\.]+)', caseSensitive: false),
      RegExp(r'VPA[:\s]+([^\s,\.]+)', caseSensitive: false),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(body);
      if (m != null) {
        final val = m.group(1)?.trim() ?? '';
        if (val.length > 2) return val;
      }
    }
    return 'PhonePe/UPI';
  }

  String _extractRef(String body) {
    final p = RegExp(
      r'(?:Ref|UPI Ref|Ref No|Transaction ID)[:\s#]+([0-9A-Za-z]{6,20})',
      caseSensitive: false,
    );
    final m = p.firstMatch(body);
    return m?.group(1) ?? '';
  }

  String _formatDate(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}
