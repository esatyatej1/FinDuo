import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/sync_engine.dart';
import '../services/api_service.dart';

const _kAutoSyncTask = 'finduo.auto_sync';
const _kLastSyncKey = 'last_auto_sync';

/// Called by WorkManager in the background
@pragma('vm:entry-point')
void backgroundSyncDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task != _kAutoSyncTask) return true;

    try {
      // Load stored credentials
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'auth_token');
      final baseUrl = await storage.read(key: 'base_url') ?? 'http://192.168.0.181:8001';
      if (token == null) return true;

      // Get last sync to determine range
      final prefs = await SharedPreferences.getInstance();
      final lastSync = prefs.getString(_kLastSyncKey);
      final from = lastSync != null
          ? DateTime.parse(lastSync).subtract(const Duration(hours: 1))
          : DateTime.now().subtract(const Duration(days: 2));
      final to = DateTime.now();

      // Sync
      final unified = await SyncEngine.sync(
        from: from,
        to: to,
        includeSms: true,
        includeGmail: false, // Gmail OAuth not available in background isolate
      );

      if (unified.isEmpty) {
        await prefs.setString(_kLastSyncKey, to.toIso8601String());
        return true;
      }

      // Post to backend
      final api = ApiService()..setToken(token, baseUrl: baseUrl);
      final txns = unified.map((u) => {
        'amount': u.amount,
        'title': u.merchant,
        'notes': 'Ref: ${u.refNo}',
        'category_id': null,
        'sub_category_id': null,
        'payment_method': 'UPI',
        'account_ref': '',
        'txn_date': u.date,
        'txn_ref': u.refNo,
        'source': 'auto_sms',
      }).toList();

      await api.bulkImport(txns);
      await prefs.setString(_kLastSyncKey, to.toIso8601String());
    } catch (_) {}

    return true;
  });
}

class AutoSyncService {
  /// Initialize WorkManager — call this in main()
  static Future<void> initialize() async {
    await Workmanager().initialize(
      backgroundSyncDispatcher,
      isInDebugMode: false,
    );
  }

  /// Register periodic 2-hour auto-sync
  static Future<void> enable() async {
    await Workmanager().registerPeriodicTask(
      _kAutoSyncTask,
      _kAutoSyncTask,
      frequency: const Duration(hours: 2),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_sync_enabled', true);
  }

  static Future<void> disable() async {
    await Workmanager().cancelByUniqueName(_kAutoSyncTask);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_sync_enabled', false);
  }

  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('auto_sync_enabled') ?? false;
  }

  static Future<String> lastSyncLabel() async {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getString(_kLastSyncKey);
    if (last == null) return 'Never';
    final dt = DateTime.parse(last);
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
