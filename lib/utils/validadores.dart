import '../config/api_config.dart';

class Validadores {
  Validadores._();

  static final _regexEmail = RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)+$');

  static bool esEmail(String valor) => _regexEmail.hasMatch(valor.trim());

  static String? usuario(String? valor) {
    final t = valor?.trim() ?? '';
    if (t.isEmpty) return 'Ingresa tu usuario';
    if (t.length > 100) return 'Máximo 100 caracteres';
    if (t.contains('@')) {
      if (!esEmail(t)) return 'El correo electrónico no es válido';
      if (!t.toLowerCase().endsWith(ApiConfig.dominioCorreo)) {
        return 'Usa tu correo institucional (${ApiConfig.dominioCorreo})';
      }
    } else {
      if (t.length < 3) return 'El usuario debe tener al menos 3 caracteres';
      if (t.contains(' ')) return 'El usuario no puede contener espacios';
    }
    return null;
  }

  static String? clave(String? valor) {
    final t = valor ?? '';
    if (t.isEmpty) return 'Ingresa tu contraseña';
    if (t.trim().isEmpty) return 'La contraseña no puede ser solo espacios';
    if (t.length < 6) return 'La contraseña debe tener al menos 6 caracteres';
    if (t.length > 64) return 'Máximo 64 caracteres';
    return null;
  }

  static String? email(String? valor) {
    final t = valor?.trim() ?? '';
    if (t.isEmpty) return 'Ingresa tu correo electrónico';
    if (!esEmail(t)) return 'El correo electrónico no es válido';
    return null;
  }

  static String? requerido(String? valor, [String campo = 'Este campo']) {
    if ((valor ?? '').trim().isEmpty) return '$campo es obligatorio';
    return null;
  }

  static final _regexNombre = RegExp(r"^[A-Za-zÁÉÍÓÚÜÑáéíóúüñ' ]+$");

  static String? nombre(String? valor, [String campo = 'El nombre']) {
    final t = valor?.trim() ?? '';
    if (t.isEmpty) return '$campo es obligatorio';
    if (t.length < 2) return '$campo debe tener al menos 2 letras';
    if (t.length > 60) return 'Máximo 60 caracteres';
    if (!_regexNombre.hasMatch(t)) return '$campo solo puede tener letras';
    return null;
  }

  static String? documento(String? valor) {
    final t = valor?.trim() ?? '';
    if (t.isEmpty) return 'El documento es obligatorio';
    if (!RegExp(r'^\d+$').hasMatch(t)) return 'Solo números, sin puntos ni espacios';
    if (t.length < 6 || t.length > 12) return 'Debe tener entre 6 y 12 dígitos';
    return null;
  }

  static String? celular(String? valor) {
    final t = valor?.trim() ?? '';
    if (t.isEmpty) return 'El celular es obligatorio';
    if (!RegExp(r'^3\d{9}$').hasMatch(t)) {
      return 'Celular colombiano de 10 dígitos que empiece por 3';
    }
    return null;
  }

  static String? emailOpcional(String? valor) {
    final t = valor?.trim() ?? '';
    if (t.isEmpty) return null;
    return esEmail(t) ? null : 'El correo electrónico no es válido';
  }

  static String? porcentaje(String? valor) {
    final t = (valor ?? '').trim().replaceAll(',', '.');
    if (t.isEmpty) return 'El porcentaje es obligatorio';
    final n = double.tryParse(t);
    if (n == null) return 'Ingresa un número válido';
    if (n < 0 || n > 100) return 'Debe estar entre 0 y 100';
    return null;
  }
}
