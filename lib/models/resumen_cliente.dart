import 'catalogos.dart';
import 'cita.dart';

enum SegmentoCliente { habitual, frecuente, primeraVisita, nuevo, inactivo }

class ResumenCliente {
  final Cliente cliente;
  final List<Cita> citas;
  final List<Cita> realizadas;
  final Cita? ultima;
  final Cita? proxima;
  final double gastoTotal;
  final String profesionalHabitual;
  final DateTime? primeraCita;

  const ResumenCliente({
    required this.cliente,
    required this.citas,
    required this.realizadas,
    required this.ultima,
    required this.proxima,
    required this.gastoTotal,
    required this.profesionalHabitual,
    required this.primeraCita,
  });

  int get visitas => realizadas.length;
  double get gastoPromedio => visitas == 0 ? 0 : gastoTotal / visitas;

  int? get diasSinVisita => ultima?.fin == null
      ? null
      : DateTime.now().difference(ultima!.fin!).inDays;

  SegmentoCliente get segmento {
    if (visitas > 0 && proxima == null && (diasSinVisita ?? 0) > 60) {
      return SegmentoCliente.inactivo;
    }
    if (visitas >= 5) return SegmentoCliente.habitual;
    if (visitas >= 2) return SegmentoCliente.frecuente;
    if (visitas == 1) return SegmentoCliente.primeraVisita;
    return SegmentoCliente.nuevo;
  }

  String get etiquetaSegmento => switch (segmento) {
        SegmentoCliente.habitual => 'Habitual',
        SegmentoCliente.frecuente => 'Frecuente',
        SegmentoCliente.primeraVisita => 'Primera visita',
        SegmentoCliente.nuevo => 'Nuevo',
        SegmentoCliente.inactivo => 'Inactivo > 60d',
      };

  static ResumenCliente calcular(Cliente c, List<Cita> todas) {
    final citas = todas
        .where((r) => r.clienteId == c.id && r.estado != EstadoCita.cancelada)
        .toList()
      ..sort((a, b) => (b.inicio ?? DateTime(2000)).compareTo(a.inicio ?? DateTime(2000)));
    final realizadas = citas.where((r) => r.estado == EstadoCita.finalizada).toList();
    final futuras = citas
        .where((r) => r.vigente || r.estado == EstadoCita.enCurso)
        .toList()
      ..sort((a, b) => (a.inicio ?? DateTime(2100)).compareTo(b.inicio ?? DateTime(2100)));

    final conteo = <String, int>{};
    for (final r in realizadas) {
      conteo[r.profesional] = (conteo[r.profesional] ?? 0) + 1;
    }
    String habitual = '';
    var max = 0;
    conteo.forEach((nombre, n) {
      if (n > max) {
        max = n;
        habitual = nombre;
      }
    });

    return ResumenCliente(
      cliente: c,
      citas: citas,
      realizadas: realizadas,
      ultima: realizadas.isEmpty ? null : realizadas.first,
      proxima: futuras.isEmpty ? null : futuras.first,
      gastoTotal: realizadas.fold<double>(0, (t, r) => t + r.precio),
      profesionalHabitual: habitual,
      primeraCita: citas.isEmpty ? null : citas.last.inicio,
    );
  }
}
