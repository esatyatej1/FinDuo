import 'package:flutter/foundation.dart';
import 'package:notification_listener_service/notification_listener_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'phonepe_parser.dart';
import 'api_service.dart';

class FinDuoNotificationService {
  static const String _kEnabledKey = 'notification_sync_enabled';
  static bool _isListening = false;

  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final isEnabled = prefs.getBool(_kEnabledKey) ?? false;

    if (isEnabled) {
      bool isGranted = await NotificationListenerService.isPermissionGranted();
      if (isGranted) {
        _startListening();
      } else {
        await disable();
      }
    }
  }

  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kEnabledKey) ?? false;
  }

  static Future<void> disable() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabledKey, false);
  }

  static Future<bool> requestPermission() async {
    bool isGranted = await NotificationListenerService.isPermissionGranted();
    if (!isGranted) {
      isGranted = await NotificationListenerService.requestPermission();
    }
    if (isGranted) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kEnabledKey, true);
      _startListening();
    }
    return isGranted;
  }

  static void _startListening() {
    if (_isListening) return;
    _isListening = true;

    NotificationListenerService.notificationsStream.listen((event) async {
      final prefs = await SharedPreferences.getInstance();
      if (!(prefs.getBool(_kEnabledKey) ?? false)) return;

      if (kDebugMode) {
        print("Notification Received from: ${event.packageName}");
        print("Title: ${event.title}");
        print("Content: ${event.content}");
      }

      if (event.packageName == PhonePeParser.phonepePackage) {
        final parsedData = PhonePeParser.parseTransaction(
          event.title,
          event.content,
        );
        if (parsedData != null) {
          if (kDebugMode) {
            print("Successfully parsed PhonePe Transaction: $parsedData");
          }
          // Here we would typically dispatch this to a Provider or Database
          // e.g., TransactionProvider.addTransaction(parsedData);
          _saveTransaction(parsedData);
        }
      }
    });
  }

  static Future<void> _saveTransaction(Map<String, dynamic> data) async {
    if (kDebugMode) {
      print(
        "Saving transaction to DB: Type=${data['type']}, Amount=${data['amount']}, Party=${data['party']}",
      );
    }

    try {
      final now = DateTime.now();
      final dateStr = now.toIso8601String();

      final title = data['party'] != null
          ? '${data['party']}'
          : 'PhonePe Transfer';

      final isReceive = data['type'] == 'receive';
      final noteText = isReceive 
          ? 'Received: Auto-detected PhonePe Transaction'
          : 'Auto-detected PhonePe Transaction';

      final payload = {
        'amount': data['amount'],
        'title': title,
        'notes': noteText,
        'payment_method': 'UPI',
        'txn_date': dateStr,
        'source': 'auto_phonepe',
        'is_pending_review': true,
        'txn_type': isReceive ? 'received' : 'sent',
      };

      await ApiService().createTransaction(payload);
      if (kDebugMode) {
        print("Successfully saved to DB!");
      }
    } catch (e) {
      if (kDebugMode) {
        print("Failed to save transaction to DB: $e");
      }
    }
  }
}
