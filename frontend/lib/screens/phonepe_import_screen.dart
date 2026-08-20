import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/finance_provider.dart';
import '../providers/settings_provider.dart';
import '../services/sync_engine.dart';
import '../services/api_service.dart';
import '../services/auto_sync_service.dart';
import '../services/notification_service.dart';
import '../services/phonepe_service.dart';
import 'package:flutter_background/flutter_background.dart';

class PhonePeImportScreen extends StatefulWidget {
  const PhonePeImportScreen({super.key});
  @override
  State<PhonePeImportScreen> createState() => _PhonePeImportScreenState();
}

class _PhonePeImportScreenState extends State<PhonePeImportScreen> {
  List<UnifiedTransaction> _transactions = [];
  bool _loading = false;
  bool _importing = false;
  String? _error;

  // Settings
  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _toDate = DateTime.now();
  bool _useSms = true;
  bool _autoSyncEnabled = false;
  bool _notificationSyncEnabled = false;
  bool _backgroundRunning = false;
  String _lastSyncStr = 'Never';

  // Category assignment per transaction (index → categoryId)
  final Map<int, int?> _catMap = {};
  final Map<int, int?> _subCatMap = {};

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    final enabled = await AutoSyncService.isEnabled();
    final lastSync = await AutoSyncService.lastSyncLabel();
    final notifEnabled = await FinDuoNotificationService.isEnabled();

    bool bgEnabled = false;
    try {
      await FlutterBackground.initialize(
        androidConfig: const FlutterBackgroundAndroidConfig(
          notificationTitle: "FinDuo Sync",
          notificationText: "Running in background to track transactions",
          notificationImportance: AndroidNotificationImportance.normal,
          notificationIcon: AndroidResource(
            name: 'ic_launcher',
            defType: 'mipmap',
          ),
        ),
      );
      bgEnabled = FlutterBackground.isBackgroundExecutionEnabled;
    } catch (_) {}

