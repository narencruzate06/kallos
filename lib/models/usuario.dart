import '../utils/json_utils.dart';

class Usuario {
  final int id;
  final String usuario;
  final String nombre;
  final String rol;
  final int empresaId;
  final String sede;

  const Usuario({
    required this.id,
    required this.usuario,
    required this.nombre,
    required this.rol,
    this.empresaId = 0,
    this.sede = 'Salón Central',
  });

  String get rolVisible {
    final r = rol.toLowerCase();
    if (r.startsWith('admin')) return 'Administración';
    if (r.isEmpty) return 'Personal';
    return rol[0].toUpperCase() + rol.substring(1);
  }

  String get nombreSaludo => nombre.isNotEmpty ? nombre : rolVisible;

  factory Usuario.desdeToken(String token) {
    final p = Jwt.payload(token) ?? {};
    return Usuario(
      id: Json.entero(p, ['sub', 'id', Jwt.claimId]),
      usuario: Json.texto(p, ['usuario', 'unique_name']),
      nombre: Json.texto(p, ['nombre', 'name', Jwt.claimNombre]),
      rol: Json.texto(p, [Jwt.claimRol, 'role', 'rol']),
      empresaId: Json.entero(p, ['empresaId']),
    );
  }

  factory Usuario.desdeLogin(Map<String, dynamic> body, String token,
      {String usuarioIngresado = ''}) {
    final delToken = Usuario.desdeToken(token);
    final json = Json.mapa(body, ['usuario', 'user', 'data']) ?? body;
    final u = delToken.combinar(json);
    return u.usuario.isNotEmpty ? u : u._conUsuario(usuarioIngresado);
  }

  factory Usuario.fromJson(Map<String, dynamic> json) =>
      const Usuario(id: 0, usuario: '', nombre: '', rol: '').combinar(json);

  Usuario _conUsuario(String valor) => Usuario(
      id: id,
      usuario: valor,
      nombre: nombre,
      rol: rol,
      empresaId: empresaId,
      sede: sede);

  Usuario combinar(Map<String, dynamic> json) {
    final nuevoNombre = Json.nombrePersona(json);
    final nuevoUsuario = Json.valor(json, ['usuario', 'documento']);
    final nuevoRol = Json.texto(json, ['rolNombre', 'rol', 'role']);
    final nuevaSede = Json.texto(json, ['empresaNombre', 'sede', 'empresa', 'nombreEmpresa']);
    final nuevoId = Json.entero(json, ['id', 'usuarioId']);
    final nuevaEmpresa = Json.entero(json, ['empresaId']);
    return Usuario(
      id: nuevoId != 0 ? nuevoId : id,
      usuario: nuevoUsuario is String || nuevoUsuario is num
          ? nuevoUsuario.toString()
          : usuario,
      nombre: nuevoNombre.isNotEmpty ? nuevoNombre : nombre,
      rol: nuevoRol.isNotEmpty && int.tryParse(nuevoRol) == null
          ? nuevoRol
          : rol,
      empresaId: nuevaEmpresa != 0 ? nuevaEmpresa : empresaId,
      sede: nuevaSede.isNotEmpty ? nuevaSede : sede,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'usuario': usuario,
        'nombre': nombre,
        'rol': rol,
        'empresaId': empresaId,
        'sede': sede,
      };
}
