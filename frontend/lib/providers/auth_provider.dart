import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AuthProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  bool _isAuthenticated = false;
  String? _errorMessage;
  bool _isConnecting = false;

  bool get isAuthenticated => _isAuthenticated;
  String? get errorMessage => _errorMessage;
  bool get isConnecting => _isConnecting;

  Future<bool> login(String username, String password) async {
    _errorMessage = null;
    _isConnecting = true;
    notifyListeners();
    
    try {
      final token = await _apiService.login(username, password);
      if (token != null) {
        _isAuthenticated = true;
        _isConnecting = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
    }
    
    _isConnecting = false;
    notifyListeners();
    return false;
  }

  Future<void> logout() async {
    await _apiService.logout();
    _isAuthenticated = false;
    notifyListeners();
  }
}
