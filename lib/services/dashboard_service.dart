import '../config/api_config.dart';
import '../data/demo_data.dart';
import '../models/cita.dart';
import '../models/dashboard_resumen.dart';
import '../utils/json_utils.dart';
import 'citas_service.dart';

class DashboardService {
  DashboardService._();
  static final DashboardService instance = DashboardService._();

  Future<DashboardResumen> calcularResumen(List<Cita> citasHoy) async {
    if (ApiConfig.modoDemo) {
      await Future.delayed(const Duration(milliseconds: 300));
      return DemoData.resumen();
    }

    final citasService = CitasService.instance;
    final ayer = DateTime.now().subtract(const Duration(days: 1));
    final citasAyer = await citasService.citasDelDia(ayer);

    final activasHoy =
        citasHoy.where((c) => c.estado != EstadoCita.cancelada).toList();
    final activasAyer =
        citasAyer.where((c) => c.estado != EstadoCita.cancelada).length;

    final profesionales = citasService.profesionalesJson;
    final activos = profesionales.where((p) {
      final a = Json.valor(p, ['activo', 'estado', 'habilitado']);
      if (a == null) return true;
      if (a is bool) return a;
      final s = a.toString().toLowerCase();
      return s == 'true' || s == '1' || s.startsWith('activ');
    }).length;

    final ocupados = activasHoy
        .where((c) => c.estado == EstadoCita.enCurso)
        .map((c) => c.profesionalId != 0 ? c.profesionalId : c.profesional)
        .toSet()
        .length;

    final capacidad = activos * ApiConfig.turnosPorProfesional;
    final ocupacion = capacidad == 0
        ? 0
        : ((activasHoy.length / capacidad) * 100).round().clamp(0, 100).toInt();

    return DashboardResumen(
      reservasHoy: activasHoy.length,
      ocupacionAgenda: ocupacion,
      variacionVsAyer: activasHoy.length - activasAyer,
      ingresosEstimados: activasHoy.fold(0.0, (t, c) => t + c.precio),
      metaDiaria: ApiConfig.metaDiaria,
      equipoEnTurno: activos,
      equipoTotal: profesionales.length,
      especialistasLibres: (activos - ocupados).clamp(0, activos).toInt(),
    );
  }
}
