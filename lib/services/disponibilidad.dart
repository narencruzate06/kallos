import '../config/api_config.dart';
import '../models/catalogos.dart';
import '../models/cita.dart';

class Disponibilidad {
  Disponibilidad._();

  static int _min(String hhmm) {
    final p = hhmm.split(':');
    if (p.length < 2) return 0;
    return (int.tryParse(p[0]) ?? 0) * 60 + (int.tryParse(p[1]) ?? 0);
  }

  static String _hhmm(int minutos) =>
      '${(minutos ~/ 60).toString().padLeft(2, '0')}:${(minutos % 60).toString().padLeft(2, '0')}';

  static List<String> deProfesional({
    required int profesionalId,
    required DateTime dia,
    required int duracion,
    required List<HorarioLaboral> horarios,
    required List<Cita> reservas,
  }) {
    final diaApi = HorarioLaboral.diaApi(dia);
    final propios = horarios.where((h) => h.profesionalId == profesionalId).toList();
    HorarioLaboral? hoy;
    for (final h in propios) {
      if (h.diaSemana == diaApi) hoy = h;
    }
    if (propios.isNotEmpty && hoy == null) return [];

    final inicio = _min(hoy?.horaInicio ?? ApiConfig.aperturaSalon);
    final fin = _min(hoy?.horaFin ?? ApiConfig.cierreSalon);
    final ocupados = <List<int>>[
      if (hoy != null && hoy.tieneAlmuerzo)
        [_min(hoy.inicioAlmuerzo), _min(hoy.finAlmuerzo)],
      for (final r in reservas)
        if (r.profesionalId == profesionalId &&
            r.estado != EstadoCita.cancelada &&
            r.inicio != null &&
            r.fin != null &&
            r.inicio!.year == dia.year &&
            r.inicio!.month == dia.month &&
            r.inicio!.day == dia.day)
          [r.inicio!.hour * 60 + r.inicio!.minute, r.fin!.hour * 60 + r.fin!.minute],
    ];

    final ahora = DateTime.now();
    final esHoy =
        ahora.year == dia.year && ahora.month == dia.month && ahora.day == dia.day;
    final minimo = esHoy ? ahora.hour * 60 + ahora.minute + 15 : 0;
    final paso = duracion < 15 ? 15 : duracion;

    final libres = <String>[];
    for (var t = inicio; t + duracion <= fin; t += paso) {
      if (t < minimo) continue;
      final choca = ocupados.any((o) => t < o[1] && t + duracion > o[0]);
      if (!choca) libres.add(_hhmm(t));
    }
    return libres;
  }

  static List<String> deCualquiera({
    required List<int> profesionales,
    required DateTime dia,
    required int duracion,
    required List<HorarioLaboral> horarios,
    required List<Cita> reservas,
  }) {
    final todas = <String>{};
    for (final id in profesionales) {
      todas.addAll(deProfesional(
          profesionalId: id,
          dia: dia,
          duracion: duracion,
          horarios: horarios,
          reservas: reservas));
    }
    return todas.toList()..sort();
  }

  static List<String> quitarPasadas(List<String> horas, DateTime dia) {
    final ahora = DateTime.now();
    if (!(ahora.year == dia.year && ahora.month == dia.month && ahora.day == dia.day)) {
      return horas;
    }
    final minimo = ahora.hour * 60 + ahora.minute;
    return horas.where((h) => _min(h) > minimo).toList();
  }
}
