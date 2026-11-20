import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../models/catalogos.dart';
import '../models/cita.dart';
import '../utils/formatos.dart';
import '../utils/json_utils.dart';
import 'api_client.dart';

class CatalogoService {
  CatalogoService._();
  static final CatalogoService instance = CatalogoService._();

  final _api = ApiClient.instance;

  Future<List<Map<String, dynamic>>> _lista(String ruta,
      {Map<String, String>? query}) async {
    try {
      final r = await _api.get(ruta, query: query);
      return Json.lista(r).whereType<Map<String, dynamic>>().toList();
    } on ApiException catch (e) {
      if (e.statusCode == 404) return [];
      rethrow;
    }
  }

  Future<List<Especialidad>> especialidades() async =>
      (await _lista(ApiConfig.especialidades)).map(Especialidad.fromJson).toList();

  static const _kServiciosInactivos = 'kallos_servicios_inactivos';

  Future<Map<int, Map<String, dynamic>>> _leerInactivos() async {
    final s = (await SharedPreferences.getInstance()).getString(_kServiciosInactivos);
    if (s == null) return {};
    try {
      final m = jsonDecode(s) as Map<String, dynamic>;
      return {
        for (final e in m.entries)
          int.parse(e.key): Map<String, dynamic>.from(e.value as Map)
      };
    } catch (_) {
      return {};
    }
  }

