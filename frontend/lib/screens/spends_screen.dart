import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/finance_provider.dart';
import '../providers/settings_provider.dart';
import 'phonepe_import_screen.dart';

class SpendsScreen extends StatefulWidget {
  const SpendsScreen({super.key});
  @override
  State<SpendsScreen> createState() => _SpendsScreenState();
}

class _SpendsScreenState extends State<SpendsScreen> {
  String _searchQuery = '';
  bool _showSearch = false;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final finance = context.read<FinanceProvider>();
      // Ensure categories + accounts are loaded
      if (finance.categories.isEmpty) finance.fetchData();
      finance.fetchTransactions();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceProvider>();
    final themeColor = context.watch<SettingsProvider>().themeColor;
    final allTxns = finance.transactions;
    
    // Filter by search query
    final txns = _searchQuery.isEmpty
        ? allTxns
        : allTxns.where((t) {
            final title = (t['title'] ?? '').toString().toLowerCase();
            final notes = (t['notes'] ?? '').toString().toLowerCase();
            final catId = t['category_id'];
            final catName = catId != null
                ? (finance.categories.firstWhere(
                    (c) => c['id'] == catId,
                    orElse: () => {'name': ''},
                  )['name'] ?? '').toString().toLowerCase()
                : '';
            final q = _searchQuery.toLowerCase();
            return title.contains(q) || notes.contains(q) || catName.contains(q);
          }).toList();
    
    final summary = finance.txnSummary;
    final total = (summary['total'] ?? 0.0).toDouble();
    final count = summary['count'] ?? 0;

