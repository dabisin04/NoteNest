import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:temp/domain/entities/user.dart';

class SessionService {
  static const String _keyUsuario = 'session_usuario';
  static const String _keyToken = 'session_token';
  static const String _keyExpiresAt = 'session_expires_at';

  static Future<void> saveUsuario(User usuario) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(usuario.toMap());
    await prefs.setString(_keyUsuario, jsonString);
  }

  static Future<User?> getUsuario() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_keyUsuario);
    if (jsonStr == null || jsonStr.isEmpty) return null;

    try {
      final map = jsonDecode(jsonStr);
      return User.fromMap(map);
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyToken);
  }

  static Future<void> saveExpiration(DateTime expiresAt) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyExpiresAt, expiresAt.millisecondsSinceEpoch);
  }

  static Future<DateTime?> getExpiration() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_keyExpiresAt);
    return ms != null ? DateTime.fromMillisecondsSinceEpoch(ms) : null;
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUsuario);
    await prefs.remove(_keyToken);
    await prefs.remove(_keyExpiresAt);
  }

  static Future<void> clearTokenData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyExpiresAt);
  }

  static Future<bool> isLoggedIn() async {
    final usuario = await getUsuario();
    return usuario != null;
  }

  static Future<String?> getUsuarioId() async {
    final usuario = await getUsuario();
    return usuario?.id;
  }
}