  Future<void> _guardarInactivos(Map<int, Map<String, dynamic>> m) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kServiciosInactivos,
        jsonEncode({for (final e in m.entries) '${e.key}': e.value}));
  }

  Future<Servicio?> servicioPorId(int id) async {
    try {
      final r = await _api.get('${ApiConfig.servicios}/$id');
      final data = r is Map<String, dynamic> ? (Json.mapa(r, ['data']) ?? r) : null;
      if (data == null || Json.entero(data, ['id']) == 0) return null;
      return Servicio.fromJson(data);
    } on ApiException catch (e) {
      if (e.noAutorizado) rethrow;
      return null;
    }
  }

  Future<List<Servicio>> servicios() async {
    final activos =
        (await _lista(ApiConfig.servicios)).map(Servicio.fromJson).toList();
    final inactivos = await _leerInactivos();
    if (inactivos.isEmpty) return activos;
    final idsActivos = {for (final s in activos) if (s.activo) s.id};
    final resultado = [...activos];
    var cambios = false;
    for (final e in inactivos.entries.toList()) {
      if (idsActivos.contains(e.key)) {
        inactivos.remove(e.key);
        cambios = true;
        continue;
      }
      if (resultado.any((s) => s.id == e.key)) continue;
      final api = await servicioPorId(e.key);
      resultado.add((api ?? Servicio.fromJson(e.value)).copyWith(activo: false));
    }
    if (cambios) await _guardarInactivos(inactivos);
    return resultado;
  }

  Future<void> crearEspecialidad(String nombre) =>
      _api.post(ApiConfig.especialidades, body: {'nombre': nombre.trim()});

  Future<void> actualizarEspecialidad(int id, String nombre, bool activa) =>
      _api.put('${ApiConfig.especialidades}/$id',
          body: {'nombre': nombre.trim(), 'activa': activa});

  Future<void> eliminarEspecialidad(int id) =>
      _api.delete('${ApiConfig.especialidades}/$id');

  Future<void> crearServicio(Servicio s) async {
    final r = await _api.post(ApiConfig.servicios, body: s.toJson());
    if (s.activo) return;
    final data = r is Map<String, dynamic> ? (Json.mapa(r, ['data']) ?? r) : null;
    final id = Json.entero(data, ['id']);
    if (id == 0) return;
    final inactivos = await _leerInactivos();
    inactivos[id] = Servicio.fromJson({...s.toCache(), 'id': id}).toCache();
    await _guardarInactivos(inactivos);
  }

  Future<void> actualizarServicio(Servicio s) async {
    await _api.put('${ApiConfig.servicios}/${s.id}', body: s.toJson());
    final inactivos = await _leerInactivos();
    if (s.activo) {
      if (inactivos.remove(s.id) == null) return;
    } else {
      inactivos[s.id] = s.toCache();
    }
    await _guardarInactivos(inactivos);
  }

  Future<void> eliminarServicio(int id) async {
    await _api.delete('${ApiConfig.servicios}/$id');
    final inactivos = await _leerInactivos();
    if (inactivos.remove(id) != null) await _guardarInactivos(inactivos);
  }

  static const _kPausados = 'kallos_profesionales_pausados';

  Future<Map<int, Map<String, dynamic>>> _leerPausados() async {
    final s = (await SharedPreferences.getInstance()).getString(_kPausados);
    if (s == null) return {};
    try {
      final m = jsonDecode(s) as Map<String, dynamic>;
      return {
        for (final e in m.entries)
          int.parse(e.key): Map<String, dynamic>.from(e.value as Map)
      };
    } catch (_) {
      return {};
    }
  }

  Future<void> _guardarPausados(Map<int, Map<String, dynamic>> m) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
        _kPausados, jsonEncode({for (final e in m.entries) '${e.key}': e.value}));
  }

  Future<Profesional?> profesionalPorId(int id) async {
    try {
      final r = await _api.get('${ApiConfig.profesionales}/$id');
      final data =
          r is Map<String, dynamic> ? (Json.mapa(r, ['data']) ?? r) : null;
      if (data == null || Json.entero(data, ['id']) == 0) return null;
      return Profesional.fromJson(data);
    } on ApiException catch (e) {
      if (e.noAutorizado) rethrow;
      return null;
    }
  }

  Future<List<Profesional>> profesionales() async {
    final activos =
        (await _lista(ApiConfig.profesionales)).map(Profesional.fromJson).toList();
    final pausados = await _leerPausados();
    if (pausados.isEmpty) return activos;

    final idsActivos = {for (final p in activos) if (p.estado) p.id};
    final resultado = [...activos];
    var cambios = false;
    for (final e in pausados.entries.toList()) {
      if (idsActivos.contains(e.key)) {
        pausados.remove(e.key);
        cambios = true;
        continue;
      }
      if (resultado.any((p) => p.id == e.key)) continue;
      final api = await profesionalPorId(e.key);
      resultado.add((api ?? Profesional.fromJson(e.value)).copyWith(estado: false));
    }
    if (cambios) await _guardarPausados(pausados);
    return resultado;
  }

  Future<void> crearProfesional(Profesional p) =>
      _api.post(ApiConfig.profesionales, body: p.toJson());

  Future<void> actualizarProfesional(Profesional p) async {
    await _api.put('${ApiConfig.profesionales}/${p.id}', body: p.toJson());
    final pausados = await _leerPausados();
    if (p.estado) {
      pausados.remove(p.id);
    } else {
      pausados[p.id] = p.toCache();
    }
    await _guardarPausados(pausados);
  }

  Future<void> eliminarProfesional(int id) async {
    await _api.delete('${ApiConfig.profesionales}/$id');
    final pausados = await _leerPausados();
    if (pausados.remove(id) != null) await _guardarPausados(pausados);
  }

  Future<List<Cliente>> clientes() async =>
      (await _lista(ApiConfig.clientes)).map(Cliente.fromJson).toList();

  Future<Cliente?> buscarClientePorDocumento(String documento) async {
    try {
      final r = await _api.get('${ApiConfig.clientes}/$documento');
      final data = r is Map<String, dynamic>
          ? (Json.mapa(r, ['data']) ?? r)
          : null;
      if (data == null || Json.entero(data, ['id']) == 0) return null;
      return Cliente.fromJson(data);
    } on ApiException catch (e) {
      if (e.statusCode == 404 || e.statusCode == 400) return null;
      rethrow;
    }
  }

  Future<Cliente> crearCliente(Cliente c) async {
    final r = await _api.post(ApiConfig.clientes, body: c.toJson());
    final data = r is Map<String, dynamic> ? (Json.mapa(r, ['data']) ?? r) : null;
    if (data != null && Json.entero(data, ['id']) != 0) {
      return Cliente.fromJson(data);
    }
    return await buscarClientePorDocumento(c.documento) ?? c;
  }

  Future<void> actualizarCliente(Cliente c) =>
      _api.put('${ApiConfig.clientes}/${c.id}', body: {
        'documento': c.documento,
        'nombres': c.nombres,
        'apellidos': c.apellidos,
        'celular': c.celular,
        'correo': c.correo,
      });

  Future<void> eliminarCliente(int id) => _api.delete('${ApiConfig.clientes}/$id');

  Future<List<HorarioLaboral>> horariosLaborales() async =>
      (await _lista(ApiConfig.horariosLaboral))
          .map(HorarioLaboral.fromJson)
          .toList();

  Future<List<HorarioLaboral>> horariosDe(int profesionalId) async =>
      (await _lista('${ApiConfig.horariosLaboral}/profesional/$profesionalId'))
          .map(HorarioLaboral.fromJson)
          .toList();

  Future<void> crearHorario(HorarioLaboral h) =>
      _api.post(ApiConfig.horariosLaboral, body: h.toJson());

  Future<void> actualizarHorario(HorarioLaboral h) =>
      _api.put('${ApiConfig.horariosLaboral}/${h.id}', body: h.toJson());

  Future<void> eliminarHorario(int id) =>
      _api.delete('${ApiConfig.horariosLaboral}/$id');

  Future<List<Cita>> reservas({DateTime? desde, DateTime? hasta}) async {
    final query = desde == null
        ? null
        : {
            'fechaInicio': Formatos.fechaApi(desde),
            'fechaFin': Formatos.fechaApi(hasta ?? desde),
          };
    return (await _lista(ApiConfig.reservas, query: query))
        .map((j) => Cita.fromJson(j))
        .toList();
  }

  Future<void> crearReserva({
    required DateTime fechaHora,
    required int servicioId,
    required int clienteId,
    int? profesionalId,
    String notas = '',
  }) async {
    await _api.post(ApiConfig.reservas, body: {
      'fecha': '${Formatos.fechaApi(fechaHora)} ${Formatos.horaApi(fechaHora)}',
      'servicioId': servicioId,
      'clienteId': clienteId,
      if (profesionalId != null) 'profesionalId': profesionalId,
      if (notas.trim().isNotEmpty) 'observaciones': notas.trim(),
    });
  }

  Future<void> editarReserva({
    required int id,
    required DateTime fechaHora,
    required int servicioId,
  }) async {
    await _api.put(ApiConfig.reserva(id), body: {
      'fecha': '${Formatos.fechaApi(fechaHora)}T${Formatos.horaApi(fechaHora)}',
      'servicioId': servicioId,
    });
  }

  Future<void> cancelarReserva(int id) => _api.delete(ApiConfig.reserva(id));

  Future<List<Map<String, dynamic>>> liquidaciones() =>
      _lista(ApiConfig.liquidaciones);

  Future<void> crearLiquidacion(DateTime inicio, DateTime fin) =>
      _api.post(ApiConfig.liquidaciones, body: {
        'fechaInicio': Formatos.fechaApi(inicio),
        'fechaFin': Formatos.fechaApi(fin),
      });

  Future<Map<int, double>> comisionesDeCierre(int cierreId) async {
    final lista = await _lista(ApiConfig.comisiones,
        query: {'cierreId': '$cierreId'});
    final r = <int, double>{};
    for (final c in lista) {
      final prof = Json.entero(c, ['profesionalId']) != 0
          ? Json.entero(c, ['profesionalId'])
          : Json.entero(Json.mapa(c, ['profesional']), ['id']);
      final valor = Json.decimal(c,
          ['valorComision', 'comision', 'totalComision', 'monto', 'valor', 'total']);
      if (prof != 0) r[prof] = (r[prof] ?? 0) + valor;
    }
    return r;
  }

  Future<List<String>?> horasDisponibles({
    required DateTime fecha,
    required int servicioId,
    int? profesionalId,
  }) async {
    try {
      final r = await _api.get(ApiConfig.agenda, query: {
        'fecha': Formatos.fechaApi(fecha),
        'servicioId': '$servicioId',
        if (profesionalId != null) 'profesionalId': '$profesionalId',
      });
      final horas = <String>{};
      _extraerHoras(r is Map<String, dynamic> ? (r['data'] ?? r) : r, horas);
      if (horas.isEmpty && !_esListaVacia(r)) return null;
      return horas.toList()..sort();
    } on ApiException catch (e) {
      if (e.noAutorizado) rethrow;
      return null;
    }
  }

  bool _esListaVacia(dynamic r) {
    final l = r is Map<String, dynamic> ? r['data'] : r;
    return l is List && l.isEmpty;
  }

  static final _regexHora = RegExp(r'(?:T|\s|^)(\d{1,2}):(\d{2})');

  void _extraerHoras(dynamic nodo, Set<String> horas) {
    if (nodo is String) {
      final m = _regexHora.firstMatch(nodo);
      if (m != null) horas.add('${m.group(1)!.padLeft(2, '0')}:${m.group(2)}');
    } else if (nodo is List) {
      for (final n in nodo) {
        _extraerHoras(n, horas);
      }
    } else if (nodo is Map<String, dynamic>) {
      final disp = Json.valor(nodo, ['disponible', 'libre', 'available']);
      if (disp == false) return;
      if (Json.valor(nodo, ['ocupado', 'reservado']) == true) return;
      final h = Json.valor(nodo, ['horaInicio', 'hora', 'inicio', 'horario', 'fechaHora']);
      if (h is String) {
        _extraerHoras(h, horas);
        return;
      }
      for (final v in nodo.values) {
        if (v is List || v is Map) _extraerHoras(v, horas);
      }
    }
  }
}
