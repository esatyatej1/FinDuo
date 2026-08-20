import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../providers/settings_provider.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});
  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = context.watch<SettingsProvider>().themeColor;
    final finance = context.watch<FinanceProvider>();

    return Column(
      children: [
        Container(
          color: Theme.of(context).colorScheme.surface,
          child: TabBar(
            controller: _tabController,
            indicatorColor: themeColor,
            labelColor: themeColor,
            unselectedLabelColor: Colors.grey,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: const [
              Tab(icon: Icon(Icons.people_rounded, size: 18), text: 'Users'),
              Tab(icon: Icon(Icons.payments_rounded, size: 18), text: 'Income'),
              Tab(icon: Icon(Icons.account_balance_rounded, size: 18), text: 'Accounts'),
              Tab(icon: Icon(Icons.request_quote_rounded, size: 18), text: 'Loans'),
              Tab(icon: Icon(Icons.receipt_long_rounded, size: 18), text: 'Bills'),
              Tab(icon: Icon(Icons.category_rounded, size: 18), text: 'Categories'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _UsersTab(finance: finance, themeColor: themeColor),
              _IncomeTab(finance: finance, themeColor: themeColor),
              _AccountsTab(finance: finance, themeColor: themeColor),
              _LoansTab(finance: finance, themeColor: themeColor),
              _BillsTab(finance: finance, themeColor: themeColor),
              _CategoriesTab(finance: finance, themeColor: themeColor),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// USERS TAB — full CRUD: add, edit name/username/income/password, delete
// ─────────────────────────────────────────────────────────────────────────────
class _UsersTab extends StatelessWidget {
  final FinanceProvider finance;
  final Color themeColor;
  const _UsersTab({required this.finance, required this.themeColor});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _sectionHeader(context, 'User Management', 'Add, edit or remove users', themeColor),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: () => _showAddUserDialog(context, finance, themeColor),
          icon: Icon(Icons.person_add_rounded, color: themeColor, size: 18),
          label: Text('Add New User', style: TextStyle(color: themeColor)),
        ),
        const SizedBox(height: 8),
        ...finance.allUsers.map((user) => _AdminCard(
          title: user['name'] ?? '',
          subtitle: '@${user['username']}  •  ${context.read<SettingsProvider>().currency}${_fmt(user['monthly_income'], context.read<SettingsProvider>().conversionRate)}/mo',
          icon: Icons.person_rounded,
          themeColor: themeColor,
          onEdit: () => _showEditUserDialog(context, finance, user, themeColor),
          onDelete: () => _confirmDelete(
            context,
            'Delete user "${user['name']}"? All their data will be removed.',
            () async {
              await finance.deleteUser(user['id']);
              if (context.mounted) _showSnackbar(context, 'User deleted', Colors.redAccent);
            },
          ),
        )),
      ],
    );
  }

  void _showAddUserDialog(BuildContext context, FinanceProvider finance, Color themeColor) {
    final nameCtrl = TextEditingController();
    final userCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final incCtrl = TextEditingController(text: '0');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add New User'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameCtrl, decoration: InputDecoration(labelText: 'Full Name', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: userCtrl, decoration: InputDecoration(labelText: 'Username', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: passCtrl, obscureText: true, decoration: InputDecoration(labelText: 'Password', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: incCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Monthly Income (${context.read<SettingsProvider>().currency})', border: OutlineInputBorder())),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: themeColor),
            onPressed: () {
              finance.createUser({
                'name': nameCtrl.text,
                'username': userCtrl.text,
                'password': passCtrl.text,
                'monthly_income': double.tryParse(incCtrl.text) ?? 0,
              });
              Navigator.pop(ctx);
            },
            child: const Text('Add', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  void _showEditUserDialog(BuildContext context, FinanceProvider finance, Map user, Color themeColor) {
    final nameCtrl = TextEditingController(text: user['name'] ?? '');
    final userCtrl = TextEditingController(text: user['username'] ?? '');
    final incCtrl = TextEditingController(text: _fmt(user['monthly_income'], context.read<SettingsProvider>().conversionRate));
    final passCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit ${user['name']}'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameCtrl, decoration: InputDecoration(labelText: 'Full Name', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: userCtrl, decoration: InputDecoration(labelText: 'Username', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: incCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Monthly Income (${context.read<SettingsProvider>().currency})', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: passCtrl, obscureText: true, decoration: InputDecoration(labelText: 'New Password (leave blank to keep)', border: OutlineInputBorder())),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: themeColor),
            onPressed: () async {
              final data = <String, dynamic>{
                'name': nameCtrl.text,
                'username': userCtrl.text,
                'monthly_income': double.tryParse(incCtrl.text) ?? 0,
              };
              if (passCtrl.text.isNotEmpty) data['password'] = passCtrl.text;
              await finance.updateUser(user['id'], data);
              if (ctx.mounted) {
                Navigator.pop(ctx);
                _showSnackbar(context, 'User updated', Colors.green);
              }
            },
            child: const Text('Save', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INCOME TAB — edit name + income per user
// ─────────────────────────────────────────────────────────────────────────────
class _IncomeTab extends StatelessWidget {
  final FinanceProvider finance;
  final Color themeColor;
  const _IncomeTab({required this.finance, required this.themeColor});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _sectionHeader(context, 'Monthly Income', 'Edit income for each member', themeColor),
        const SizedBox(height: 16),
        ...finance.allUsers.map(
          (user) => _AdminCard(
            title: user['name'] ?? '',
            subtitle: '@${user['username']}  •  ${context.read<SettingsProvider>().currency}${_fmt(user['monthly_income'], context.read<SettingsProvider>().conversionRate)}/month',
            icon: Icons.person_rounded,
            themeColor: themeColor,
            onEdit: () => _showEditDialog(
              context,
              title: 'Edit Income – ${user['name']}',
              fields: {'name': user['name'] ?? '', 'income': _fmt(user['monthly_income'], context.read<SettingsProvider>().conversionRate)},
              onSave: (vals) async {
                final data = <String, dynamic>{};
                if (vals['name'] != user['name']) data['name'] = vals['name'];
                if (data.isNotEmpty) await finance.updateUser(user['id'], data);
                await finance.updateUserIncome(user['id'], double.tryParse(vals['income']!) ?? 0);
              },
              themeColor: themeColor,
            ),
          ),
        ),
      ],
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// ACCOUNTS TAB
// ─────────────────────────────────────────────────────────────────────────────
class _AccountsTab extends StatelessWidget {
  final FinanceProvider finance;
  final Color themeColor;
  const _AccountsTab({required this.finance, required this.themeColor});

  @override
  Widget build(BuildContext context) {
    final users = finance.allUsers;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _sectionHeader(
          context,
          'All Accounts',
          'Manage bank accounts and credit cards',
          themeColor,
        ),
        const SizedBox(height: 8),
        ...users.map((user) {
          final userAccounts = finance.allAccounts
              .where((a) => a['user_id'] == user['id'])
              .toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              _userLabel(context, user['name'] ?? '', themeColor),
              const SizedBox(height: 8),
              ...userAccounts.map((acc) {
                final isCC = acc['type'] == 'Credit Card';
                return _AdminCard(
                  title: '${acc['bank_name']} ${isCC ? "Credit Card" : "Bank"}',
                  subtitle: isCC
                      ? 'Limit: ${context.read<SettingsProvider>().currency}${_fmt(acc['limit'], context.read<SettingsProvider>().conversionRate)}  |  Left: ${context.read<SettingsProvider>().currency}${_fmt(acc['balance_left'], context.read<SettingsProvider>().conversionRate)}'
                      : acc['is_active'] == true
                      ? 'Active'
                      : 'Passive',
                  icon: isCC
                      ? Icons.credit_card_rounded
                      : Icons.account_balance_rounded,
                  themeColor: themeColor,
                  onEdit: () {
                    // Full edit for any account type
                    final bankCtrl = TextEditingController(text: acc['bank_name'] ?? '');
                    final limitCtrl = TextEditingController(text: _fmt(acc['limit'], context.read<SettingsProvider>().conversionRate));
                    final balCtrl = TextEditingController(text: _fmt(acc['balance_left'], context.read<SettingsProvider>().conversionRate));
                    bool isActiveState = acc['is_active'] == true;
                    showDialog(
                      context: context,
                      builder: (ctx) => StatefulBuilder(
                        builder: (ctx, setS) => AlertDialog(
                          title: Text('Edit ${acc['bank_name']}'),
                          content: SingleChildScrollView(
                            child: Column(mainAxisSize: MainAxisSize.min, children: [
                              TextField(controller: bankCtrl, decoration: InputDecoration(labelText: 'Bank Name', border: OutlineInputBorder())),
                              if (isCC) ...[
                                const SizedBox(height: 10),
                                TextField(controller: limitCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Credit Limit (${context.read<SettingsProvider>().currency})', border: OutlineInputBorder())),
                                const SizedBox(height: 10),
                                TextField(controller: balCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Balance Left (${context.read<SettingsProvider>().currency})', border: OutlineInputBorder())),
                              ] else ...[
                                const SizedBox(height: 8),
                                SwitchListTile(
                                  title: const Text('Active Account'),
                                  value: isActiveState,
                                  activeColor: themeColor,
                                  onChanged: (v) => setS(() => isActiveState = v),
                                ),
                              ],
                            ]),
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: themeColor),
                              onPressed: () {
                                final data = <String, dynamic>{'bank_name': bankCtrl.text};
                                if (isCC) {
                                  data['limit'] = double.tryParse(limitCtrl.text) ?? 0;
                                  data['balance_left'] = double.tryParse(balCtrl.text) ?? 0;
                                } else {
                                  data['is_active'] = isActiveState;
                                }
                                finance.updateAccount(acc['id'], data);
                                Navigator.pop(ctx);
                              },
                              child: const Text('Save', style: TextStyle(color: Colors.black)),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  onDelete: () =>
                      _confirmDelete(context, 'Delete this account?', () async {
                        await finance.deleteAccount(acc['id']);
                        if (context.mounted)
                          _showSnackbar(
                            context,
                            'Account deleted',
                            Colors.redAccent,
                          );
                      }),
                );
              }),
              // Add account button
              TextButton.icon(
                onPressed: () => _showAddAccountDialog(
                  context,
                  finance,
                  user['id'],
                  themeColor,
                ),
                icon: Icon(
                  Icons.add_circle_outline,
                  color: themeColor,
                  size: 18,
                ),
                label: Text(
                  'Add Account for ${(user['name'] as String).split(' ')[0]}',
                  style: TextStyle(color: themeColor, fontSize: 12),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  void _showAddAccountDialog(
    BuildContext context,
    FinanceProvider finance,
    int userId,
    Color themeColor,
  ) {
    String selectedType = 'Bank';
    final bankCtrl = TextEditingController();
    final limitCtrl = TextEditingController(text: '0');
    final balCtrl = TextEditingController(text: '0');
    bool isActive = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Add New Account'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: InputDecoration(
                    labelText: 'Account Type',
                    border: OutlineInputBorder(),
                  ),
                  items: ['Bank', 'Credit Card']
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) => setS(() => selectedType = v!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bankCtrl,
                  decoration: InputDecoration(
                    labelText: 'Bank Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (selectedType == 'Credit Card') ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: limitCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Credit Limit (${context.read<SettingsProvider>().currency})',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: balCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Balance Left (${context.read<SettingsProvider>().currency})',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Active Account'),
                    value: isActive,
                    activeColor: themeColor,
                    onChanged: (v) => setS(() => isActive = v),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                finance.createAccount({
                  'user_id': userId,
                  'account_type': selectedType,
                  'bank_name': bankCtrl.text,
                  'is_active': isActive,
                  'limit': double.tryParse(limitCtrl.text) ?? 0,
                  'balance_left': double.tryParse(balCtrl.text) ?? 0,
                });
                Navigator.pop(ctx);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LOANS TAB
// ─────────────────────────────────────────────────────────────────────────────
class _LoansTab extends StatelessWidget {
  final FinanceProvider finance;
  final Color themeColor;
  const _LoansTab({required this.finance, required this.themeColor});

  @override
  Widget build(BuildContext context) {
    final users = finance.allUsers;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _sectionHeader(
          context,
          'Loan EMIs',
          'Manage all active loans and EMIs',
          themeColor,
        ),
        ...users.map((user) {
          final userLoans = finance.allLoans
              .where((l) => l['user_id'] == user['id'])
              .toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              _userLabel(context, user['name'] ?? '', themeColor),
              const SizedBox(height: 8),
              ...userLoans.map(
                (loan) => _AdminCard(
                  title: loan['name'] ?? '',
                  subtitle: loan['is_active'] == false
                      ? 'Finished • EMI: ${context.read<SettingsProvider>().currency}${_fmt(loan['emi'], context.read<SettingsProvider>().conversionRate)}/month'
                      : 'EMI: ${context.read<SettingsProvider>().currency}${_fmt(loan['emi'], context.read<SettingsProvider>().conversionRate)}/month',
                  icon: loan['is_active'] == false
                      ? Icons.check_circle_rounded
                      : Icons.request_quote_rounded,
                  themeColor: loan['is_active'] == false
                      ? Colors.grey
                      : themeColor,
                  onEdit: () => _showEditDialog(
                    context,
                    title: 'Edit ${loan['name']}',
                    fields: {
                      'loan_name': loan['name'] ?? '',
                      'emi_amount': _fmt(loan['emi'], context.read<SettingsProvider>().conversionRate),
                      'lender': loan['lender'] ?? '',
                      'notes': loan['notes'] ?? '',
                    },
                    onSave: (vals) async {
                      await finance.updateLoan(loan['id'], {
                        'loan_name': vals['loan_name'],
                        'emi_amount': double.tryParse(vals['emi_amount']!) ?? 0,
                        'lender': vals['lender'],
                        'notes': vals['notes'],
                      });
                      if (context.mounted)
                        _showSnackbar(context, 'Loan updated', Colors.green);
                    },
                    themeColor: themeColor,
                  ),
                  onDelete: () =>
                      _confirmDelete(context, 'Delete this loan?', () async {
                        await finance.deleteLoan(loan['id']);
                        if (context.mounted)
                          _showSnackbar(
                            context,
                            'Loan deleted',
                            Colors.redAccent,
                          );
                      }),
                  extraAction: loan['is_active'] == false
                      ? IconButton(
                          icon: const Icon(
                            Icons.refresh_rounded,
                            size: 18,
                            color: Colors.blueAccent,
                          ),
                          onPressed: () => _confirmAction(
                            context,
                            'Re-activate Loan',
                            'Mark this loan as active again?',
                            'Re-activate',
                            () async {
                              await finance.updateLoan(loan['id'], {
                                'is_active': true,
                              });
                              if (context.mounted)
                                _showSnackbar(
                                  context,
                                  'Loan re-activated',
                                  Colors.blueAccent,
                                );
                            },
                          ),
                          tooltip: 'Re-activate',
                        )
                      : IconButton(
                          icon: const Icon(
                            Icons.check_circle_outline,
                            size: 18,
                            color: Colors.green,
                          ),
                          onPressed: () => _confirmAction(
                            context,
                            'Finish Loan',
                            'Mark this loan as finished?',
                            'Finish',
                            () async {
                              await finance.updateLoan(loan['id'], {
                                'is_active': false,
                              });
                              if (context.mounted)
                                _showSnackbar(
                                  context,
                                  'Loan marked as finished! 🎉',
                                  Colors.green,
                                );
                            },
                          ),
                          tooltip: 'Mark Finished',
                        ),
                ),
              ),
              TextButton.icon(
                onPressed: () => _showAddLoanDialog(
                  context,
                  finance,
                  user['id'],
                  themeColor,
                ),
                icon: Icon(
                  Icons.add_circle_outline,
                  color: themeColor,
                  size: 18,
                ),
                label: Text(
                  'Add Loan for ${(user['name'] as String).split(' ')[0]}',
                  style: TextStyle(color: themeColor, fontSize: 12),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  void _showAddLoanDialog(
    BuildContext context,
    FinanceProvider finance,
    int userId,
    Color themeColor,
  ) {
    final nameCtrl = TextEditingController();
    final emiCtrl = TextEditingController();
    final lenderCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add New Loan'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: InputDecoration(labelText: 'Loan Name', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: emiCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Monthly EMI (${context.read<SettingsProvider>().currency})', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: lenderCtrl, decoration: InputDecoration(labelText: 'Lender (Bank/Person)', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: notesCtrl, maxLines: 2, decoration: InputDecoration(labelText: 'Notes (optional)', border: OutlineInputBorder())),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: themeColor),
            onPressed: () {
              finance.createLoan({
                'user_id': userId,
                'loan_name': nameCtrl.text,
                'emi_amount': double.tryParse(emiCtrl.text) ?? 0,
                'lender': lenderCtrl.text,
                'notes': notesCtrl.text,
              });
              Navigator.pop(ctx);
            },
            child: const Text('Add', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BILLS TAB
// ─────────────────────────────────────────────────────────────────────────────
class _BillsTab extends StatelessWidget {
  final FinanceProvider finance;
  final Color themeColor;
  const _BillsTab({required this.finance, required this.themeColor});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _sectionHeader(
          context,
          'Fixed Monthly Bills',
          'House rent, utilities, subscriptions',
          themeColor,
        ),
        const SizedBox(height: 16),
        ...finance.expenses.map(
          (exp) {
            bool isVar = exp['is_variable'] == true;
            return _AdminCard(
              title: exp['name'] ?? '',
              subtitle: '${context.read<SettingsProvider>().currency}${_fmt(exp['amount'], context.read<SettingsProvider>().conversionRate)}${exp['notes'] != null && (exp['notes'] as String).isNotEmpty ? '  •  ${exp['notes']}' : ''}${isVar ? '  (variable)' : ''}',
              icon: Icons.receipt_long_rounded,
              themeColor: themeColor,
              onEdit: () {
                final nameCtrl = TextEditingController(text: exp['name'] ?? '');
                final amtCtrl = TextEditingController(text: _fmt(exp['amount'], context.read<SettingsProvider>().conversionRate));
                final notesCtrl = TextEditingController(text: exp['notes'] ?? '');
                bool varFlag = isVar;
                showDialog(
                  context: context,
                  builder: (ctx) => StatefulBuilder(
                    builder: (ctx, setS) => AlertDialog(
                      title: Text('Edit ${exp['name']}'),
                      content: SingleChildScrollView(
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          TextField(controller: nameCtrl, decoration: InputDecoration(labelText: 'Bill Name', border: OutlineInputBorder())),
                          const SizedBox(height: 10),
                          TextField(controller: amtCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Amount (${context.read<SettingsProvider>().currency})', border: OutlineInputBorder())),
                          const SizedBox(height: 10),
                          TextField(controller: notesCtrl, decoration: InputDecoration(labelText: 'Notes (optional)', border: OutlineInputBorder())),
                          SwitchListTile(
                            title: const Text('Variable amount?'),
                            value: varFlag,
                            activeColor: themeColor,
                            onChanged: (v) => setS(() => varFlag = v),
                          ),
                        ]),
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: themeColor),
                          onPressed: () {
                            finance.updateExpense(exp['id'], {
                              'name': nameCtrl.text,
                              'amount': double.tryParse(amtCtrl.text) ?? 0,
                              'is_variable': varFlag,
                              'notes': notesCtrl.text,
                            });
                            Navigator.pop(ctx);
                          },
                          child: const Text('Save', style: TextStyle(color: Colors.black)),
                        ),
                      ],
                    ),
                  ),
                );
              },
              onDelete: () => _confirmDelete(context, 'Delete this bill?', () async {
                await finance.deleteExpense(exp['id']);
                if (context.mounted) _showSnackbar(context, 'Bill deleted', Colors.redAccent);
              }),
            );
          },
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () => _showAddBillDialog(context, finance, themeColor),
          icon: Icon(Icons.add_circle_outline, color: themeColor, size: 18),
          label: Text('Add New Bill', style: TextStyle(color: themeColor)),
        ),
      ],
    );
  }

  void _showAddBillDialog(
    BuildContext context,
    FinanceProvider finance,
    Color themeColor,
  ) {
    final nameCtrl = TextEditingController();
    final amtCtrl = TextEditingController();
    bool isVariable = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Add Fixed Bill'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Bill Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amtCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Amount (${context.read<SettingsProvider>().currency})',
                  border: OutlineInputBorder(),
                ),
              ),
              SwitchListTile(
                title: const Text('Variable amount?'),
                value: isVariable,
                activeColor: themeColor,
                onChanged: (v) => setS(() => isVariable = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                finance.createExpense({
                  'name': nameCtrl.text,
                  'amount': double.tryParse(amtCtrl.text) ?? 0,
                  'is_variable': isVariable,
                  'notes': '',
                });
                Navigator.pop(ctx);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CATEGORIES TAB
// ─────────────────────────────────────────────────────────────────────────────
class _CategoriesTab extends StatelessWidget {
  final FinanceProvider finance;
  final Color themeColor;
  const _CategoriesTab({required this.finance, required this.themeColor});

  @override
  Widget build(BuildContext context) {
    final parents = finance.parentCategories;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _sectionHeader(
          context,
          'Transaction Categories',
          'Manage categories and sub-categories',
          themeColor,
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () =>
              _showAddCategoryDialog(context, finance, null, themeColor),
          icon: Icon(Icons.add_circle_outline, color: themeColor, size: 18),
          label: Text(
            'Add Parent Category',
            style: TextStyle(color: themeColor),
          ),
        ),
        const SizedBox(height: 8),
        ...parents.map((cat) {
          final subs = finance.subCategoriesOf(cat['id']);
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: ExpansionTile(
              leading: Icon(Icons.category_rounded, color: themeColor),
              title: Text(
                cat['name'] ?? '',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                '${subs.length} sub-categories',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.edit_rounded, size: 18, color: themeColor),
                    onPressed: () => _showEditDialog(
                      context,
                      title: 'Rename Category',
                      fields: {'name': cat['name'] ?? ''},
                      onSave: (vals) => finance.updateCategory(cat['id'], {
                        'name': vals['name'],
                        'parent_id': null,
                      }),
                      themeColor: themeColor,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      size: 18,
                      color: Colors.redAccent,
                    ),
                    onPressed: () => _confirmDelete(
                      context,
                      'Delete category and all sub-categories?',
                      () => finance.deleteCategory(cat['id']),
                    ),
                  ),
                  const Icon(Icons.expand_more_rounded),
                ],
              ),
              children: [
                ...subs.map(
                  (sub) => ListTile(
                    contentPadding: const EdgeInsets.only(left: 32, right: 12),
                    leading: Icon(
                      Icons.arrow_right_rounded,
                      color: Colors.grey[500],
                    ),
                    title: Text(
                      sub['name'] ?? '',
                      style: const TextStyle(fontSize: 13),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.edit_rounded,
                            size: 16,
                            color: themeColor,
                          ),
                          onPressed: () => _showEditDialog(
                            context,
                            title: 'Rename Sub-Category',
                            fields: {'name': sub['name'] ?? ''},
                            onSave: (vals) => finance.updateCategory(
                              sub['id'],
                              {'name': vals['name'], 'parent_id': cat['id']},
                            ),
                            themeColor: themeColor,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 16,
                            color: Colors.redAccent,
                          ),
                          onPressed: () => _confirmDelete(
                            context,
                            'Delete this sub-category?',
                            () => finance.deleteCategory(sub['id']),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                ListTile(
                  contentPadding: const EdgeInsets.only(left: 32, right: 12),
                  leading: Icon(
                    Icons.add_circle_outline,
                    color: themeColor,
                    size: 18,
                  ),
                  title: Text(
                    'Add sub-category',
                    style: TextStyle(color: themeColor, fontSize: 12),
                  ),
                  onTap: () => _showAddCategoryDialog(
                    context,
                    finance,
                    cat['id'],
                    themeColor,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  void _showAddCategoryDialog(
    BuildContext context,
    FinanceProvider finance,
    int? parentId,
    Color themeColor,
  ) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(parentId == null ? 'Add Category' : 'Add Sub-Category'),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(
            labelText: 'Name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              finance.createCategory({
                'name': ctrl.text,
                'parent_id': parentId,
                'icon': 'category',
              });
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED HELPERS
// ─────────────────────────────────────────────────────────────────────────────
String _fmt(dynamic val, [double rate = 1.0]) {
    final v = (double.tryParse(val.toString()) ?? 0.0) * rate;
  if (val == null) return '0';
  final d = (val is double) ? val : double.tryParse(val.toString()) ?? 0.0;
  return d.toStringAsFixed(d == d.roundToDouble() ? 0 : 2);
}

void _showSnackbar(BuildContext context, String message, Color color) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(
            color == Colors.redAccent
                ? Icons.delete_rounded
                : Icons.check_circle_rounded,
            color: Colors.white,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(message),
        ],
      ),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 2),
    ),
  );
}

Widget _sectionHeader(
  BuildContext context,
  String title,
  String subtitle,
  Color themeColor,
) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
      ),
      Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
    ],
  );
}

Widget _userLabel(BuildContext context, String name, Color themeColor) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: themeColor.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.person_rounded, size: 14, color: themeColor),
        const SizedBox(width: 6),
        Text(
          name,
          style: TextStyle(
            color: themeColor,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ],
    ),
  );
}

void _confirmDelete(
  BuildContext context,
  String message,
  VoidCallback onConfirm,
) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Confirm Delete'),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
          onPressed: () {
            Navigator.pop(ctx);
            onConfirm();
          },
          child: const Text('Delete', style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
}

void _confirmAction(
  BuildContext context,
  String title,
  String message,
  String buttonText,
  VoidCallback onConfirm,
) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(ctx);
            onConfirm();
          },
          child: Text(buttonText),
        ),
      ],
    ),
  );
}

void _showEditDialog(
  BuildContext context, {
  required String title,
  required Map<String, String> fields,
  required Function(Map<String, String>) onSave,
  required Color themeColor,
}) {
  final controllers = fields.map(
    (k, v) => MapEntry(k, TextEditingController(text: v)),
  );
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: controllers.entries
              .map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextField(
                    controller: e.value,
                    keyboardType: RegExp(r'\d').hasMatch(fields[e.key] ?? '')
                        ? TextInputType.number
                        : TextInputType.text,
                    decoration: InputDecoration(
                      labelText: e.key
                          .replaceAll('_', ' ')
                          .replaceFirst(e.key[0], e.key[0].toUpperCase()),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: themeColor),
          onPressed: () {
            onSave(controllers.map((k, c) => MapEntry(k, c.text)));
            Navigator.pop(ctx);
          },
          child: const Text('Save', style: TextStyle(color: Colors.black)),
        ),
      ],
    ),
  );
}

class _AdminCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color themeColor;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;
  final Widget? extraAction;

  const _AdminCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.themeColor,
    required this.onEdit,
    this.onDelete,
    this.extraAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: themeColor.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: themeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: themeColor, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.edit_rounded, size: 18, color: themeColor),
            onPressed: onEdit,
            tooltip: 'Edit',
          ),
          if (onDelete != null)
            IconButton(
              icon: const Icon(
                Icons.delete_outline_rounded,
                size: 18,
                color: Colors.redAccent,
              ),
              onPressed: onDelete,
              tooltip: 'Delete',
            ),
          if (extraAction != null) extraAction!,
        ],
      ),
    );
  }
}
