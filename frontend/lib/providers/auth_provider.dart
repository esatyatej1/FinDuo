import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
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

  Future<bool> loginWithGoogle() async {
    _errorMessage = null;
    _isConnecting = true;
    notifyListeners();

    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
      );

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser != null) {
        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;
        final String? idToken = googleAuth.idToken;

        if (idToken != null) {
          final token = await _apiService.loginWithGoogle(idToken);
          if (token != null) {
            _isAuthenticated = true;
            _isConnecting = false;
            notifyListeners();
            return true;
          }
        } else {
          _errorMessage = "Google Sign-In failed: No ID Token";
        }
      } else {
        // User canceled sign-in
        _isConnecting = false;
        notifyListeners();
        return false;
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
