import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'preferences/local_storage.dart';
import 'preferences/local_storage_keys.dart';

class LocalizationController extends Translations {
  var selectedLangIndex = 0.obs;
  static Locale? _locale;
  static const fallbackLocale = Locale('en', 'EN');
  static final Map<String, Map<String, String>> _translations = {};

  // Initialize the localization controller.
  static Future<void> init() async {
    try {
      // Check if LocalStorage is registered
      if (!Get.isRegistered<LocalStorage>()) {
        print("LocalStorage not found, using default locale");
        _locale = const Locale('en');
        await _loadTranslations();
        Get.updateLocale(_locale!);
        return;
      }

      String langCode = Get.find<LocalStorage>().getString(key: StorageKeys.langCode) ?? "en";
      await _loadTranslations();
      _locale = Locale(langCode);
      Get.updateLocale(_locale!);
    } catch (e) {
      print("Error initializing LocalizationController: $e");
      _locale = const Locale('en');
      await _loadTranslations();
      Get.updateLocale(_locale!);
    }
  }

  // Load translations from ARB files.
  static Future<void> _loadTranslations() async {
    final List<String> locales = ['en', 'bn', 'ar'];
    for (String locale in locales) {
      try {
        String path = 'lib/l10n/app_$locale.arb';
        String content = await rootBundle.loadString(path);
        final Map<String, dynamic> jsonContent = json.decode(content);
        final Map<String, String> translations =
        jsonContent.map((key, value) => MapEntry(key, value.toString()));

        _translations[locale] = translations;
      } catch (e) {
        print("Error loading $locale translations: $e");
      }
    }
  }

  // Change the locale and persist the selection.
  static Future<void> changeLocale(String langCode) async {
    try {
      if (langCode.isNotEmpty) {
        Get.find<LocalStorage>().setString(key: StorageKeys.langCode, value: langCode);
      } else {
        Get.find<LocalStorage>().setString(key: StorageKeys.langCode, value: "en");
        langCode = "en";
      }
      await _loadTranslations();
      _locale = Locale(langCode);
      Get.updateLocale(_locale!);
    } catch (e) {
      log("Error changing locale: $e");
    }
  }

  // Change the selected language name and persist the selection.
  static Future<void> changeLanguageName(String langName) async {
    try {
      Get.find<LocalStorage>().setString(key: StorageKeys.languageName, value: langName);
    } catch (e) {
      print("Error saving language name: $e");
    }
  }

  // Change the selected language flag/image and persist the selection.
  static Future<void> changeLanguageImg(String langImg) async {
    try {
      Get.find<LocalStorage>().setString(key: StorageKeys.languageFlag, value: langImg);
    } catch (e) {
      print("Error saving language image: $e");
    }
  }

  @override
  Map<String, Map<String, String>> get keys => _translations;

  // Getter for the current locale.
  static Locale? get locale => _locale ?? const Locale('en');

  // Update the selected language index.
  void updateSelectedLangIndex(int index) {
    selectedLangIndex.value = index;
  }
}