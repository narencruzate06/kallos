import 'dart:convert';

class Json {
  Json._();

  static dynamic valor(Map<String, dynamic>? json, List<String> claves) {
    if (json == null) return null;
    for (final clave in claves) {
      for (final entrada in json.entries) {
        if (entrada.key.toLowerCase() == clave.toLowerCase() &&
            entrada.value != null) {
          return entrada.value;
        }
      }
    }
    return null;
  }

  static String texto(Map<String, dynamic>? json, List<String> claves,
      [String porDefecto = '']) {
    final v = valor(json, claves);
    if (v == null) return porDefecto;
    if (v is Map<String, dynamic>) {
      final n = nombrePersona(v);
      return n.isEmpty ? porDefecto : n;
    }
    return v.toString();
  }

  static String nombrePersona(Map<String, dynamic>? json) {
    if (json == null) return '';
    final completo = texto(json, const ['nombreCompleto', 'fullName']);
    if (completo.isNotEmpty) return completo;
    final nombres = texto(json, const ['nombres', 'nombre', 'name']);
    final apellidos = texto(json, const ['apellidos', 'apellido']);
    final junto = '$nombres $apellidos'.trim();
    if (junto.isNotEmpty) return junto;
    return texto(json, const ['descripcion']);
  }

  static int entero(Map<String, dynamic>? json, List<String> claves,
      [int porDefecto = 0]) {
    final v = valor(json, claves);
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? porDefecto;
  }

  static double decimal(Map<String, dynamic>? json, List<String> claves,
      [double porDefecto = 0]) {
    final v = valor(json, claves);
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? porDefecto;
  }

  static Map<String, dynamic>? mapa(
      Map<String, dynamic>? json, List<String> claves) {
    final v = valor(json, claves);
    return v is Map<String, dynamic> ? v : null;
  }

  static List<dynamic> lista(dynamic respuesta) {
    if (respuesta is List) return respuesta;
    if (respuesta is Map<String, dynamic>) {
      final v = valor(respuesta,
          const ['data', 'items', 'resultado', 'result', 'citas', 'lista']);
      if (v is List) return v;
    }
    return const [];
  }
}

class Jwt {
  Jwt._();

  static const claimNombre =
      'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name';
  static const claimRol =
      'http://schemas.microsoft.com/ws/2008/06/identity/claims/role';
  static const claimEmail =
      'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress';
  static const claimId =
      'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier';

  static Map<String, dynamic>? payload(String token) {
    final partes = token.split('.');
    if (partes.length != 3) return null;
    try {
      final normalizado = base64Url.normalize(partes[1]);
      final decodificado = utf8.decode(base64Url.decode(normalizado));
      final json = jsonDecode(decodificado);
      return json is Map<String, dynamic> ? json : null;
    } catch (_) {
      return null;
    }
  }

  static bool expirado(String token) {
    final exp = payload(token)?['exp'];
    if (exp is! num) return false;
    final vence = DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000);
    return DateTime.now().isAfter(vence);
  }
}
