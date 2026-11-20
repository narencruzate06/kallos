import '../utils/json_utils.dart';

class DashboardResumen {
  final int reservasHoy;
  final int ocupacionAgenda;
  final int variacionVsAyer;
  final double ingresosEstimados;
  final double metaDiaria;
  final int equipoEnTurno;
  final int equipoTotal;
  final int especialistasLibres;

  const DashboardResumen({
    required this.reservasHoy,
    required this.ocupacionAgenda,
    required this.variacionVsAyer,
    required this.ingresosEstimados,
    required this.metaDiaria,
    required this.equipoEnTurno,
    required this.equipoTotal,
    required this.especialistasLibres,
  });

  bool get metaAlcanzada => metaDiaria > 0 && ingresosEstimados >= metaDiaria;

  factory DashboardResumen.fromJson(Map<String, dynamic> json) {
    return DashboardResumen(
      reservasHoy:
          Json.entero(json, ['reservasHoy', 'citasHoy', 'totalCitasHoy']),
      ocupacionAgenda: Json.decimal(json,
              ['ocupacionAgenda', 'ocupacion', 'porcentajeOcupacion'])
          .round(),
      variacionVsAyer:
          Json.entero(json, ['variacionVsAyer', 'diferenciaAyer', 'variacion']),
      ingresosEstimados: Json.decimal(
          json, ['ingresosEstimados', 'ingresosHoy', 'ingresos']),
      metaDiaria: Json.decimal(json, ['metaDiaria', 'meta']),
      equipoEnTurno:
          Json.entero(json, ['equipoEnTurno', 'especialistasEnTurno']),
      equipoTotal: Json.entero(json, ['equipoTotal', 'totalEspecialistas']),
      especialistasLibres:
          Json.entero(json, ['especialistasLibres', 'libres']),
    );
  }
}
