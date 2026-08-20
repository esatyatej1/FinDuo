import 'package:flutter/material.dart';
import '../services/api_service.dart';

class FinanceProvider with ChangeNotifier {
  final ApiService _api = ApiService();

  List<dynamic> _myAccounts = [];
  List<dynamic> _allAccounts = [];
  List<dynamic> _myLoans = [];
  List<dynamic> _allLoans = [];
  List<dynamic> _expenses = [];
  List<dynamic> _categories = [];
  Map<String, dynamic> _userData = {};
  List<dynamic> _allUsers = [];
  bool _isLoading = false;
  String? _error;

  List<dynamic> get myAccounts => _myAccounts;
  List<dynamic> get allAccounts => _allAccounts;
  List<dynamic> get myLoans => _myLoans;
  List<dynamic> get allLoans => _allLoans;
  List<dynamic> get expenses => _expenses;
  List<dynamic> get categories => _categories;
  Map<String, dynamic> get userData => _userData;
  List<dynamic> get allUsers => _allUsers;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Backward compat alias
  List<dynamic> get accounts => _myAccounts;
  List<dynamic> get loans => _myLoans;

  // Derived: parent categories only
  List<dynamic> get parentCategories =>
      _categories.where((c) => c['parent_id'] == null).toList();

  // Get sub-categories for a parent
  List<dynamic> subCategoriesOf(int parentId) =>
      _categories.where((c) => c['parent_id'] == parentId).toList();

