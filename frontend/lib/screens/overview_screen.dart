import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/finance_provider.dart';
import '../providers/settings_provider.dart';

class OverviewScreen extends StatelessWidget {
  const OverviewScreen({super.key});

  String _fmtFull(double val) {
    final n = val.toInt();
    return n.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceProvider>();
    final themeColor = context.watch<SettingsProvider>().themeColor;

    if (finance.isLoading && finance.userData.isEmpty) {
      return Center(child: CircularProgressIndicator(color: themeColor));
    }

    if (finance.error != null && finance.userData.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              Text(finance.error ?? 'Connection error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    final income = (finance.userData['monthly_income'] ?? 0.0).toDouble();
    final totalEMIs =
        finance.myLoans.fold<double>(0, (s, l) => s + (l['emi'] ?? 0.0));
    final totalBills =
        finance.expenses.fold<double>(0, (s, e) => s + (e['amount'] ?? 0.0));
    final netBalance = income - totalEMIs - totalBills;

    final creditCards =
        finance.myAccounts.where((a) => a['type'] == 'Credit Card').toList();
    final banks =
        finance.myAccounts.where((a) => a['type'] == 'Bank').toList();
    final totalCCLimit = creditCards.fold<double>(
        0, (s, a) => s + (a['limit'] ?? 0.0));
    final totalCCUsed = creditCards.fold<double>(
        0, (s, a) => s + ((a['limit'] ?? 0.0) - (a['balance_left'] ?? 0.0)));

    return RefreshIndicator(
      color: themeColor,
      onRefresh: () => finance.fetchData(),
      child: ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        // ── Monthly Summary ─────────────────────────────────────────
        _SectionTitle(title: 'Monthly Summary', icon: Icons.analytics_outlined),
        const SizedBox(height: 10),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.55,
          children: [
            _MetricCard(
              title: 'Income',
              value: '₹${_fmtFull(income)}',
              icon: Icons.trending_up_rounded,
              colors: [const Color(0xFF10B981), const Color(0xFF059669)],
            ),
            _MetricCard(
              title: 'Total EMIs',
              value: '₹${_fmtFull(totalEMIs)}',
              icon: Icons.request_quote_rounded,
              colors: [const Color(0xFFF59E0B), const Color(0xFFD97706)],
            ),
            _MetricCard(
              title: 'Fixed Bills',
              value: '₹${_fmtFull(totalBills)}',
              icon: Icons.receipt_long_rounded,
              colors: [const Color(0xFFEF4444), const Color(0xFFDC2626)],
            ),
            _MetricCard(
              title: 'Net Balance',
              value: '₹${_fmtFull(netBalance)}',
              icon: netBalance >= 0
                  ? Icons.savings_rounded
                  : Icons.warning_rounded,
              colors: netBalance >= 0
                  ? [const Color(0xFF6366F1), const Color(0xFF4F46E5)]
                  : [const Color(0xFFEF4444), const Color(0xFFDC2626)],
            ),
          ],
        ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.1, end: 0),
        const SizedBox(height: 20),

        // ── Credit Cards ─────────────────────────────────────────────
        if (creditCards.isNotEmpty) ...[
          _SectionTitle(
              title: 'Credit Cards', icon: Icons.credit_card_rounded),
          const SizedBox(height: 10),
          // CC Utilization bar
          _CCUtilizationBar(used: totalCCUsed, total: totalCCLimit),
          const SizedBox(height: 10),
          ...creditCards.map((cc) => _CreditCardTile(cc: cc)),
          const SizedBox(height: 20),
        ],

        // ── Bank Accounts ─────────────────────────────────────────────
        _SectionTitle(
            title: 'Bank Accounts', icon: Icons.account_balance_rounded),
        const SizedBox(height: 10),
        if (banks.isEmpty)
          _EmptyTile(text: 'No bank accounts')
        else
          ...banks.map((b) => _BankTile(acc: b, themeColor: themeColor)),
        const SizedBox(height: 20),

        // ── Active EMIs ───────────────────────────────────────────────
        _SectionTitle(
            title: 'Active EMIs', icon: Icons.request_quote_rounded),
        const SizedBox(height: 10),
        if (finance.myLoans.isEmpty)
          _EmptyTile(text: 'No active loans')
        else
          ...finance.myLoans.map((l) => _LoanTile(loan: l)),
        const SizedBox(height: 20),

        // ── Fixed Bills ───────────────────────────────────────────────
        _SectionTitle(
            title: 'Fixed Monthly Bills', icon: Icons.receipt_long_rounded),
        const SizedBox(height: 10),
        if (finance.expenses.isEmpty)
          _EmptyTile(text: 'No fixed bills')
        else
          ...finance.expenses.map((e) => _BillTile(exp: e)),
        const SizedBox(height: 20),

        // ── Spending Categories ───────────────────────────────────────
        _SectionTitle(
            title: 'Spending Categories', icon: Icons.category_rounded),
        const SizedBox(height: 10),
        if (finance.parentCategories.isEmpty)
          _EmptyTile(text: 'No categories defined')
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: finance.parentCategories
                .map((cat) => _CategoryPill(
                      category: cat,
                      subs: finance.subCategoriesOf(cat['id']),
                      themeColor: themeColor,
                    ))
                .toList(),
          ),
        const SizedBox(height: 16),
      ],
      ), // end ListView
    ); // end RefreshIndicator
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REUSABLE WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionTitle({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 6),
        Text(title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                )),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final List<Color> colors;
  const _MetricCard(
      {required this.title,
      required this.value,
      required this.icon,
      required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors.map((c) => c.withValues(alpha: 0.18)).toList(),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors[0].withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: colors),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white, size: 14),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style:
                      const TextStyle(color: Colors.grey, fontSize: 11)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ],
      ),
    );
  }
}