    setState(() {
      _autoSyncEnabled = enabled;
      _lastSyncStr = lastSync;
      _notificationSyncEnabled = notifEnabled;
      _backgroundRunning = bgEnabled;
    });
  }

  Future<void> _loadTransactions() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    // Auth checks
    if (_useSms) {
      final pSvc = PhonePeService();
      if (!await pSvc.hasPermission()) {
        final granted = await pSvc.requestPermission();
        if (!granted) {
          setState(() {
            _useSms = false;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('SMS permission denied. Proceeding without SMS.'),
              ),
            );
          }
        }
      }
    }

    try {
      final txns = await SyncEngine.sync(
        from: _fromDate,
        to: _toDate,
        includeSms: _useSms,
        includeGmail: false,
      );
      setState(() {
        _transactions = txns;
        _loading = false;
      });

      if (txns.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No transactions found in the selected date range.'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Failed to load transactions: $e';
      });
    }
  }

  Future<void> _importSelected() async {
    final finance = context.read<FinanceProvider>();
    final selected = _transactions.where((t) => t.selected).toList();
    if (selected.isEmpty) return;

    setState(() => _importing = true);

    final toImport = <Map<String, dynamic>>[];
    for (int i = 0; i < _transactions.length; i++) {
      final t = _transactions[i];
      if (!t.selected) continue;

      toImport.add({
        'amount': t.amount,
        'title': t.merchant,
        'notes': t.refNo.isNotEmpty ? 'Ref: ${t.refNo}' : '',
        'category_id': _catMap[i],
        'sub_category_id': _subCatMap[i],
        'payment_method': 'UPI',
        'account_ref': '',
        'txn_date': t.date,
        'txn_ref': t.refNo,
        'source': 'manual_sync',
      });
    }

    try {
      final result = await ApiService().bulkImport(toImport);
      setState(() => _importing = false);

      if (mounted) {
        final imp = result['imported'];
        final skip = result['skipped'];
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Imported $imp transactions. Skipped $skip duplicates.',
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _importing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleAutoSync(bool val) async {
    if (val) {
      await AutoSyncService.enable();
    } else {
      await AutoSyncService.disable();
    }
    setState(() => _autoSyncEnabled = val);
  }

  Future<void> _toggleNotificationSync(bool val) async {
    if (val) {
      bool granted = await FinDuoNotificationService.requestPermission();
      if (granted) {
        setState(() => _notificationSyncEnabled = true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Real-time PhonePe Sync Enabled!')),
          );
        }
      } else {
        setState(() => _notificationSyncEnabled = false);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Permission denied.')));
        }
      }
    } else {
      await FinDuoNotificationService.disable();
      setState(() => _notificationSyncEnabled = false);
    }
  }

  Future<void> _toggleBackgroundExecution(bool val) async {
    if (val) {
      bool initialized = await FlutterBackground.initialize(
        androidConfig: const FlutterBackgroundAndroidConfig(
          notificationTitle: "FinDuo Sync",
          notificationText: "Running in background to track transactions",
          notificationImportance: AndroidNotificationImportance.normal,
          notificationIcon: AndroidResource(
            name: 'ic_launcher',
            defType: 'mipmap',
          ),
        ),
      );

      bool success = false;
      if (initialized) {
        success = await FlutterBackground.enableBackgroundExecution();
      }
      setState(() => _backgroundRunning = success);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('App will now run in the background!')),
        );
      }
    } else {
      await FlutterBackground.disableBackgroundExecution();
      setState(() => _backgroundRunning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = context.watch<SettingsProvider>().themeColor;
    final finance = context.watch<FinanceProvider>();
    final selectedCount = _transactions.where((t) => t.selected).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Smart Sync',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      body: _loading
          ? _buildLoading(themeColor)
          : _error != null
          ? _buildError(themeColor)
          : _transactions.isEmpty
          ? _buildConfigScreen(themeColor)
          : Column(
              children: [
                _buildSelectBar(themeColor, selectedCount),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                    itemCount: _transactions.length,
                    itemBuilder: (_, i) => _TxnImportCard(
                      index: i,
                      txn: _transactions[i],
                      finance: finance,
                      themeColor: themeColor,
                      categoryId: _catMap[i],
                      subCategoryId: _subCatMap[i],
                      onToggle: () => setState(
                        () => _transactions[i].selected =
                            !_transactions[i].selected,
                      ),
                      onCategoryChanged: (cId, sId) => setState(() {
                        _catMap[i] = cId;
                        _subCatMap[i] = sId;
                      }),
                    ),
                  ),
                ),
              ],
            ),
      bottomNavigationBar:
          !_loading && _error == null && _transactions.isNotEmpty
          ? _buildImportBar(themeColor, selectedCount)
          : null,
    );
  }

  Widget _buildConfigScreen(Color themeColor) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Auto Sync Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                themeColor.withValues(alpha: 0.15),
                themeColor.withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: themeColor.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.autorenew_rounded, color: themeColor),
                  const SizedBox(width: 8),
                  const Text(
                    'Background Auto-Sync',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const Spacer(),
                  Switch(
                    value: _autoSyncEnabled,
                    activeColor: themeColor,
                    onChanged: _toggleAutoSync,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Checks SMS for UPI debits every 2 hours and imports them silently.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text(
                    'Last synced: ',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  Text(
                    _lastSyncStr,
                    style: TextStyle(
                      fontSize: 12,
                      color: themeColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Notification Sync Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                themeColor.withValues(alpha: 0.15),
                themeColor.withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: themeColor.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.notifications_active_rounded, color: themeColor),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Real-Time PhonePe Sync',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Switch(
                    value: _notificationSyncEnabled,
                    activeColor: themeColor,
                    onChanged: _toggleNotificationSync,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Instantly tracks PhonePe transactions by securely reading incoming notifications.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),
        // Run in Background Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                themeColor.withValues(alpha: 0.15),
                themeColor.withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: themeColor.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.system_security_update_good_rounded,
                    color: themeColor,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Keep App Alive (Background)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Switch(
                    value: _backgroundRunning,
                    activeColor: themeColor,
                    onChanged: _toggleBackgroundExecution,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Prevents Android from killing the app so real-time sync never stops.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),
        const Text(
          'Manual Sync',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 16),

        // Sources
        SwitchListTile(
          title: const Text('SMS Inbox'),
          subtitle: const Text('Read bank & PhonePe SMS'),
          value: _useSms,
          onChanged: (v) => setState(() => _useSms = v),
          secondary: const Icon(Icons.sms_rounded),
          activeColor: themeColor,
        ),
        const SizedBox(height: 16),

        // Dates
        ListTile(
          leading: const Icon(Icons.date_range_rounded),
          title: const Text('Date Range'),
          subtitle: Text('${_fmtDate(_fromDate)}  to  ${_fmtDate(_toDate)}'),
          trailing: TextButton(
            child: Text('Change', style: TextStyle(color: themeColor)),
            onPressed: () async {
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2023),
                lastDate: DateTime.now(),
                initialDateRange: DateTimeRange(start: _fromDate, end: _toDate),
                builder: (ctx, child) => Theme(
                  data: Theme.of(ctx).copyWith(
                    colorScheme: ColorScheme.dark(primary: themeColor),
                  ),
                  child: child!,
                ),
              );
              if (picked != null) {
                setState(() {
                  _fromDate = picked.start;
                  _toDate = picked.end;
                });
              }
            },
          ),
        ),

        const SizedBox(height: 32),
        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: themeColor,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: (!_useSms) ? null : _loadTransactions,
            icon: const Icon(Icons.search_rounded),
            label: const Text(
              'Scan for Transactions',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Widget _buildSelectBar(Color themeColor, int selectedCount) {
    final total = _transactions.length;
    final allSelected = selectedCount == total;
    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.checklist_rounded, color: themeColor, size: 18),
          const SizedBox(width: 8),
          Text(
            'Found $total unique transactions',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          TextButton(
            onPressed: () => setState(() {
              for (final t in _transactions) t.selected = !allSelected;
            }),
            child: Text(
              allSelected ? 'Deselect All' : 'Select All',
              style: TextStyle(color: themeColor, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImportBar(Color themeColor, int count) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SizedBox(
        height: 52,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF5F259F),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 0,
          ),
          onPressed: count == 0 || _importing ? null : _importSelected,
          icon: _importing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Icon(Icons.download_rounded, size: 20),
          label: Text(
            _importing
                ? 'Importing...'
                : 'Import $count Transaction${count != 1 ? 's' : ''}',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildLoading(Color themeColor) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(color: themeColor),
        const SizedBox(height: 16),
        const Text(
          'Correlating SMS & Gmail data...',
          style: TextStyle(color: Colors.grey),
        ),
      ],
    ),
  );

  Widget _buildError(Color themeColor) => Padding(
    padding: const EdgeInsets.all(32),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.error_outline_rounded,
          size: 64,
          color: Colors.redAccent.withValues(alpha: 0.6),
        ),
        const SizedBox(height: 16),
        Text(
          _error!,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () => setState(() => _error = null),
          icon: const Icon(Icons.arrow_back_rounded),
          label: const Text('Back to Config'),
          style: ElevatedButton.styleFrom(
            backgroundColor: themeColor,
            foregroundColor: Colors.black,
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
class _TxnImportCard extends StatelessWidget {
  final int index;
  final UnifiedTransaction txn;
  final FinanceProvider finance;
  final Color themeColor;
  final int? categoryId;
  final int? subCategoryId;
  final VoidCallback onToggle;
  final Function(int? catId, int? subId) onCategoryChanged;

  const _TxnImportCard({
    required this.index,
    required this.txn,
    required this.finance,
    required this.themeColor,
    required this.categoryId,
    required this.subCategoryId,
    required this.onToggle,
    required this.onCategoryChanged,
  });

  String _fmtFull(double v, [double rate = 1.0]) => (v * rate).toInt().toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]},',
  );

  @override
  Widget build(BuildContext context) {
    final subs = categoryId != null
        ? finance.subCategoriesOf(categoryId!)
        : <dynamic>[];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: txn.selected
              ? const Color(0xFF5F259F).withValues(alpha: 0.5)
              : Colors.grey.withValues(alpha: 0.2),
          width: txn.selected ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          // Main row
          ListTile(
            contentPadding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
            leading: GestureDetector(
              onTap: onToggle,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: txn.selected
                      ? const Color(0xFF5F259F)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: txn.selected ? const Color(0xFF5F259F) : Colors.grey,
                    width: 2,
                  ),
                ),
                child: txn.selected
                    ? const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 16,
                      )
                    : null,
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    txn.merchant,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${context.read<SettingsProvider>().currency}${_fmtFull(txn.amount, context.read<SettingsProvider>().conversionRate)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.redAccent,
                  ),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 11,
                      color: Colors.grey[500],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      txn.date,
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                    if (txn.refNo.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      Icon(
                        Icons.tag_rounded,
                        size: 11,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 2),
                      Text(
                        txn.refNo,
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                // Source badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    txn.sourceLabel,
                    style: const TextStyle(fontSize: 9, color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
          // Category assignment
          if (txn.selected)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int?>(
                      value: categoryId,
                      isDense: true,
                      style: const TextStyle(fontSize: 12),
                      decoration: InputDecoration(
                        labelText: 'Category',
                        labelStyle: const TextStyle(fontSize: 11),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        isDense: true,
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text(
                            'No category',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                        ...finance.parentCategories.map(
                          (c) => DropdownMenuItem<int>(
                            value: c['id'],
                            child: Text(
                              c['name'] ?? '',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      ],
                      onChanged: (v) => onCategoryChanged(v, null),
                    ),
                  ),
                  if (subs.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<int?>(
                        value: subCategoryId,
                        isDense: true,
                        style: const TextStyle(fontSize: 12),
                        decoration: InputDecoration(
                          labelText: 'Sub',
                          labelStyle: const TextStyle(fontSize: 11),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          isDense: true,
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('None', style: TextStyle(fontSize: 12)),
                          ),
                          ...subs.map(
                            (s) => DropdownMenuItem<int>(
                              value: s['id'],
                              child: Text(
                                s['name'] ?? '',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                        ],
                        onChanged: (v) => onCategoryChanged(categoryId, v),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    ).animate().fadeIn(
      duration: 300.ms,
      delay: Duration(milliseconds: index * 30),
    );
  }
}
