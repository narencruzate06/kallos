import '../config/api_config.dart';
import '../data/demo_data.dart';
import '../models/usuario.dart';
import '../utils/json_utils.dart';
import 'api_client.dart';
import 'sesion_storage.dart';

class AuthService {
  AuthService._() {
    ApiClient.instance.renovarSesion = _renovarEnSilencio;
  }
  static final AuthService instance = AuthService._();

  final _api = ApiClient.instance;
  bool _renovando = false;

  Future<bool> _renovarEnSilencio() async {
    if (_renovando || ApiConfig.modoDemo) return false;
    final cred = await SesionStorage.credenciales();
    if (cred == null) return false;
    _renovando = true;
    try {
      await iniciarSesion(usuario: cred.usuario, clave: cred.clave, recordar: true);
      return true;
    } catch (_) {
      return false;
    } finally {
      _renovando = false;
    }
  }

  Future<Usuario> iniciarSesion({
    required String usuario,
    required String clave,
    required bool recordar,
  }) async {
    final ingresado = usuario.trim();

    if (ApiConfig.modoDemo) {
      await Future.delayed(const Duration(milliseconds: 900));
      final valido = (ingresado.toLowerCase() == DemoData.emailDemo ||
              ingresado.toLowerCase() == DemoData.usuarioDemo) &&
          clave == DemoData.claveDemo;
      if (!valido) {
        throw ApiException('Correo/usuario o contraseña incorrectos.',
            statusCode: 401);
      }
      const token = 'demo-token';
      _api.establecerToken(token);
      if (recordar) {
        await SesionStorage.guardar(
            token: token, usuario: DemoData.usuario, usuarioIngresado: ingresado);
        await SesionStorage.guardarCredenciales(ingresado, clave);
      } else {
        await SesionStorage.limpiar(olvidarUsuario: true);
      }
      await SesionStorage.marcarSalidaManual(false);
      return DemoData.usuario;
    }

    final asociado = ApiConfig.correosInstitucionales[ingresado.toLowerCase()];
    dynamic respuesta;
    try {
      respuesta = await _api.post(ApiConfig.sesion,
          body: {'usuario': ingresado, 'clave': clave});
    } on ApiException catch (e) {
      final credenciales =
          e.statusCode == 401 || e.statusCode == 400 || e.statusCode == 404;
      if (!credenciales) rethrow;
      if (asociado == null) {
        throw ApiException('Correo/usuario o contraseña incorrectos.',
            statusCode: 401);
      }
      try {
        respuesta = await _api.post(ApiConfig.sesion,
            body: {'usuario': asociado, 'clave': clave});
      } on ApiException catch (e2) {
        if (e2.statusCode == 401 || e2.statusCode == 400 || e2.statusCode == 404) {
          throw ApiException('Correo/usuario o contraseña incorrectos.',
              statusCode: 401);
        }
        rethrow;
      }
    }

    final body =
        respuesta is Map<String, dynamic> ? respuesta : <String, dynamic>{};
    var token = Json.texto(body, ['token', 'accessToken', 'jwt']);
    if (token.isEmpty) {
      token = Json.texto(Json.mapa(body, ['data', 'resultado']), ['token']);
    }
    if (token.isEmpty && respuesta is String && respuesta.split('.').length == 3) {
      token = respuesta.replaceAll('"', '').trim();
    }
    if (token.isEmpty) {
      throw ApiException('El servidor no devolvió un token de acceso.');
    }

    final user = Usuario.desdeLogin(body, token, usuarioIngresado: ingresado);
    _api.establecerToken(token);

    if (recordar) {
      await SesionStorage.guardar(
          token: token, usuario: user, usuarioIngresado: ingresado);
      await SesionStorage.guardarCredenciales(ingresado, clave);
    } else {
      await SesionStorage.limpiar(olvidarUsuario: true);
    }
    await SesionStorage.marcarSalidaManual(false);
    return user;
  }

  Future<Usuario?> restaurarSesion() async {
    if (await SesionStorage.salidaManual()) return null;
    final token = await SesionStorage.token();
    final usuario = await SesionStorage.usuario();
    if (token != null &&
        token.isNotEmpty &&
        usuario != null &&
        (ApiConfig.modoDemo || !Jwt.expirado(token))) {
      _api.establecerToken(token);
      return usuario;
    }
    final cred = await SesionStorage.credenciales();
    if (cred == null) {
      await SesionStorage.limpiar();
      return null;
    }
    try {
      return await iniciarSesion(
          usuario: cred.usuario, clave: cred.clave, recordar: true);
    } on ApiException catch (e) {
      if (e.noAutorizado) await SesionStorage.borrarCredenciales();
      rethrow;
    }
  }

  Future<void> recuperarClave(String email) async {
    await Future.delayed(const Duration(milliseconds: 800));
  }

  Future<void> cerrarSesion() async {
    _api.establecerToken(null);
    await SesionStorage.limpiar();
    await SesionStorage.marcarSalidaManual(true);
  }
}