class _CCUtilizationBar extends StatelessWidget {
  final double used;
  final double total;
  const _CCUtilizationBar({required this.used, required this.total});

  String _fmt(double v) => v.toInt().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (used / total).clamp(0.0, 1.0) : 0.0;
    final color = pct > 0.8
        ? Colors.redAccent
        : pct > 0.5
            ? Colors.orangeAccent
            : Colors.green;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Overall Utilization',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600)),
              Text('${(pct * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                      color: color,
                      fontSize: 14,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 7,
              backgroundColor: color.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Used: ₹${_fmt(used)}',
                  style: TextStyle(fontSize: 11, color: color)),
              Text('Total: ₹${_fmt(total)}',
                  style: const TextStyle(
                      fontSize: 11, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }
}

class _CreditCardTile extends StatelessWidget {
  final dynamic cc;
  const _CreditCardTile({required this.cc});

  String _fmt(double v) => v.toInt().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

  @override
  Widget build(BuildContext context) {
    final limit = (cc['limit'] ?? 0.0).toDouble();
    final left = (cc['balance_left'] ?? 0.0).toDouble();
    final used = limit - left;
    final pct = limit > 0 ? (used / limit).clamp(0.0, 1.0) : 0.0;
    final color = pct > 0.9
        ? Colors.redAccent
        : pct > 0.5
            ? Colors.orangeAccent
            : Colors.green;
    final isMaxed = left <= 0;
    final isClear = left >= limit;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF7C3AED).withValues(alpha: 0.1),
            const Color(0xFF4F46E5).withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: Colors.deepPurpleAccent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.credit_card_rounded,
                  color: Color(0xFF7C3AED), size: 18),
              const SizedBox(width: 8),
              Expanded(
                  child: Text('${cc['bank_name']}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14))),
              if (isMaxed)
                _StatusBadge('MAXED', Colors.redAccent)
              else if (isClear)
                _StatusBadge('CLEAR', Colors.green),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 5,
              backgroundColor: color.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Limit: ₹${_fmt(limit)}',
                  style:
                      const TextStyle(fontSize: 11, color: Colors.grey)),
              Text('Used: ₹${_fmt(used)}',
                  style: TextStyle(
                      fontSize: 11,
                      color: color,
                      fontWeight: FontWeight.w600)),
              Text('Left: ₹${_fmt(left)}',
                  style:
                      const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusBadge(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 9, fontWeight: FontWeight.bold)),
    );
  }
}

