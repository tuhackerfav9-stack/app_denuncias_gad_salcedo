import 'package:shared_preferences/shared_preferences.dart';

import 'api_connection.dart';

class Session {
  static const _kAccess = "access";
  static const _kRefresh = "refresh";
  static const _kEmail = "email";
  static const _kUserId = "user_id";
  static const _kUserTipo = "user_tipo";

  // ====== GUARDAR LOGIN ======
  static Future<void> saveLogin({
    required String access,
    required String refresh,
    required String email,
    required String userId,
    required String tipo,
  }) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kAccess, access);
    await sp.setString(_kRefresh, refresh);
    await sp.setString(_kEmail, email);
    await sp.setString(_kUserId, userId);
    await sp.setString(_kUserTipo, tipo);
  }

  // ====== GETTERS ======
  static Future<String?> access() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_kAccess);
  }

  static Future<String?> refresh() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_kRefresh);
  }

  static Future<String?> email() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_kEmail);
  }

  static Future<String?> userId() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_kUserId);
  }

  static Future<String?> tipo() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_kUserTipo);
  }

  // ====== HELPERS ======
  static Future<bool> hasSession() async {
    final a = await access();
    final r = await refresh();
    return (a != null && a.isNotEmpty && r != null && r.isNotEmpty);
  }

  // Cuando refrescas token, normalmente SOLO cambia access
  static Future<void> updateAccess(String access) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kAccess, access);
    //final pending = await Session.pendingFcmToken();
    //if (pending != null && pending.isNotEmpty) {
    //  await ApiConnection.instance.post("api/notificaciones/token/", {
    //    "fcm_token": pending,
    //    "platform": "android",
    //  }, auth: true);
    //  await Session.clearPendingFcmToken();
    //}
    final pending = await Session.pendingFcmToken();
    if (pending != null && pending.isNotEmpty) {
      await ApiConnection.instance.post("api/notificaciones/token/", {
        "fcm_token": pending,
        "platform": "android",
      }, auth: true);
      await Session.clearPendingFcmToken();
    }
  }

  // Si tu backend devuelve refresh nuevo (a veces), lo actualizas
  static Future<void> updateRefresh(String refresh) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kRefresh, refresh);
  }

  // ====== LOGOUT ======
  static Future<void> clear() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kAccess);
    await sp.remove(_kRefresh);
    await sp.remove(_kEmail);
    await sp.remove(_kUserId);
    await sp.remove(_kUserTipo);
  }

  static const _pendingFcmKey = "pending_fcm_token";

  static Future<void> setPendingFcmToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingFcmKey, token);
  }

  static Future<String?> pendingFcmToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_pendingFcmKey);
  }

  static Future<void> clearPendingFcmToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingFcmKey);
  }
}
