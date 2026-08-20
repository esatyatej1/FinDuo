import 'package:isar/isar.dart';

part 'user_settings.g.dart';

@collection
class UserSettings {
  Id id = Isar.autoIncrement;

  bool isDarkMode = true;
  String themeColor = '0xFF00BCD4';
  String selectedFont = 'Inter';
  String currency = '₹';
}