class _BankTile extends StatelessWidget {
  final dynamic acc;
  final Color themeColor;
  const _BankTile({required this.acc, required this.themeColor});

  @override
  Widget build(BuildContext context) {
    final isActive = acc['is_active'] == true;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive
              ? themeColor.withValues(alpha: 0.3)
              : Colors.grey.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color:
                  (isActive ? themeColor : Colors.grey).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.account_balance_rounded,
                color: isActive ? themeColor : Colors.grey, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(acc['bank_name'] ?? '',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                const Text('Bank Account',
                    style: TextStyle(color: Colors.grey, fontSize: 11)),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: (isActive ? Colors.green : Colors.orange)
                  .withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isActive ? 'Active' : 'Passive',
              style: TextStyle(
                color: isActive ? Colors.green : Colors.orange,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoanTile extends StatelessWidget {
  final dynamic loan;
  const _LoanTile({required this.loan});

  String _fmt(double v) => v.toInt().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: Colors.orangeAccent.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orangeAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.request_quote_rounded,
                color: Colors.orangeAccent, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(loan['name'] ?? '',
                style: const TextStyle(
                    fontWeight: FontWeight.w500, fontSize: 13)),
          ),
          Text('₹${_fmt((loan['emi'] ?? 0.0).toDouble())}/mo',
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.orangeAccent,
                  fontSize: 13)),
        ],
      ),
    );
  }
}

class _BillTile extends StatelessWidget {
  final dynamic exp;
  const _BillTile({required this.exp});

  String _fmt(double v) => v.toInt().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

  @override
  Widget build(BuildContext context) {
    final isVar = exp['is_variable'] == true;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: Colors.redAccent.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.receipt_long_rounded,
                color: Colors.redAccent, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(exp['name'] ?? '',
                    style: const TextStyle(
                        fontWeight: FontWeight.w500, fontSize: 13)),
                if (isVar)
                  const Text('Variable each month',
                      style:
                          TextStyle(color: Colors.grey, fontSize: 10)),
              ],
            ),
          ),
          Text(
            '₹${_fmt((exp['amount'] ?? 0.0).toDouble())}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isVar ? Colors.orangeAccent : Colors.redAccent,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  final dynamic category;
  final List<dynamic> subs;
  final Color themeColor;
  const _CategoryPill(
      {required this.category,
      required this.subs,
      required this.themeColor});

  static const Map<String, IconData> _icons = {
    'Food': Icons.fastfood_rounded,
    'Online order': Icons.delivery_dining_rounded,
    'Online store': Icons.shopping_bag_rounded,
    'NonVeg Raw items': Icons.set_meal_rounded,
    'Food Raw items': Icons.eco_rounded,
    'Restaurants': Icons.restaurant_rounded,
    'Fuel': Icons.local_gas_station_rounded,
    'Gas Cylinder': Icons.propane_tank_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final icon = _icons[category['name']] ?? Icons.category_rounded;
    return GestureDetector(
      onTap: subs.isNotEmpty
          ? () => _showSubs(context)
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: themeColor.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: themeColor),
            const SizedBox(width: 6),
            Text(category['name'] ?? '',
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            if (subs.isNotEmpty) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: themeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('${subs.length}',
                    style: TextStyle(
                        fontSize: 10,
                        color: themeColor,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showSubs(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(category['name'] ?? '',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: subs
                  .map((s) => Chip(
                        label: Text(s['name'] ?? '',
                            style: const TextStyle(fontSize: 12)),
                        avatar: Icon(Icons.arrow_right_rounded,
                            size: 16, color: themeColor),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _EmptyTile extends StatelessWidget {
  final String text;
  const _EmptyTile({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded,
              size: 16, color: Colors.grey[500]),
          const SizedBox(width: 8),
          Text(text,
              style: TextStyle(color: Colors.grey[500], fontSize: 12)),
        ],
      ),
    );
  }
}
