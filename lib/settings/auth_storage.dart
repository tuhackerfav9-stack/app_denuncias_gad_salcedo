import 'package:shared_preferences/shared_preferences.dart';

class AuthStorage {
  static const _kAccess = "access";
  static const _kRefresh = "refresh";

  Future<void> saveTokens({
    required String access,
    required String refresh,
  }) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kAccess, access);
    await sp.setString(_kRefresh, refresh);
  }

  Future<String?> getAccess() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_kAccess);
  }

  Future<String?> getRefresh() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_kRefresh);
  }

  Future<void> clear() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kAccess);
    await sp.remove(_kRefresh);
  }
}
