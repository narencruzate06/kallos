class Formatos {
  Formatos._();

  static const _dias = [
    'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'
  ];
  static const _meses = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio',
    'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
  ];

  static String _dos(int n) => n.toString().padLeft(2, '0');

  static String fechaLarga(DateTime f) =>
      '${_dias[f.weekday - 1]}, ${f.day} de ${_meses[f.month - 1]}';

  static String fechaApi(DateTime f) =>
      '${f.year}-${_dos(f.month)}-${_dos(f.day)}';

  static String horaApi(DateTime f) => '${_dos(f.hour)}:${_dos(f.minute)}:00';

  static String hhmm(DateTime f) => '${_dos(f.hour)}:${_dos(f.minute)}';

  static String mesAnio(DateTime f) => '${_meses[f.month - 1]} ${f.year}';

  static const _diasCortos = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
  static String diaCorto(DateTime f) => _diasCortos[f.weekday - 1];

  static String moneda(num valor) {
    final entero = valor.round();
    final digitos = entero.abs().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digitos.length; i++) {
      if (i > 0 && (digitos.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digitos[i]);
    }
    return '${entero < 0 ? '-' : ''}\$$buffer';
  }

  static String hora(dynamic valor) {
    if (valor == null) return '--:--';
    final s = valor.toString();
    if (s.contains('T')) {
      final f = DateTime.tryParse(s);
      if (f != null) return '${_dos(f.hour)}:${_dos(f.minute)}';
    }
    return s.length >= 5 ? s.substring(0, 5) : s;
  }

  static String iniciales(String nombre) {
    final partes =
        nombre.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (partes.isEmpty) return '?';
    if (partes.length == 1) return partes.first[0].toUpperCase();
    return (partes[0][0] + partes[1][0]).toUpperCase();
  }

  static String primerNombre(String nombre) {
    final t = nombre.trim();
    if (t.isEmpty) return '';
    final p = t.split(RegExp(r'\s+')).first.toLowerCase();
    return p[0].toUpperCase() + p.substring(1);
  }
}
