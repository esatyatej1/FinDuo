import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.dark;
  Color _themeColor = const Color(0xFF00BCD4); // Cyan/Teal default
  String _selectedFont = 'Inter';
  bool _initialized = false;

  ThemeMode get themeMode => _themeMode;
  Color get themeColor => _themeColor;
  String get selectedFont => _selectedFont;
  bool get initialized => _initialized;

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

  SettingsProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('isDark') ?? true;
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    final colorIndex = prefs.getInt('colorIndex') ?? 0;
    _themeColor = availableColors[colorIndex.clamp(0, availableColors.length - 1)]['color'] as Color;
    _selectedFont = prefs.getString('font') ?? 'Inter';
    _initialized = true;
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDark', _themeMode == ThemeMode.dark);
    notifyListeners();
  }

  Future<void> setThemeColor(Color color) async {
    _themeColor = color;
    final idx = availableColors.indexWhere((c) => c['color'] == color);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('colorIndex', idx >= 0 ? idx : 0);
    notifyListeners();
  }

  Future<void> setFont(String font) async {
    _selectedFont = font;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('font', font);
    notifyListeners();
  }
}
