import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'colors_resources.dart';
import 'preferences/local_storage.dart';
import 'preferences/local_storage_keys.dart';

class ThemeController extends GetxController implements GetxService {

  @override
  onInit() async {
    super.onInit();
    await _loadCurrentTheme();
  }

  bool _darkTheme = false; // Default light theme
  bool get isDarkTheme => _darkTheme;

  void toggleDarkTheme() {
    _darkTheme = true;
    _saveTheme();
    Get.changeThemeMode(ThemeMode.dark);
    update();
  }

  void toggleLightTheme() {
    _darkTheme = false;
    _saveTheme();
    Get.changeThemeMode(ThemeMode.light);
    update();
  }

  void toggleTheme() {
    _darkTheme = !_darkTheme;
    _saveTheme();
    Get.changeThemeMode(_darkTheme ? ThemeMode.dark : ThemeMode.light);
    update();
  }

  void _saveTheme() {
    try {
      Get.find<LocalStorage>().setBool(key: StorageKeys.theme, value: _darkTheme);
    } catch (e) {
      debugPrint('LocalStorage not initialized yet: $e');
    }
  }

  Future<void> _loadCurrentTheme() async {
    try {
      bool? storedTheme = Get.find<LocalStorage>().getBool(key: StorageKeys.theme, isFalse: false);
      _darkTheme = storedTheme ?? false; // Default light theme
      Get.changeThemeMode(_darkTheme ? ThemeMode.dark : ThemeMode.light);
    } catch (e) {
      debugPrint('Could not load theme from storage: $e');
      _darkTheme = false; // Default to light theme
    }
  }

  // Get ThemeMode
  ThemeMode get themeMode => _darkTheme ? ThemeMode.dark : ThemeMode.light;

  /// White/Black Color
  Color lightDarkWhiteBlackColor(BuildContext context) {
    final theme = Theme.of(context).brightness;
    return theme == Brightness.dark ? ColorRes.white : ColorRes.black;
  }

  /// Black/White Color
  Color lightDarkBlackWhiteColor(BuildContext context) {
    final theme = Theme.of(context).brightness;
    return theme == Brightness.dark ? ColorRes.black : ColorRes.white;
  }

  /// App Icon Color (for section headers)
  Color lightDarkAppIconColor(BuildContext context) {
    final theme = Theme.of(context).brightness;
    return theme == Brightness.dark ? ColorRes.white : ColorRes.lightAppColor;
  }

  // ==/@ Theme Color Methods @/==

  /// App Background Color
  Color lightDarkAppBackColor(BuildContext context) {
    final theme = Theme.of(context).brightness;
    return theme == Brightness.dark ? ColorRes.darkAppBackColor : ColorRes.lightAppBackColor;
  }

  /// AppBar Background Color
  Color lightDarkAppBarColor(BuildContext context) {
    final theme = Theme.of(context).brightness;
    return theme == Brightness.dark ? ColorRes.darkAppColor : ColorRes.lightAppColor;
  }

  /// Card Background Color
  Color lightDarkCardColor(BuildContext context) {
    final theme = Theme.of(context).brightness;
    return theme == Brightness.dark ? ColorRes.darkCardColor : ColorRes.lightCardColor;
  }

  /// Primary Text Color
  Color lightDarkTextColor(BuildContext context) {
    final theme = Theme.of(context).brightness;
    return theme == Brightness.dark ? ColorRes.darkTextColor : ColorRes.lightTextColor;
  }

  /// Secondary Text Color
  Color lightDarkTextSecondaryColor(BuildContext context) {
    final theme = Theme.of(context).brightness;
    return theme == Brightness.dark ? ColorRes.darkTextSecondaryColor : ColorRes.lightTextSecondaryColor;
  }

  /// Border Color
  Color lightDarkBorderColor(BuildContext context) {
    final theme = Theme.of(context).brightness;
    return theme == Brightness.dark ? ColorRes.darkBorderColor : ColorRes.lightBorderColor.withValues(alpha: 0.5);
  }

  /// ListTile Background Color
  Color lightDarkListTileBackColor(BuildContext context) {
    final theme = Theme.of(context).brightness;
    return theme == Brightness.dark ? ColorRes.darkAppBackColor.withValues(alpha: 0.5) : ColorRes.lightListTileBackColor;
  }

  Color lightDarkListTileBackColorAlpha(BuildContext context) {
    final theme = Theme.of(context).brightness;
    return theme == Brightness.dark ? ColorRes.darkCardColor : ColorRes.lightCardColor;
  }

  /// Divider Color
  Color lightDarkDividerColor(BuildContext context) {
    final theme = Theme.of(context).brightness;
    return theme == Brightness.dark ? ColorRes.darkDividerColor : ColorRes.lightDividerColor;
  }

  /// Icon Color
  Color lightDarkIconColor(BuildContext context) {
    final theme = Theme.of(context).brightness;
    return theme == Brightness.dark ? ColorRes.darkIconColor : ColorRes.lightIconColor;
  }

  /// Shadow Color
  Color lightDarkShadowColor(BuildContext context) {
    final theme = Theme.of(context).brightness;
    return theme == Brightness.dark ? ColorRes.black.withAlpha(150) : ColorRes.grey.withAlpha(100);
    // return theme == Brightness.dark ? ColorRes.darkShadowColor : ColorRes.lightShadowColor;
  }

  /// Alternating Row Color (for list items)
  Color lightDarkAlternateRowColor(BuildContext context) {
    final theme = Theme.of(context).brightness;
    return theme == Brightness.dark
        ? ColorRes.darkCardColor.withValues(alpha: 0.3)
        : ColorRes.lightAppColor.withValues(alpha: 0.12);
  }

  /// Status Active Color
  Color lightDarkStatusActiveColor(BuildContext context) {
    final theme = Theme.of(context).brightness;

    return theme == Brightness.dark ? Colors.green : ColorRes.green;
    //return theme == Brightness.dark ? Colors.indigo.shade400 : Colors.indigo;
  }

  /// Status Inactive Color
  Color lightDarkStatusInactiveColor(BuildContext context) {
    return ColorRes.red; // Same for both themes
  }

}