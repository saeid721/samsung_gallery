import 'package:shared_preferences/shared_preferences.dart';
import 'local_storage_keys.dart';

class LocalStorage {
  late final SharedPreferences? _sharedPrefInstance;

  SharedPreferences get sharedPreference {
    if (_sharedPrefInstance == null) {
      throw Exception('SharedPreferences is not initialized');
    }
    return _sharedPrefInstance;
  }

  Future<void> initLocalStorage() async {
    _sharedPrefInstance = await SharedPreferences.getInstance();
  }

  void setBool({
    required StorageKeys key,
    required bool value,
  }) async {
    await sharedPreference.setBool(key.name, value);
  }

  bool getBool({required StorageKeys key, bool? isFalse}) {
    return sharedPreference.getBool(key.name) ?? (isFalse ?? true);
  }

  void setString({
    required StorageKeys key,
    required String? value,
  }) async {
    await sharedPreference.setString(key.name, value!);
  }

  String? getString({required StorageKeys key}) {
    return sharedPreference.getString(key.name);
  }

  void setInt({
    required StorageKeys key,
    required int? value,
  }) async {
    await sharedPreference.setInt(key.name, value!);
  }

  int? getInt({required StorageKeys key}) {
    return sharedPreference.getInt(key.name);
  }

  Future<bool?> removeLocalData({required StorageKeys key}) {
    return sharedPreference.remove(key.name);
  }

  Future<bool>? clearLocalStorage() {
    return sharedPreference.clear();
  }

  String getCurrentLanguage() {
    return sharedPreference.getString(StorageKeys.localLangCode.name) ?? "en";
  }

  /// Removes a specific key from SharedPreferences
  Future<bool> remove({required StorageKeys key}) async {
    return await sharedPreference.remove(key.name);
  }

}
