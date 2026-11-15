import 'package:shared_preferences/shared_preferences.dart';

class ApiConfig {
  // Alamat IPv4 lokal laptop sebagai default
  static const String defaultBaseUrl = 'http://10.205.87.242:8000';
  static const String keyBaseUrl = 'pref_server_base_url';
  static const String keyToken = 'pref_access_token';
  static const String keyUserNama = 'pref_user_nama';
  static const String keyUserEmployeeId = 'pref_user_emp_id';
  static const String keyUserRole = 'pref_user_role';

  static Future<String> getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(keyBaseUrl);
    if (saved != null && saved.trim().isNotEmpty) {
      return saved.trim();
    }
    return defaultBaseUrl;
  }

  static Future<void> setBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    var cleanUrl = url.trim();
    if (cleanUrl.endsWith('/')) {
      cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
    }
    await prefs.setString(keyBaseUrl, cleanUrl);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyToken);
  }

  static Future<void> setToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyToken, token);
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(keyToken);
    await prefs.remove(keyUserNama);
    await prefs.remove(keyUserEmployeeId);
    await prefs.remove(keyUserRole);
  }
}
