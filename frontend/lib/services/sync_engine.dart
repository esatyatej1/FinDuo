import 'phonepe_service.dart';
import 'gmail_service.dart';

/// A unified transaction from any source (SMS / Gmail / both)
class UnifiedTransaction {
  final double amount;
  final String date;
  final String merchant;
  final String refNo;
  final String paymentMethod;
  final Set<String> sources; // 'sms', 'gmail'
  final String rawSms;
  final String rawGmail;
  bool selected;

  // For import UI
  int? categoryId;
  int? subCategoryId;

  UnifiedTransaction({
    required this.amount,
    required this.date,
    required this.merchant,
    required this.refNo,
    required this.paymentMethod,
    required this.sources,
    this.rawSms = '',
    this.rawGmail = '',
    this.selected = true,
    this.categoryId,
    this.subCategoryId,
  });

  /// Source badge label
  String get sourceLabel {
    if (sources.containsAll(['sms', 'gmail'])) return 'SMS + Gmail';
    if (sources.contains('gmail')) return 'Gmail';
    return 'SMS';
  }
}

class SyncEngine {
  /// Pull from both SMS and Gmail, correlate, deduplicate
  /// Returns merged unique transactions sorted by date desc
  static Future<List<UnifiedTransaction>> sync({
    required DateTime from,
    required DateTime to,
    bool includeSms = true,
    bool includeGmail = true,
  }) async {
    final List<PhonePeTransaction> smsTxns = [];
    final List<GmailTransaction> gmailTxns = [];

    final daysBack = DateTime.now().difference(from).inDays + 1;

    if (includeSms) {
      final svc = PhonePeService();
      smsTxns.addAll(await svc.fetchPhonePeTransactions(daysBack: daysBack));
    }

    if (includeGmail && GmailService.isSignedIn) {
      gmailTxns.addAll(
        await GmailService.fetchTransactions(from: from, to: to),
      );
    }

    // Filter by date range
    final fromStr = _fmtDate(from);
    final toStr = _fmtDate(to);

    final filteredSms = smsTxns
        .where(
          (t) => t.date.compareTo(fromStr) >= 0 && t.date.compareTo(toStr) <= 0,
        )
        .toList();
    final filteredGmail = gmailTxns
        .where(
          (t) => t.date.compareTo(fromStr) >= 0 && t.date.compareTo(toStr) <= 0,
        )
        .toList();

    return _correlate(filteredSms, filteredGmail);
  }

  /// Correlate SMS and Gmail transactions, merging duplicates
  static List<UnifiedTransaction> _correlate(
    List<PhonePeTransaction> smsList,
    List<GmailTransaction> gmailList,
  ) {
    final merged = <UnifiedTransaction>[];

    // Track which Gmail txns have been matched
    final matchedGmailIdx = <int>{};

    for (final s in smsList) {
      // Try to find a matching Gmail transaction
      int gmailMatch = -1;
      for (int i = 0; i < gmailList.length; i++) {
        if (matchedGmailIdx.contains(i)) continue;
        final g = gmailList[i];
        if (_isMatch(s.amount, s.date, s.refNo, g.amount, g.date, g.refNo)) {
          gmailMatch = i;
          break;
        }
      }

      if (gmailMatch >= 0) {
        // Merge: prefer Gmail merchant (richer data)
        final g = gmailList[gmailMatch];
        merged.add(
          UnifiedTransaction(
            amount: s.amount,
            date: s.date,
            merchant: g.merchant.length > s.merchant.length
                ? g.merchant
                : s.merchant,
            refNo: s.refNo.isNotEmpty ? s.refNo : g.refNo,
            paymentMethod: 'UPI',
            sources: {'sms', 'gmail'},
            rawSms: s.rawSms,
            rawGmail: g.rawBody,
          ),
        );
        matchedGmailIdx.add(gmailMatch);
      } else {
        merged.add(
          UnifiedTransaction(
            amount: s.amount,
            date: s.date,
            merchant: s.merchant,
            refNo: s.refNo,
            paymentMethod: 'UPI',
            sources: {'sms'},
            rawSms: s.rawSms,
          ),
        );
      }
    }

    // Add unmatched Gmail transactions
    for (int i = 0; i < gmailList.length; i++) {
      if (matchedGmailIdx.contains(i)) continue;
      final g = gmailList[i];
      merged.add(
        UnifiedTransaction(
          amount: g.amount,
          date: g.date,
          merchant: g.merchant,
          refNo: g.refNo,
          paymentMethod: 'UPI',
          sources: {'gmail'},
          rawGmail: g.rawBody,
        ),
      );
    }

    merged.sort((a, b) => b.date.compareTo(a.date));
    return merged;
  }

  /// Match heuristic: by ref OR (same amount + date within 1 day)
  static bool _isMatch(
    double a1,
    String d1,
    String r1,
    double a2,
    String d2,
    String r2,
  ) {
    // Ref match (most reliable)
    if (r1.isNotEmpty && r2.isNotEmpty && r1 == r2) return true;
    // Amount match + date within 1 day
    if ((a1 - a2).abs() < 0.01) {
      try {
        final dt1 = DateTime.parse(d1);
        final dt2 = DateTime.parse(d2);
        if (dt1.difference(dt2).inDays.abs() <= 1) return true;
      } catch (_) {}
    }
    return false;
  }

  static String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
