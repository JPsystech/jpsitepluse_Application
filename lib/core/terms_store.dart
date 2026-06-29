import "package:shared_preferences/shared_preferences.dart";

class TermsStore {
  static const String _keyAccepted = "sitepulse_engineer_terms_accepted_v1";

  static Future<bool> isAccepted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyAccepted) ?? false;
  }

  static Future<void> setAccepted(bool accepted) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAccepted, accepted);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAccepted);
  }
}