  Future<void> fetchData() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _userData = await _api.getMe();
      _myAccounts = await _api.getMyAccounts();
      _myLoans = await _api.getMyLoans();
      _expenses = await _api.getExpenses();
      _categories = await _api.getCategories();
      _allUsers = await _api.getAllUsers();
      _allAccounts = await _api.getAllAccounts();
      _allLoans = await _api.getAllLoans();
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
    }
    _isLoading = false;
    notifyListeners();
  }

  // ─── Income ─────────────────────────────────────────────────────
  Future<void> updateUserIncome(int userId, double income) async {
    await _api.updateUserIncome(userId, income);
    await fetchData();
  }

  // ─── Users CRUD ─────────────────────────────────────────────────
  Future<void> createUser(Map<String, dynamic> data) async {
    await _api.createUser(data);
    await fetchData();
  }

  Future<void> updateUser(int id, Map<String, dynamic> data) async {
    await _api.updateUser(id, data);
    await fetchData();
  }

  Future<void> deleteUser(int id) async {
    await _api.deleteUser(id);
    await fetchData();
  }

  Future<void> updateMyProfile(Map<String, dynamic> data) async {
    await _api.updateMyProfile(data);
    await fetchData();
  }

  // ─── Accounts ───────────────────────────────────────────────────
  Future<void> createAccount(Map<String, dynamic> data) async {
    await _api.createAccount(data);
    await fetchData();
  }

  Future<void> updateAccount(int id, Map<String, dynamic> data) async {
    await _api.updateAccount(id, data);
    await fetchData();
  }

  Future<void> deleteAccount(int id) async {
    await _api.deleteAccount(id);
    await fetchData();
  }

  // ─── Loans ──────────────────────────────────────────────────────
  Future<void> createLoan(Map<String, dynamic> data) async {
    await _api.createLoan(data);
    await fetchData();
  }

  Future<void> updateLoan(int id, Map<String, dynamic> data) async {
    await _api.updateLoan(id, data);
    await fetchData();
  }

  Future<void> deleteLoan(int id) async {
    await _api.deleteLoan(id);
    await fetchData();
  }

  // ─── Expenses ───────────────────────────────────────────────────
  Future<void> createExpense(Map<String, dynamic> data) async {
    await _api.createExpense(data);
    await fetchData();
  }

  Future<void> updateExpense(int id, Map<String, dynamic> data) async {
    await _api.updateExpense(id, data);
    await fetchData();
  }

  Future<void> deleteExpense(int id) async {
    await _api.deleteExpense(id);
    await fetchData();
  }

  // ─── Categories ─────────────────────────────────────────────────
  Future<void> createCategory(Map<String, dynamic> data) async {
    await _api.createCategory(data);
    await fetchData();
  }

  Future<void> updateCategory(int id, Map<String, dynamic> data) async {
    await _api.updateCategory(id, data);
    await fetchData();
  }

  Future<void> deleteCategory(int id) async {
    await _api.deleteCategory(id);
    await fetchData();
  }

  // ─── Transactions ────────────────────────────────────────────────
  List<dynamic> _transactions = [];
  Map<String, dynamic> _txnSummary = {};
  String _selectedMonth = '';

  List<dynamic> get transactions => _transactions;
  Map<String, dynamic> get txnSummary => _txnSummary;
  String get selectedMonth => _selectedMonth;

  Future<void> fetchTransactions({String? month}) async {
    final m = month ?? _selectedMonth;
    if (m.isEmpty) {
      final now = DateTime.now();
      _selectedMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    } else {
      _selectedMonth = m;
    }
    _isLoading = true;
    notifyListeners();
    try {
      _transactions = await _api.getTransactions(month: _selectedMonth);
      _txnSummary = await _api.getTransactionSummary(month: _selectedMonth);
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> createTransaction(Map<String, dynamic> data) async {
    await _api.createTransaction(data);
    await fetchTransactions();
    // Refresh dashboard data too since account balances may have changed
    _fetchDashboardSilently();
  }

  Future<void> updateTransaction(int id, Map<String, dynamic> data) async {
    await _api.updateTransaction(id, data);
    await fetchTransactions();
    _fetchDashboardSilently();
  }

  Future<void> deleteTransaction(int id) async {
    await _api.deleteTransaction(id);
    await fetchTransactions();
    _fetchDashboardSilently();
  }

  // ─── AI Chat ─────────────────────────────────────────────────────
  Future<String> chatWithAi(List<Map<String, dynamic>> messages) async {
    return await _api.chatWithAi(messages);
  }

  // ─── Analytics ───────────────────────────────────────────────────
  List<Map<String, dynamic>> _monthlyTrend = [];
  List<Map<String, dynamic>> get monthlyTrend => _monthlyTrend;

  Future<void> fetchAnalytics() async {
    try {
      final data = await _api.getMonthlyAnalytics();
      _monthlyTrend = data.map((e) => Map<String, dynamic>.from(e)).toList();
      notifyListeners();
    } catch (e) {
      // Silently fail analytics – not critical
    }
  }

  // ─── Advanced Live Dashboard Data ─────────────────────────────────
  List<dynamic> _dailySpending = [];
  Map<String, dynamic> _spendingVelocity = {};
  Map<String, dynamic> _accountFlow = {};
  Map<String, dynamic> _insights = {};
  bool _isDashboardLoading = false;

  List<dynamic> get dailySpending => _dailySpending;
  Map<String, dynamic> get spendingVelocity => _spendingVelocity;
  Map<String, dynamic> get accountFlow => _accountFlow;
  Map<String, dynamic> get insights => _insights;
  bool get isDashboardLoading => _isDashboardLoading;

  /// Fetches all dashboard data in parallel for maximum performance
  Future<void> fetchDashboardData() async {
    _isDashboardLoading = true;
    notifyListeners();
    try {
      final results = await Future.wait([
        _api.getDailySpending(),
        _api.getSpendingVelocity(),
        _api.getAccountFlow(),
        _api.getInsights(),
        _api.getMonthlyAnalytics(),
        _api.getTransactions(),
        _api.getTransactionSummary(),
      ]);
      _dailySpending = results[0] as List<dynamic>;
      _spendingVelocity = results[1] as Map<String, dynamic>;
      _accountFlow = results[2] as Map<String, dynamic>;
      _insights = results[3] as Map<String, dynamic>;
      _monthlyTrend = (results[4] as List<dynamic>)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      _transactions = results[5] as List<dynamic>;
      _txnSummary = results[6] as Map<String, dynamic>;
      if (_selectedMonth.isEmpty) {
        final now = DateTime.now();
        _selectedMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      }
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
    }
    _isDashboardLoading = false;
    notifyListeners();
  }

  /// Silently refresh dashboard-related data (called after txn changes)
  void _fetchDashboardSilently() {
    Future.microtask(() async {
      try {
        final results = await Future.wait([
          _api.getDailySpending(),
          _api.getSpendingVelocity(),
          _api.getInsights(),
          _api.getMyAccounts(),
        ]);
        _dailySpending = results[0] as List<dynamic>;
        _spendingVelocity = results[1] as Map<String, dynamic>;
        _insights = results[2] as Map<String, dynamic>;
        _myAccounts = results[3] as List<dynamic>;
        notifyListeners();
      } catch (_) {}
    });
  }
}
