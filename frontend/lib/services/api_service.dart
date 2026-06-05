import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  // For real Android device debugging, use your machine's local IP address
  // Find it by running 'ipconfig' on Windows
  static const String _localIp = '192.168.0.181';

  static String get baseUrl =>
      (!kIsWeb && Platform.isAndroid) ? 'http://$_localIp:8001' : 'http://127.0.0.1:8001';

  final Dio dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
  ));
  final storage = const FlutterSecureStorage();

  ApiService() {
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await storage.read(key: 'jwt');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
    ));
  }

  /// Used by background sync — directly sets token + base URL
  void setToken(String token, {String? baseUrl}) {
    if (baseUrl != null) dio.options.baseUrl = baseUrl;
    dio.options.headers['Authorization'] = 'Bearer $token';
  }

  // ─── Auth ───────────────────────────────────────────────────────
  Future<String?> login(String username, String password) async {
    try {
      final response = await dio.post(
        '/token',
        data: {'username': username, 'password': password},
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      final token = response.data['access_token'];
      await storage.write(key: 'jwt', value: token);
      return token;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError) {
        throw Exception(
            'Connection failed. Backend not reachable at $baseUrl. Check if server is running and phone is on the same Wi-Fi.');
      } else if (e.response?.statusCode == 401) {
        throw Exception('Invalid username or password');
      } else {
        throw Exception('Server error: ${e.message}');
      }
    } catch (e) {
      throw Exception('Unexpected error: $e');
    }
  }

  Future<void> logout() async => await storage.delete(key: 'jwt');

  // ─── Users ──────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getMe() async {
    final response = await dio.get('/users/me');
    return response.data;
  }

  Future<List<dynamic>> getAllUsers() async {
    final response = await dio.get('/users');
    return response.data;
  }

  Future<void> updateUserIncome(int userId, double income) async {
    await dio.put('/users/$userId/income?income=$income');
  }

  // ─── Accounts ───────────────────────────────────────────────────
  Future<List<dynamic>> getMyAccounts() async {
    final response = await dio.get('/accounts');
    return response.data;
  }

  Future<List<dynamic>> getAllAccounts() async {
    final response = await dio.get('/accounts/all');
    return response.data;
  }

  Future<Map<String, dynamic>> createAccount(Map<String, dynamic> data) async {
    final response = await dio.post('/accounts', data: data);
    return response.data;
  }

  Future<Map<String, dynamic>> updateAccount(int id, Map<String, dynamic> data) async {
    final response = await dio.put('/accounts/$id', data: data);
    return response.data;
  }

  Future<void> deleteAccount(int id) async {
    await dio.delete('/accounts/$id');
  }

  // ─── Loans ──────────────────────────────────────────────────────
  Future<List<dynamic>> getMyLoans({bool activeOnly = true}) async {
    final response = await dio.get('/loans', queryParameters: {'active_only': activeOnly});
    return response.data;
  }

  Future<List<dynamic>> getAllLoans() async {
    final response = await dio.get('/loans/all');
    return response.data;
  }

  Future<Map<String, dynamic>> createLoan(Map<String, dynamic> data) async {
    final response = await dio.post('/loans', data: data);
    return response.data;
  }

  Future<Map<String, dynamic>> updateLoan(int id, Map<String, dynamic> data) async {
    final response = await dio.put('/loans/$id', data: data);
    return response.data;
  }

  Future<void> deleteLoan(int id) async {
    await dio.delete('/loans/$id');
  }

  // ─── Expenses ───────────────────────────────────────────────────
  Future<List<dynamic>> getExpenses() async {
    final response = await dio.get('/expenses');
    return response.data;
  }

  Future<Map<String, dynamic>> createExpense(Map<String, dynamic> data) async {
    final response = await dio.post('/expenses', data: data);
    return response.data;
  }

  Future<Map<String, dynamic>> updateExpense(int id, Map<String, dynamic> data) async {
    final response = await dio.put('/expenses/$id', data: data);
    return response.data;
  }

  Future<void> deleteExpense(int id) async {
    await dio.delete('/expenses/$id');
  }

  // ─── Categories ─────────────────────────────────────────────────
  Future<List<dynamic>> getCategories() async {
    final response = await dio.get('/categories');
    return response.data;
  }

  Future<Map<String, dynamic>> createCategory(Map<String, dynamic> data) async {
    final response = await dio.post('/categories', data: data);
    return response.data;
  }

  Future<Map<String, dynamic>> updateCategory(int id, Map<String, dynamic> data) async {
    final response = await dio.put('/categories/$id', data: data);
    return response.data;
  }

  Future<void> deleteCategory(int id) async {
    await dio.delete('/categories/$id');
  }

  // ─── Transactions ────────────────────────────────────────────────
  Future<List<dynamic>> getTransactions({String? month}) async {
    final params = month != null ? {'month': month} : <String, dynamic>{};
    final response = await dio.get('/transactions', queryParameters: params);
    return response.data;
  }

  Future<Map<String, dynamic>> getTransactionSummary({String? month}) async {
    final params = month != null ? {'month': month} : <String, dynamic>{};
    final response = await dio.get('/transactions/summary', queryParameters: params);
    return response.data;
  }

  Future<Map<String, dynamic>> createTransaction(Map<String, dynamic> data) async {
    final response = await dio.post('/transactions', data: data);
    return response.data;
  }

  Future<Map<String, dynamic>> updateTransaction(int id, Map<String, dynamic> data) async {
    final response = await dio.put('/transactions/$id', data: data);
    return response.data;
  }

  Future<void> deleteTransaction(int id) async {
    await dio.delete('/transactions/$id');
  }

  Future<Map<String, dynamic>> bulkImport(List<Map<String, dynamic>> transactions, {bool skipDuplicates = true}) async {
    final response = await dio.post('/transactions/bulk', data: {
      'transactions': transactions,
      'skip_duplicates': skipDuplicates,
    });
    return response.data;
  }
  
  // ─── AI Chat ─────────────────────────────────────────────────────
  Future<String> chatWithAi(List<Map<String, dynamic>> messages) async {
    final response = await dio.post('/ai/chat', data: {
      'messages': messages,
    });
    return response.data['response'];
  }

  // ─── Analytics ───────────────────────────────────────────────────
  Future<List<dynamic>> getMonthlyAnalytics({int months = 6}) async {
    final response = await dio.get('/analytics/monthly', queryParameters: {'months': months});
    return response.data;
  }
}