    // Group transactions by date
    final Map<String, List<dynamic>> grouped = {};
    for (final t in txns) {
      final date = t['txn_date'] ?? 'Unknown';
      grouped.putIfAbsent(date, () => []).add(t);
    }
    final sortedDates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      body: Column(
        children: [
          // ── Month Selector + Summary Bar ──────────────────────────
          _MonthBar(finance: finance, themeColor: themeColor, total: total, count: count),
          
          // ── Search Bar ────────────────────────────────────────────
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            height: _showSearch ? 56 : 0,
            color: Theme.of(context).colorScheme.surface,
            child: _showSearch
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: TextField(
                      controller: _searchCtrl,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Search by title, category, notes...',
                        prefixIcon: Icon(Icons.search_rounded, color: themeColor, size: 18),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                onPressed: () => setState(() {
                                  _searchQuery = '';
                                  _searchCtrl.clear();
                                }),
                              )
                            : null,
                        filled: true,
                        fillColor: themeColor.withValues(alpha: 0.08),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        isDense: true,
                      ),
                      onChanged: (v) => setState(() => _searchQuery = v),
                    ),
                  )
                : const SizedBox(),
          ),
          
          // ── Transaction List ──────────────────────────────────────
          Expanded(
            child: finance.isLoading
                ? Center(child: CircularProgressIndicator(color: themeColor))
                : txns.isEmpty
                    ? _searchQuery.isNotEmpty
                        ? _NoSearchResults(query: _searchQuery, themeColor: themeColor)
                        : _EmptySpends(themeColor: themeColor)
                    : RefreshIndicator(
                        color: themeColor,
                        onRefresh: () => finance.fetchTransactions(),
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                          itemCount: sortedDates.length,
                          itemBuilder: (_, i) {
                            final date = sortedDates[i];
                            final dayTxns = grouped[date]!;
                            final dayTotal = dayTxns.fold<double>(0, (s, t) => s + (t['amount'] ?? 0.0));
                            return _DayGroup(
                              date: date,
                              dayTotal: dayTotal,
                              txns: dayTxns,
                              finance: finance,
                              themeColor: themeColor,
                              context: context,
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Search toggle
          FloatingActionButton.small(
            heroTag: 'search_toggle',
            onPressed: () => setState(() {
              _showSearch = !_showSearch;
              if (!_showSearch) {
                _searchQuery = '';
                _searchCtrl.clear();
              }
            }),
            backgroundColor: _showSearch ? themeColor : Theme.of(context).colorScheme.surface,
            foregroundColor: _showSearch ? Colors.white : themeColor,
            tooltip: 'Search',
            child: Icon(_showSearch ? Icons.search_off_rounded : Icons.search_rounded, size: 18),
          ).animate().scale(delay: 100.ms, curve: Curves.elasticOut),
          const SizedBox(height: 8),
          // PhonePe import FAB
          FloatingActionButton.small(
            heroTag: 'phonepe_import',
            onPressed: () => _openPhonePeImport(context, finance),
            backgroundColor: const Color(0xFF5F259F),
            foregroundColor: Colors.white,
            tooltip: 'Import from PhonePe',
            child: const Icon(Icons.phone_android_rounded, size: 18),
          ).animate().scale(delay: 200.ms, curve: Curves.elasticOut),
          const SizedBox(height: 10),
          // Main add FAB
          FloatingActionButton.extended(
            heroTag: 'add_spend',
            onPressed: () => _showAddSheet(context, finance),
            backgroundColor: themeColor,
            foregroundColor: Colors.black,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Spend', style: TextStyle(fontWeight: FontWeight.bold)),
          ).animate().scale(delay: 300.ms, curve: Curves.elasticOut),
        ],
      ),
    );
  }

  void _showAddSheet(BuildContext context, FinanceProvider finance, {Map<String, dynamic>? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddSpendSheet(finance: finance, existing: existing),
    );
  }

  void _openPhonePeImport(BuildContext context, FinanceProvider finance) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const PhonePeImportScreen()),
    );
    // Refresh if transactions were imported
    if (result == true && mounted) {
      finance.fetchTransactions();
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _MonthBar extends StatelessWidget {
  final FinanceProvider finance;
  final Color themeColor;
  final double total;
  final int count;
  const _MonthBar({required this.finance, required this.themeColor, required this.total, required this.count});

  String _fmtFull(double v) => v.toInt().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

  List<String> _buildMonths() {
    final now = DateTime.now();
    return List.generate(6, (i) {
      final d = DateTime(now.year, now.month - i, 1);
      return '${d.year}-${d.month.toString().padLeft(2, '0')}';
    });
  }

  @override
  Widget build(BuildContext context) {
    final months = _buildMonths();
    final selected = finance.selectedMonth;
    final monthNames = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];

    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          // Month chips
          SizedBox(
            height: 48,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: months.length,
              itemBuilder: (_, i) {
                final m = months[i];
                final parts = m.split('-');
                final label = '${monthNames[int.parse(parts[1]) - 1]} ${parts[0]}';
                final isSelected = m == selected;
                return GestureDetector(
                  onTap: () => finance.fetchTransactions(month: m),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSelected ? themeColor : themeColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: themeColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.black : themeColor,
                        )),
                  ),
                );
              },
            ),
          ),
          // Summary strip
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [themeColor.withValues(alpha: 0.15), themeColor.withValues(alpha: 0.05)],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: themeColor.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Icon(Icons.account_balance_wallet_rounded, color: themeColor, size: 20),
                const SizedBox(width: 10),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Month Total', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  Text('₹${_fmtFull(total)}',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: themeColor)),
                ]),
                const Spacer(),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  const Text('Transactions', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  Text('$count entries', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _DayGroup extends StatelessWidget {
  final String date;
  final double dayTotal;
  final List<dynamic> txns;
  final FinanceProvider finance;
  final Color themeColor;
  final BuildContext context;

  const _DayGroup({
    required this.date, required this.dayTotal, required this.txns,
    required this.finance, required this.themeColor, required this.context,
  });

  String _fmt(double v) => v.toInt().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

  String _prettyDate(String d) {
    try {
      final parts = d.split('-');
      final dt = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      final days = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
      if (dt == today) return 'Today';
      if (dt == yesterday) return 'Yesterday';
      return '${days[dt.weekday - 1]}, ${dt.day} ${months[dt.month - 1]}';
    } catch (_) { return d; }
  }

  @override
  Widget build(BuildContext ctx) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Text(_prettyDate(date),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const Spacer(),
              Text('₹${_fmt(dayTotal)}',
                  style: TextStyle(color: themeColor, fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        ...txns.map((t) => _TxnTile(t: t, finance: finance, themeColor: themeColor, parentContext: context)),
      ],
    ).animate().fadeIn(duration: 300.ms);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _TxnTile extends StatelessWidget {
  final dynamic t;
  final FinanceProvider finance;
  final Color themeColor;
  final BuildContext parentContext;
  const _TxnTile({required this.t, required this.finance, required this.themeColor, required this.parentContext});

  String _fmt(double v) => v.toInt().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

  IconData _payIcon(String m) {
    switch (m) {
      case 'UPI': return Icons.phone_android_rounded;
      case 'Cash': return Icons.money_rounded;
      case 'Credit Card': return Icons.credit_card_rounded;
      case 'Debit Card': return Icons.payment_rounded;
      default: return Icons.attach_money_rounded;
    }
  }

  String _catName(int? id) {
    if (id == null) return 'Other';
    final cat = finance.categories.firstWhere((c) => c['id'] == id, orElse: () => {'name': 'Other'});
    return cat['name'] ?? 'Other';
  }

  @override
  Widget build(BuildContext context) {
    final amount = (t['amount'] ?? 0.0).toDouble();
    final method = t['payment_method'] ?? 'UPI';
    final title = t['title']?.toString().isNotEmpty == true ? t['title'] : _catName(t['category_id']);

    return Dismissible(
      key: Key('txn_${t['id']}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: parentContext,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete Transaction'),
            content: const Text('Remove this spend entry?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) => finance.deleteTransaction(t['id']),
      background: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.redAccent,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_rounded, color: Colors.white),
      ),
      child: GestureDetector(
        onTap: () => showModalBottomSheet(
          context: parentContext,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => _AddSpendSheet(finance: finance, existing: Map<String, dynamic>.from(t)),
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: themeColor.withValues(alpha: 0.12)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: themeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_payIcon(method), color: themeColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title ?? 'Spend',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        overflow: TextOverflow.ellipsis),
                    Row(children: [
                      Container(
                        margin: const EdgeInsets.only(top: 3),
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: themeColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(_catName(t['category_id']),
                            style: TextStyle(fontSize: 10, color: themeColor)),
                      ),
                      if (t['notes']?.toString().isNotEmpty == true) ...[
                        const SizedBox(width: 6),
                        Text(t['notes'], style: const TextStyle(fontSize: 10, color: Colors.grey),
                            overflow: TextOverflow.ellipsis),
                      ],
                    ]),
                  ],
                ),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('₹${_fmt(amount)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.redAccent)),
                Text(method, style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ADD / EDIT SPEND SHEET
// ─────────────────────────────────────────────────────────────────────────────
class _AddSpendSheet extends StatefulWidget {
  final FinanceProvider finance;
  final Map<String, dynamic>? existing;
  const _AddSpendSheet({required this.finance, this.existing});
  @override
  State<_AddSpendSheet> createState() => _AddSpendSheetState();
}

class _AddSpendSheetState extends State<_AddSpendSheet> {
  final _amountCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  int? _selectedCategoryId;
  int? _selectedSubCategoryId;
  String _paymentMethod = 'UPI';
  String _accountRef = '';
  String _txnDate = '';
  bool _saving = false;

  final List<String> _methods = ['UPI', 'Cash', 'Credit Card', 'Debit Card'];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _amountCtrl.text = (e['amount'] ?? '').toString();
      _titleCtrl.text = e['title'] ?? '';
      _notesCtrl.text = e['notes'] ?? '';
      _selectedCategoryId = e['category_id'];
      _selectedSubCategoryId = e['sub_category_id'];
      _paymentMethod = e['payment_method'] ?? 'UPI';
      _accountRef = e['account_ref'] ?? '';
      _txnDate = e['txn_date'] ?? _todayStr();
    } else {
      _txnDate = _todayStr();
    }
  }

  String _todayStr() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  Future<void> _save() async {
    if (_amountCtrl.text.isEmpty) return;
    setState(() => _saving = true);
    final data = {
      'amount': double.tryParse(_amountCtrl.text) ?? 0,
      'title': _titleCtrl.text,
      'notes': _notesCtrl.text,
      'category_id': _selectedCategoryId,
      'sub_category_id': _selectedSubCategoryId,
      'payment_method': _paymentMethod,
      'account_ref': _accountRef,
      'txn_date': _txnDate,
    };
    try {
      if (widget.existing != null) {
        await widget.finance.updateTransaction(widget.existing!['id'], data);
      } else {
        await widget.finance.createTransaction(data);
      }
      if (mounted) Navigator.pop(context);
    } catch (_) {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = context.watch<SettingsProvider>().themeColor;
    final finance = widget.finance;
    final parents = finance.parentCategories;
    final subs = _selectedCategoryId != null
        ? finance.subCategoriesOf(_selectedCategoryId!)
        : <dynamic>[];
    final isEdit = widget.existing != null;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 16),
            Text(isEdit ? 'Edit Spend' : 'Log a Spend',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),

            // Amount
            TextField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                prefixText: '₹ ',
                prefixStyle: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: themeColor),
                hintText: '0',
                hintStyle: const TextStyle(fontSize: 28, color: Colors.grey),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: themeColor, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Title
            TextField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                labelText: 'Description (optional)',
                prefixIcon: const Icon(Icons.edit_note_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: themeColor),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Category
            DropdownButtonFormField<int?>(
              value: _selectedCategoryId,
              decoration: InputDecoration(
                labelText: 'Category',
                prefixIcon: const Icon(Icons.category_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('Select Category')),
                ...parents.map((c) => DropdownMenuItem<int>(value: c['id'], child: Text(c['name'] ?? ''))),
              ],
              onChanged: (v) => setState(() {
                _selectedCategoryId = v;
                _selectedSubCategoryId = null;
              }),
            ),
            const SizedBox(height: 14),

            // Sub-Category
            if (subs.isNotEmpty)
              DropdownButtonFormField<int?>(
                value: _selectedSubCategoryId,
                decoration: InputDecoration(
                  labelText: 'Sub-Category',
                  prefixIcon: const Icon(Icons.subdirectory_arrow_right_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('None')),
                  ...subs.map((s) => DropdownMenuItem<int>(value: s['id'], child: Text(s['name'] ?? ''))),
                ],
                onChanged: (v) => setState(() => _selectedSubCategoryId = v),
              ),
            if (subs.isNotEmpty) const SizedBox(height: 14),

            // Payment Method
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Payment Method', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: _methods.map((m) {
                    final sel = m == _paymentMethod;
                    return ChoiceChip(
                      label: Text(m),
                      selected: sel,
                      selectedColor: themeColor,
                      labelStyle: TextStyle(
                          color: sel ? Colors.black : null,
                          fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12),
                      onSelected: (_) => setState(() => _paymentMethod = m),
                    );
                  }).toList(),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Account ref (shown when CC or Debit)
            if (_paymentMethod == 'Credit Card' || _paymentMethod == 'Debit Card')
              DropdownButtonFormField<String>(
                value: _accountRef.isEmpty ? null : _accountRef,
                decoration: InputDecoration(
                  labelText: 'Which Card/Account?',
                  prefixIcon: const Icon(Icons.credit_card_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: finance.myAccounts
                    .where((a) => a['type'] == (_paymentMethod == 'Credit Card' ? 'Credit Card' : 'Bank'))
                    .map((a) => DropdownMenuItem<String>(
                          value: '${a['bank_name']} ${a['type']}',
                          child: Text('${a['bank_name']}'),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _accountRef = v ?? ''),
              ),
            if (_paymentMethod == 'Credit Card' || _paymentMethod == 'Debit Card')
              const SizedBox(height: 14),

            // Date
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.tryParse(_txnDate) ?? DateTime.now(),
                  firstDate: DateTime(2024),
                  lastDate: DateTime.now(),
                  builder: (ctx, child) => Theme(
                    data: Theme.of(ctx).copyWith(
                      colorScheme: ColorScheme.dark(primary: themeColor),
                    ),
                    child: child!,
                  ),
                );
                if (picked != null) {
                  setState(() => _txnDate =
                      '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}');
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.4)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today_rounded, color: themeColor, size: 18),
                    const SizedBox(width: 10),
                    Text(_txnDate, style: const TextStyle(fontSize: 14)),
                    const Spacer(),
                    const Icon(Icons.arrow_drop_down_rounded, color: Colors.grey),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Notes
            TextField(
              controller: _notesCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Notes (optional)',
                prefixIcon: const Icon(Icons.notes_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: themeColor),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Save Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeColor,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(width: 22, height: 22,
                        child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                    : Text(isEdit ? 'Update Spend' : 'Save Spend',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _EmptySpends extends StatelessWidget {
  final Color themeColor;
  const _EmptySpends({required this.themeColor});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.receipt_long_rounded, size: 72, color: themeColor.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          const Text('No spends this month',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Tap + Add Spend to log your first entry',
              style: TextStyle(fontSize: 13, color: Colors.grey)),
        ],
      ),
    );
  }
}

class _NoSearchResults extends StatelessWidget {
  final String query;
  final Color themeColor;
  const _NoSearchResults({required this.query, required this.themeColor});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_rounded, size: 64, color: Colors.grey.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text('No results for "$query"',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Try a different search term',
              style: TextStyle(fontSize: 13, color: Colors.grey)),
        ],
      ),
    );
  }
}
