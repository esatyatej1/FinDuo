import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/finance_provider.dart';
import '../providers/settings_provider.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final finance = context.read<FinanceProvider>();
      if (finance.monthlyTrend.isEmpty) {
        finance.fetchAnalytics();
      }
      if (finance.transactions.isEmpty) {
        finance.fetchTransactions();
      }
    });
  }

  String _fmtFull(double v, String c, [double rate = 1.0]) =>
      '${c}${(v * rate).toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final finance = context.watch<FinanceProvider>();
    final themeColor = context.watch<SettingsProvider>().themeColor;

    if (finance.isLoading && finance.monthlyTrend.isEmpty) {
      return Center(child: CircularProgressIndicator(color: themeColor));
    }

    final trend = finance.monthlyTrend;
    final txns = finance.transactions;
    final summary = finance.txnSummary;
    final total = (summary['total'] ?? 0.0).toDouble();
    final income = (finance.userData['monthly_income'] ?? 0.0).toDouble();
    final totalEMIs = finance.myLoans.fold<double>(
      0,
      (s, l) => s + (l['emi'] ?? 0.0),
    );
    final totalBills = finance.expenses.fold<double>(
      0,
      (s, e) => s + (e['amount'] ?? 0.0),
    );

    // Category breakdown from current month transactions
    final Map<String, double> catBreakdown = {};
    for (final t in txns) {
      final catId = t['category_id'];
      String catName = 'Uncategorized';
      if (catId != null) {
        final cat = finance.categories.firstWhere(
          (c) => c['id'] == catId,
          orElse: () => {'name': 'Other'},
        );
        catName = cat['name'] ?? 'Other';
      }
      catBreakdown[catName] =
          (catBreakdown[catName] ?? 0) + (t['amount'] ?? 0.0).toDouble();
    }
    final sortedCats = catBreakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Payment method breakdown
    final Map<String, double> methodBreak = {};
    for (final t in txns) {
      final m = t['payment_method'] ?? 'UPI';
      methodBreak[m] = (methodBreak[m] ?? 0) + (t['amount'] ?? 0.0).toDouble();
    }

    return RefreshIndicator(
      color: themeColor,
      onRefresh: () async {
        await finance.fetchAnalytics();
        await finance.fetchTransactions();
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          // ── Monthly Budget Overview ───────────────────────────────
          _SectionHeader(
            title: 'This Month',
            icon: Icons.calendar_today_rounded,
          ),
          const SizedBox(height: 10),
          _BudgetSummaryCard(
            income: income,
            totalEMIs: totalEMIs,
            totalBills: totalBills,
            spentThisMonth: total,
            themeColor: themeColor,
          ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),
          const SizedBox(height: 20),

          // ── 6-Month Trend ─────────────────────────────────────────
          if (trend.isNotEmpty) ...[
            _SectionHeader(
              title: '6-Month Transaction Trend',
              icon: Icons.trending_up_rounded,
            ),
            const SizedBox(height: 10),
            _TrendLineChart(trend: trend, themeColor: themeColor),
            const SizedBox(height: 20),
          ],

          // ── Category Breakdown ────────────────────────────────────
          if (sortedCats.isNotEmpty) ...[
            _SectionHeader(
              title: 'Transactions by Category',
              icon: Icons.pie_chart_rounded,
            ),
            const SizedBox(height: 10),
            _CategoryPieSection(
              cats: sortedCats,
              total: total,
              themeColor: themeColor,
            ).animate().fadeIn(duration: 500.ms, delay: 100.ms),
            const SizedBox(height: 20),
          ],

          // ── Payment Methods ───────────────────────────────────────
          if (methodBreak.isNotEmpty) ...[
            _SectionHeader(
              title: 'Payment Methods',
              icon: Icons.payment_rounded,
            ),
            const SizedBox(height: 10),
            _PaymentMethodBars(
              methods: methodBreak,
              total: total,
              themeColor: themeColor,
            ).animate().fadeIn(duration: 500.ms, delay: 200.ms),
            const SizedBox(height: 20),
          ],

          // ── Top Transactions ──────────────────────────────────────
          _SectionHeader(
            title: 'Top Transactions This Month',
            icon: Icons.arrow_upward_rounded,
          ),
          const SizedBox(height: 10),
          ..._getTopTxns(txns, finance, themeColor, 5).asMap().entries.map(
            (e) => e.value.animate().fadeIn(
              duration: 300.ms,
              delay: Duration(milliseconds: e.key * 50),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _getTopTxns(
    List<dynamic> txns,
    FinanceProvider finance,
    Color themeColor,
    int limit,
  ) {
    if (txns.isEmpty) {
      return [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 16, color: Colors.grey),
              SizedBox(width: 8),
              Text(
                'No transactions this month',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
      ];
    }
    final sorted = [...txns]
      ..sort((a, b) => (b['amount'] ?? 0.0).compareTo(a['amount'] ?? 0.0));
    return sorted.take(limit).map((t) {
      final amount = (t['amount'] ?? 0.0).toDouble();
      final catId = t['category_id'];
      String catName = 'Uncategorized';
      if (catId != null) {
        final cat = finance.categories.firstWhere(
          (c) => c['id'] == catId,
          orElse: () => {'name': 'Other'},
        );
        catName = cat['name'] ?? 'Other';
      }
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: themeColor.withValues(alpha: 0.12)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.arrow_outward_rounded,
                color: Colors.redAccent,
                size: 16,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t['title']?.toString().isNotEmpty == true
                        ? t['title']
                        : catName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    t['txn_date'] ?? '',
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ],
              ),
            ),
            Text(
              _fmtFull(amount,  context.read<SettingsProvider>().currency, context.read<SettingsProvider>().conversionRate),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.redAccent,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 6),
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _BudgetSummaryCard extends StatelessWidget {
  final double income, totalEMIs, totalBills, spentThisMonth;
  final Color themeColor;

  const _BudgetSummaryCard({
    required this.income,
    required this.totalEMIs,
    required this.totalBills,
    required this.spentThisMonth,
    required this.themeColor,
  });

  String _fmt(double v, String c, [double rate = 1.0]) =>
      '${c}${(v * rate).toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';

  @override
  Widget build(BuildContext context) {
    final committed = totalEMIs + totalBills;
    final spendable = (income - committed).clamp(0.0, double.infinity);
    final pct = spendable > 0
        ? (spentThisMonth / spendable).clamp(0.0, 1.0)
        : 0.0;
    final color = pct > 0.9
        ? Colors.redAccent
        : pct > 0.7
        ? Colors.orange
        : Colors.green;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            themeColor.withValues(alpha: 0.15),
            themeColor.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: themeColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Discretionary Budget',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  Text(
                    _fmt(spendable,  context.read<SettingsProvider>().currency, context.read<SettingsProvider>().conversionRate),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: themeColor,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${(pct * 100).toStringAsFixed(0)}% used',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: color.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _Stat(label: 'Income', value: _fmt(income,  context.read<SettingsProvider>().currency, context.read<SettingsProvider>().conversionRate), color: Colors.green),
              const SizedBox(width: 16),
              _Stat(
                label: 'Committed',
                value: _fmt(committed,  context.read<SettingsProvider>().currency, context.read<SettingsProvider>().conversionRate),
                color: Colors.orange,
              ),
              const SizedBox(width: 16),
              _Stat(
                label: 'Spent',
                value: _fmt(spentThisMonth,  context.read<SettingsProvider>().currency, context.read<SettingsProvider>().conversionRate),
                color: Colors.redAccent,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _Stat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _TrendLineChart extends StatelessWidget {
  final List<Map<String, dynamic>> trend;
  final Color themeColor;

  const _TrendLineChart({required this.trend, required this.themeColor});

  @override
  Widget build(BuildContext context) {
    if (trend.isEmpty) return const SizedBox();

    final maxVal = trend.fold<double>(0, (max, e) {
      final v = (e['total'] ?? 0.0).toDouble();
      return v > max ? v : max;
    });

    final spots = trend.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), (e.value['total'] ?? 0.0).toDouble());
    }).toList();

    return Container(
      height: 200,
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: themeColor.withValues(alpha: 0.15)),
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            horizontalInterval: maxVal > 0 ? maxVal / 4 : 1,
            getDrawingHorizontalLine: (v) => FlLine(
              color: Colors.grey.withValues(alpha: 0.1),
              strokeWidth: 1,
            ),
            getDrawingVerticalLine: (v) => FlLine(
              color: Colors.grey.withValues(alpha: 0.05),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 48,
                getTitlesWidget: (v, meta) {
                  if (v == 0) return const SizedBox();
                  return Text(
                    v >= 1000
                        ? '${(v / 1000).toStringAsFixed(0)}k'
                        : v.toInt().toString(),
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, meta) {
                  final idx = v.toInt();
                  if (idx < 0 || idx >= trend.length) return const SizedBox();
                  final month = trend[idx]['month']?.toString() ?? '';
                  final parts = month.split('-');
                  if (parts.length < 2) return const SizedBox();
                  const names = [
                    '',
                    'Jan',
                    'Feb',
                    'Mar',
                    'Apr',
                    'May',
                    'Jun',
                    'Jul',
                    'Aug',
                    'Sep',
                    'Oct',
                    'Nov',
                    'Dec',
                  ];
                  final mNum = int.tryParse(parts[1]) ?? 0;
                  return Text(
                    mNum > 0 && mNum <= 12 ? names[mNum] : '',
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: themeColor,
              barWidth: 2.5,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, pct, bar, idx) => FlDotCirclePainter(
                  radius: 4,
                  color: themeColor,
                  strokeWidth: 2,
                  strokeColor: Theme.of(context).colorScheme.surface,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    themeColor.withValues(alpha: 0.25),
                    themeColor.withValues(alpha: 0.0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
          minY: 0,
          maxY: maxVal * 1.2,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

const List<Color> _chartColors = [
  Color(0xFF6366F1),
  Color(0xFF10B981),
  Color(0xFFF59E0B),
  Color(0xFFEF4444),
  Color(0xFF8B5CF6),
  Color(0xFF06B6D4),
  Color(0xFFF97316),
  Color(0xFFEC4899),
];

class _CategoryPieSection extends StatefulWidget {
  final List<MapEntry<String, double>> cats;
  final double total;
  final Color themeColor;

  const _CategoryPieSection({
    required this.cats,
    required this.total,
    required this.themeColor,
  });

  @override
  State<_CategoryPieSection> createState() => _CategoryPieSectionState();
}

class _CategoryPieSectionState extends State<_CategoryPieSection> {
  int _touchedIndex = -1;

  String _fmt(double v, String c, [double rate = 1.0]) =>
      '${c}${(v * rate).toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';

  @override
  Widget build(BuildContext context) {
    final cats = widget.cats.take(8).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: widget.themeColor.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 180,
            child: Row(
              children: [
                Expanded(
                  child: PieChart(
                    PieChartData(
                      pieTouchData: PieTouchData(
                        touchCallback: (evt, resp) {
                          setState(() {
                            if (resp == null || resp.touchedSection == null) {
                              _touchedIndex = -1;
                            } else {
                              _touchedIndex =
                                  resp.touchedSection!.touchedSectionIndex;
                            }
                          });
                        },
                      ),
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                      sections: cats.asMap().entries.map((e) {
                        final isTouched = e.key == _touchedIndex;
                        final color = _chartColors[e.key % _chartColors.length];
                        final pct = widget.total > 0
                            ? e.value.value / widget.total * 100
                            : 0.0;
                        return PieChartSectionData(
                          value: e.value.value,
                          color: color,
                          radius: isTouched ? 70 : 60,
                          title: isTouched ? '${pct.toStringAsFixed(0)}%' : '',
                          titleStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: cats.asMap().entries.map((e) {
                    final color = _chartColors[e.key % _chartColors.length];
                    final pct = widget.total > 0
                        ? e.value.value / widget.total * 100
                        : 0.0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            e.value.key.length > 14
                                ? '${e.value.key.substring(0, 12)}…'
                                : e.value.key,
                            style: const TextStyle(fontSize: 11),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${pct.toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 10,
                              color: color,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const Divider(height: 20),
          ...cats.map((e) {
            final idx = cats.indexOf(e);
            final color = _chartColors[idx % _chartColors.length];
            final pct = widget.total > 0 ? e.value / widget.total * 100 : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      e.key,
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    _fmt(e.value, widget.themeColor == null ? '${context.read<SettingsProvider>().currency}' : context.read<SettingsProvider>().currency, context.read<SettingsProvider>().conversionRate),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 60,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct / 100,
                        minHeight: 4,
                        backgroundColor: color.withValues(alpha: 0.1),
                        valueColor: AlwaysStoppedAnimation(color),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _PaymentMethodBars extends StatelessWidget {
  final Map<String, double> methods;
  final double total;
  final Color themeColor;

  const _PaymentMethodBars({
    required this.methods,
    required this.total,
    required this.themeColor,
  });

  String _fmt(double v, String c, [double rate = 1.0]) =>
      '${c}${(v * rate).toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';

  IconData _methodIcon(String m) {
    switch (m) {
      case 'UPI':
        return Icons.phone_android_rounded;
      case 'Cash':
        return Icons.money_rounded;
      case 'Credit Card':
        return Icons.credit_card_rounded;
      case 'Debit Card':
        return Icons.payment_rounded;
      default:
        return Icons.attach_money_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sorted = methods.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: themeColor.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: sorted.asMap().entries.map((entry) {
          final e = entry.value;
          final color = _chartColors[entry.key % _chartColors.length];
          final pct = total > 0 ? e.value / total : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(_methodIcon(e.key), color: color, size: 14),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            e.key,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            _fmt(e.value,  context.read<SettingsProvider>().currency, context.read<SettingsProvider>().conversionRate),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct,
                          minHeight: 5,
                          backgroundColor: color.withValues(alpha: 0.1),
                          valueColor: AlwaysStoppedAnimation(color),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${(pct * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
