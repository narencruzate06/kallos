import '../config/api_config.dart';
import '../data/demo_data.dart';
import '../models/cita.dart';
import '../utils/formatos.dart';
import '../utils/json_utils.dart';
import 'api_client.dart';

class CitasService {
  CitasService._();
  static final CitasService instance = CitasService._();

  final _api = ApiClient.instance;

  Map<int, Map<String, dynamic>> _servicios = {};
  Map<int, String> _profesionales = {};
  List<Map<String, dynamic>> profesionalesJson = [];

  Future<void> cargarCatalogos() async {
    if (ApiConfig.modoDemo) return;
    final r = await Future.wait([
      _listaSegura(ApiConfig.servicios),
      _listaSegura(ApiConfig.profesionales),
    ]);
    _servicios = {
      for (final s in r[0]) Json.entero(s, ['id', 'servicioId']): s,
    };
    profesionalesJson = r[1];
    _profesionales = {
      for (final p in r[1])
        Json.entero(p, ['id', 'profesionalId']): Json.nombrePersona(p),
    };
  }

  Future<List<Map<String, dynamic>>> _listaSegura(String ruta) async {
    try {
      final r = await _api.get(ruta);
      return Json.lista(r).whereType<Map<String, dynamic>>().toList();
    } on ApiException catch (e) {
      if (e.noAutorizado) rethrow;
      return [];
    }
  }

  Future<List<Cita>> citasDelDia(DateTime dia) async {
    if (ApiConfig.modoDemo) {
      await Future.delayed(const Duration(milliseconds: 600));
      return List.of(DemoData.citas);
    }
    final fecha = Formatos.fechaApi(dia);
    final dynamic r;
    try {
      r = await _api.get(ApiConfig.reservas,
          query: {'fechaInicio': fecha, 'fechaFin': fecha});
    } on ApiException catch (e) {
      if (e.statusCode == 404) return [];
      rethrow;
    }

    final citas = Json.lista(r)
        .whereType<Map<String, dynamic>>()
        .map((j) => Cita.fromJson(j,
            servicios: _servicios, profesionales: _profesionales))
        .where((c) =>
            c.inicio == null ||
            (c.inicio!.year == dia.year &&
                c.inicio!.month == dia.month &&
                c.inicio!.day == dia.day))
        .toList();
    return citas;
  }

  Future<List<Cita>> citasDeHoy() => citasDelDia(DateTime.now());

  Future<void> cancelar(int id) async {
    if (ApiConfig.modoDemo) {
      await Future.delayed(const Duration(milliseconds: 500));
      final i = DemoData.citas.indexWhere((c) => c.id == id);
      if (i == -1) throw ApiException('La reserva no existe.', statusCode: 404);
      DemoData.citas[i] = DemoData.citas[i].copyWith(estado: EstadoCita.cancelada);
      return;
    }
    await _api.delete(ApiConfig.reserva(id));
  }
}
