import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../models/user_settings.dart';
import '../services/api_service.dart';
import 'package:dio/dio.dart';

class SettingsProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.dark;
  Color _themeColor = const Color(0xFF00BCD4); // Cyan/Teal default
  String _selectedFont = 'Inter';
  String _currency = '₹';
  bool _initialized = false;
  late Isar _isar;
  final ApiService _apiService = ApiService();

  double _conversionRate = 1.0;
  Map<String, dynamic>? _exchangeRates;

  ThemeMode get themeMode => _themeMode;
  Color get themeColor => _themeColor;
  String get selectedFont => _selectedFont;
  String get currency => _currency;
  bool get initialized => _initialized;
  double get conversionRate => _conversionRate;

  static const List<Map<String, dynamic>> availableColors = [
    {'name': 'Cyan', 'color': Color(0xFF00BCD4)},
    {'name': 'Indigo', 'color': Color(0xFF3F51B5)},
    {'name': 'Purple', 'color': Color(0xFF9C27B0)},
    {'name': 'Teal', 'color': Color(0xFF009688)},
    {'name': 'Orange', 'color': Color(0xFFFF9800)},
    {'name': 'Pink', 'color': Color(0xFFE91E63)},
    {'name': 'Green', 'color': Color(0xFF4CAF50)},
    {'name': 'Amber', 'color': Color(0xFFFFC107)},
    {'name': 'Deep Purple', 'color': Color(0xFF673AB7)},
    {'name': 'Blue', 'color': Color(0xFF2196F3)},
    {'name': 'Red', 'color': Color(0xFFF44336)},
    {'name': 'Lime', 'color': Color(0xFFCDDC39)},
  ];

  static const List<String> availableFonts = [
    'Inter',
    'Roboto',
    'Poppins',
    'Outfit',
    'Manrope',
  ];

  static const List<Map<String, String>> availableCurrencies = [
    {'name': 'Indian Rupee', 'symbol': '₹', 'code': 'INR'},
    {'name': 'US Dollar', 'symbol': '\$', 'code': 'USD'},
    {'name': 'Euro', 'symbol': '€', 'code': 'EUR'},
    {'name': 'British Pound', 'symbol': '£', 'code': 'GBP'},
    {'name': 'Japanese Yen', 'symbol': '¥', 'code': 'JPY'},
  ];

  SettingsProvider._();

  static Future<SettingsProvider> create() async {
    final provider = SettingsProvider._();
    await provider._initIsar();
    provider._fetchExchangeRates(); // Fetch exchange rates non-blocking
    return provider;
  }

  Future<void> _fetchExchangeRates() async {
    try {
      final dio = Dio();
      final response = await dio.get('https://api.exchangerate-api.com/v4/latest/INR');
      if (response.statusCode == 200) {
        _exchangeRates = Map<String, dynamic>.from(response.data['rates']);
        _updateConversionRate();
      }
    } catch (e) {
      debugPrint("Exchange rates fetch failed: $e");
    }
  }

  void _updateConversionRate() {
    if (_exchangeRates == null) return;
    
    final currencyMap = availableCurrencies.firstWhere(
      (c) => c['symbol'] == _currency, 
      orElse: () => availableCurrencies[0]
    );
    final code = currencyMap['code'];
    
    if (code != null && _exchangeRates!.containsKey(code)) {
      _conversionRate = (_exchangeRates![code] as num).toDouble();
      notifyListeners();
    }
  }

  Future<void> _initIsar() async {
    final dir = await getApplicationDocumentsDirectory();
    if (Isar.instanceNames.isEmpty) {
      _isar = await Isar.open([UserSettingsSchema], directory: dir.path);
    } else {
      _isar = Isar.getInstance()!;
    }
    await _loadFromLocal();
    syncWithBackend();
  }

  Future<void> _loadFromLocal() async {
    final localSettings = await _isar.userSettings.get(1);
    if (localSettings != null) {
      _themeMode = localSettings.isDarkMode ? ThemeMode.dark : ThemeMode.light;
      _themeColor = Color(int.parse(localSettings.themeColor));
      _selectedFont = localSettings.selectedFont;
      _currency = localSettings.currency;
    }
    _initialized = true;
    _updateConversionRate();
    notifyListeners();
  }

  Future<void> syncWithBackend() async {
    try {
      final data = await _apiService.getSettings();
      final isDark = data['is_dark_mode'] as bool;
      final tColor = data['theme_color'] as String;
      final sFont = data['selected_font'] as String;
      final cur = data['currency'] as String? ?? '₹';

      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
      _themeColor = Color(int.parse(tColor));
      _selectedFont = sFont;
      _currency = cur;

      await _saveToLocal(isDark, tColor, sFont, cur);
      notifyListeners();
    } catch (e) {
      debugPrint("Settings sync failed: $e");
    }
  }

  Future<void> _saveToLocal(bool isDark, String tColor, String sFont, String cur) async {
    await _isar.writeTxn(() async {
      final settings = UserSettings()
        ..id = 1
        ..isDarkMode = isDark
        ..themeColor = tColor
        ..selectedFont = sFont
        ..currency = cur;
      await _isar.userSettings.put(settings);
    });
  }

  Future<void> _updateBackendAndLocal(
    bool isDark,
    String tColor,
    String sFont,
    String cur,
  ) async {
    await _saveToLocal(isDark, tColor, sFont, cur);
    notifyListeners();
    try {
      await _apiService.updateSettings({
        'is_dark_mode': isDark,
        'theme_color': tColor,
        'selected_font': sFont,
        'currency': cur,
      });
    } catch (e) {
      debugPrint("Update settings failed: $e");
    }
  }

  Future<void> toggleTheme() async {
    final isDark = _themeMode == ThemeMode.light;
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    final tColor =
        '0x${_themeColor.value.toRadixString(16).padLeft(8, '0').toUpperCase()}';
    await _updateBackendAndLocal(isDark, tColor, _selectedFont, _currency);
  }

  Future<void> setThemeColor(Color color) async {
    _themeColor = color;
    final isDark = _themeMode == ThemeMode.dark;
    final tColor =
        '0x${_themeColor.value.toRadixString(16).padLeft(8, '0').toUpperCase()}';
    await _updateBackendAndLocal(isDark, tColor, _selectedFont, _currency);
  }

  Future<void> setFont(String font) async {
    _selectedFont = font;
    final isDark = _themeMode == ThemeMode.dark;
    final tColor =
        '0x${_themeColor.value.toRadixString(16).padLeft(8, '0').toUpperCase()}';
    await _updateBackendAndLocal(isDark, tColor, font, _currency);
  }

  Future<void> setCurrency(String cur) async {
    _currency = cur;
    _updateConversionRate();
    final isDark = _themeMode == ThemeMode.dark;
    final tColor =
        '0x${_themeColor.value.toRadixString(16).padLeft(8, '0').toUpperCase()}';
    await _updateBackendAndLocal(isDark, tColor, _selectedFont, cur);
  }
}
