import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/usuario.dart';

class SesionStorage {
  SesionStorage._();

  static const _kToken = 'kallos_token';
  static const _kUsuario = 'kallos_usuario';
  static const _kUltimoUsuario = 'kallos_ultimo_usuario';
  static const _kCredencial = 'kallos_credencial';
  static const _kSalidaManual = 'kallos_salida_manual';

  static Future<void> marcarSalidaManual(bool valor) async =>
      (await SharedPreferences.getInstance()).setBool(_kSalidaManual, valor);

  static Future<bool> salidaManual() async =>
      (await SharedPreferences.getInstance()).getBool(_kSalidaManual) ?? false;

  static Future<void> guardarCredenciales(String usuario, String clave) async {
    final p = await SharedPreferences.getInstance();
    final texto = base64Url.encode(utf8.encode(jsonEncode({'u': usuario, 'c': clave})));
    await p.setString(_kCredencial, texto);
  }

  static Future<({String usuario, String clave})?> credenciales() async {
    final s = (await SharedPreferences.getInstance()).getString(_kCredencial);
    if (s == null) return null;
    try {
      final m = jsonDecode(utf8.decode(base64Url.decode(s))) as Map<String, dynamic>;
      return (usuario: m['u'] as String, clave: m['c'] as String);
    } catch (_) {
      return null;
    }
  }

  static Future<void> borrarCredenciales() async =>
      (await SharedPreferences.getInstance()).remove(_kCredencial);

  static Future<void> guardar(
      {required String token,
      required Usuario usuario,
      required String usuarioIngresado}) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kToken, token);
    await p.setString(_kUsuario, jsonEncode(usuario.toJson()));
    await p.setString(_kUltimoUsuario, usuarioIngresado);
  }

  static Future<String?> token() async =>
      (await SharedPreferences.getInstance()).getString(_kToken);

  static Future<Usuario?> usuario() async {
    final s = (await SharedPreferences.getInstance()).getString(_kUsuario);
    if (s == null) return null;
    try {
      return Usuario.fromJson(jsonDecode(s) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<String?> ultimoUsuario() async =>
      (await SharedPreferences.getInstance()).getString(_kUltimoUsuario);

  static Future<void> limpiar({bool olvidarUsuario = false}) async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kToken);
    await p.remove(_kUsuario);
    if (olvidarUsuario) {
      await p.remove(_kUltimoUsuario);
      await p.remove(_kCredencial);
    }
  }
}
