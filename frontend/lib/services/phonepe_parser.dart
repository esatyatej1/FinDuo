class PhonePeParser {
  static const String phonepePackage = 'com.phonepe.app';

  /// Parses a notification title or content to extract transaction details.
  /// Returns a map with 'amount', 'type', and 'party' if successful, otherwise null.
  static Map<String, dynamic>? parseTransaction(
    String? title,
    String? content,
  ) {
    if (content == null && title == null) return null;

    final textToParse = "${title ?? ''} ${content ?? ''}".trim();

    // Pattern for sending money (e.g., "Paid ₹500 to John Doe")
    final sendPattern = RegExp(
      r'Paid\s+₹([\d,.]+)\s+to\s+(.+)',
      caseSensitive: false,
    );
    // Alternative pattern for sending money
    final sendPattern2 = RegExp(
      r'₹([\d,.]+)\s+has been sent to\s+(.+)',
      caseSensitive: false,
    );
    final receivePattern = RegExp(
      r'Received\s+₹([\d,.]+)\s+from\s+(.+)',
      caseSensitive: false,
    );
    // Alternative pattern for receiving money
    final receivePattern2 = RegExp(
      r'(.+?)\s+sent\s+₹([\d,.]+)\s+to\s+you',
      caseSensitive: false,
    );

    final sendMatch = sendPattern.firstMatch(textToParse) ?? sendPattern2.firstMatch(textToParse);
    if (sendMatch != null) {
      return {
        'type': 'send',
        'amount': _parseAmount(sendMatch.group(1)),
        'party': sendMatch.group(2)?.trim(),
      };
    }

    final receiveMatch = receivePattern.firstMatch(textToParse);
    if (receiveMatch != null) {
      return {
        'type': 'receive',
        'amount': _parseAmount(receiveMatch.group(1)),
        'party': receiveMatch.group(2)?.trim(),
      };
    }

    final receiveMatch2 = receivePattern2.firstMatch(textToParse);
    if (receiveMatch2 != null) {
      return {
        'type': 'receive',
        'amount': _parseAmount(receiveMatch2.group(2)),
        'party': receiveMatch2.group(1)?.split(':').first.trim(),
      };
    }

    return null;
  }

  static double _parseAmount(String? amountStr) {
    if (amountStr == null) return 0.0;
    // Remove commas if any
    final cleanStr = amountStr.replaceAll(',', '');
    return double.tryParse(cleanStr) ?? 0.0;
  }
}
