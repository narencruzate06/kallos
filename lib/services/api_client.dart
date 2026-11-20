import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../utils/json_utils.dart';

class ApiException implements Exception {
  final String mensaje;
  final int? statusCode;

  ApiException(this.mensaje, {this.statusCode});

  bool get noAutorizado => statusCode == 401;

  @override
  String toString() => mensaje;
}

class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  String? _token;
  String? get token => _token;

  Future<bool> Function()? renovarSesion;
  void establecerToken(String? token) => _token = token;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Uri _uri(String ruta, [Map<String, String>? query]) {
    final uri = Uri.parse('${ApiConfig.baseUrl}$ruta');
    return query == null ? uri : uri.replace(queryParameters: query);
  }

  Future<dynamic> get(String ruta, {Map<String, String>? query}) =>
      _conRenovacion(ruta, () => http.get(_uri(ruta, query), headers: _headers));

  Future<dynamic> post(String ruta, {Object? body}) => _conRenovacion(ruta, () =>
      http.post(_uri(ruta), headers: _headers, body: jsonEncode(body ?? {})));

  Future<dynamic> put(String ruta, {Object? body}) => _conRenovacion(ruta, () =>
      http.put(_uri(ruta), headers: _headers, body: jsonEncode(body ?? {})));

  Future<dynamic> patch(String ruta, {Object? body}) => _conRenovacion(ruta, () =>
      http.patch(_uri(ruta), headers: _headers, body: jsonEncode(body ?? {})));

  Future<dynamic> delete(String ruta) =>
      _conRenovacion(ruta, () => http.delete(_uri(ruta), headers: _headers));

  Future<dynamic> _conRenovacion(
      String ruta, Future<http.Response> Function() peticion) async {
    try {
      return await _enviar(peticion);
    } on ApiException catch (e) {
      final esLogin = ruta == ApiConfig.sesion;
      if (!e.noAutorizado || esLogin || _token == null || renovarSesion == null) {
        rethrow;
      }
      final renovado = await renovarSesion!();
      if (!renovado) rethrow;
      return _enviar(peticion);
    }
  }

  Future<dynamic> _enviar(Future<http.Response> Function() peticion) async {
    final http.Response res;
    try {
      res = await peticion().timeout(ApiConfig.timeout);
      _log(res);
    } on TimeoutException {
      throw ApiException(
          'El servidor tardó demasiado en responder. Intenta de nuevo.');
    } on http.ClientException {
      throw ApiException(
          'No se pudo conectar con el servidor. Revisa tu conexión a internet.');
    } catch (_) {
      throw ApiException(
          'No se pudo conectar con el servidor. Revisa tu conexión a internet.');
    }

    dynamic data;
    if (res.body.isNotEmpty) {
      try {
        data = jsonDecode(utf8.decode(res.bodyBytes));
      } catch (_) {
        data = res.body;
      }
    }

    if (res.statusCode >= 200 && res.statusCode < 300) return data;

    throw ApiException(_mensajeError(res.statusCode, data),
        statusCode: res.statusCode);
  }

  void _log(http.Response res) {
    if (!kDebugMode || !ApiConfig.mostrarLogs) return;
    final cuerpo = utf8.decode(res.bodyBytes, allowMalformed: true);
    debugPrint('[API] ${res.request?.method} ${res.request?.url} '
        '-> ${res.statusCode}');
    debugPrint('[API] ${cuerpo.length > 3000 ? '${cuerpo.substring(0, 3000)}…' : cuerpo}');
  }

  String _mensajeError(int status, dynamic data) {
    if (data is Map<String, dynamic>) {
      final errores = Json.valor(data, ['errors', 'errores']);
      if (errores is Map) {
        final lista = errores.values
            .expand((v) => v is List ? v : [v])
            .map((e) => e.toString())
            .toList();
        if (lista.isNotEmpty) return lista.join('\n');
      }
      final msg = Json.texto(
          data, ['mensaje', 'message', 'detail', 'error', 'title']);
      if (msg.isNotEmpty) return msg;
    } else if (data is String && data.trim().isNotEmpty && data.length < 200) {
      return data.trim();
    }

    return switch (status) {
      400 => 'Los datos enviados no son válidos.',
      401 => 'Tu sesión expiró. Inicia sesión nuevamente.',
      403 => 'No tienes permisos para realizar esta acción.',
      404 => 'El recurso solicitado no existe.',
      409 => 'El registro ya existe o está en conflicto.',
      >= 500 => 'Error en el servidor. Intenta más tarde.',
      _ => 'Ocurrió un error inesperado ($status).',
    };
  }
}
