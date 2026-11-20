import '../config/api_config.dart';
import '../utils/formatos.dart';
import '../utils/json_utils.dart';

enum EstadoCita { pendiente, confirmada, enCurso, finalizada, cancelada }

extension EstadoCitaX on EstadoCita {
  String get etiqueta => switch (this) {
        EstadoCita.pendiente => 'PENDIENTE',
        EstadoCita.confirmada => 'CONFIRMADA',
        EstadoCita.enCurso => 'EN CURSO',
        EstadoCita.finalizada => 'FINALIZADA',
        EstadoCita.cancelada => 'CANCELADA',
      };

  String get valorApi => switch (this) {
        EstadoCita.pendiente => 'Pendiente',
        EstadoCita.confirmada => 'Confirmada',
        EstadoCita.enCurso => 'EnCurso',
        EstadoCita.finalizada => 'Finalizada',
        EstadoCita.cancelada => 'Cancelada',
      };
}

EstadoCita estadoCitaDesde(dynamic valor) {
  if (valor is num) {
    final i = valor.toInt();
    return (i >= 0 && i < EstadoCita.values.length)
        ? EstadoCita.values[i]
        : EstadoCita.pendiente;
  }
  final s = (valor?.toString() ?? '')
      .toLowerCase()
      .replaceAll(RegExp(r'[\s_\-]'), '');
  if (int.tryParse(s) != null) return estadoCitaDesde(int.parse(s));
  if (s.contains('curso') || s.contains('proceso') || s == 'iniciada') {
    return EstadoCita.enCurso;
  }
  if (s.startsWith('confirm')) return EstadoCita.confirmada;
  if (s.startsWith('final') || s.startsWith('complet') || s.startsWith('termin')) {
    return EstadoCita.finalizada;
  }
  if (s.startsWith('cancel') || s.startsWith('anul')) return EstadoCita.cancelada;
  return EstadoCita.pendiente;
}

class Cita {
  final int id;
  final String horaInicio;
  final String horaFin;
  final String cliente;
  final String servicio;
  final String profesional;
  final EstadoCita estado;
  final double precio;
  final int profesionalId;
  final int clienteId;
  final int servicioId;
  final DateTime? inicio;
  final DateTime? fin;

  const Cita({
    required this.id,
    required this.horaInicio,
    required this.horaFin,
    required this.cliente,
    required this.servicio,
    required this.profesional,
    required this.estado,
    this.precio = 0,
    this.profesionalId = 0,
    this.clienteId = 0,
    this.servicioId = 0,
    this.inicio,
    this.fin,
  });

  String get inicialesCliente => Formatos.iniciales(cliente);

  String get profesionalCorto {
    final partes = profesional.trim().split(RegExp(r'\s+'));
    if (partes.length < 2) return profesional;
    return '${partes.first} ${partes[1][0].toUpperCase()}.';
  }

  factory Cita.fromJson(Map<String, dynamic> json,
      {Map<int, Map<String, dynamic>> servicios = const {},
      Map<int, String> profesionales = const {}}) {
    final servicioJson = Json.mapa(json, ['servicio']) ??
        servicios[Json.entero(json, ['servicioId'])];
    final profesionalJson = Json.mapa(json, ['profesional', 'especialista']);
    final profesionalId = Json.entero(json, ['profesionalId']) != 0
        ? Json.entero(json, ['profesionalId'])
        : Json.entero(servicioJson, ['profesionalId']);

    final dia = _fecha(Json.valor(json, ['fecha', 'fechaReserva', 'dia']));
    final inicio = _combinar(dia, Json.valor(json, ['horaInicio', 'inicio'])) ??
        _fecha(Json.valor(json, ['fechaInicio', 'fechaHora'])) ??
        dia;
    final duracion = Json.entero(servicioJson,
        ['duracion', 'duracionMinutos', 'tiempo', 'minutos'],
        ApiConfig.duracionPorDefecto);
    final fin = _combinar(dia, Json.valor(json, ['horaFin', 'fin'])) ??
        _fecha(Json.valor(json, ['fechaFin'])) ??
        inicio?.add(Duration(minutes: duracion));

    final estado = _estadoDesdeApi(
        Json.valor(json, ['estado', 'estadoReserva', 'estadoCita']), inicio, fin);

    var profesional = Json.nombrePersona(profesionalJson);
    if (profesional.isEmpty) {
      profesional = Json.texto(json, ['nombreProfesional', 'profesionalNombre']);
    }
    if (profesional.isEmpty) profesional = profesionales[profesionalId] ?? '';

    var cliente = Json.texto(json, ['cliente']);
    if (cliente.isEmpty) {
      cliente = Json.texto(json, ['nombreCliente', 'clienteNombre']);
    }
    if (cliente.isEmpty) cliente = Json.nombrePersona(json);
    if (cliente.isEmpty) cliente = 'Cliente';

    var servicio = Json.nombrePersona(servicioJson);
    if (servicio.isEmpty) {
      servicio = Json.texto(json, ['nombreServicio', 'servicioNombre']);
    }

    return Cita(
      id: Json.entero(json, ['id', 'reservaId', 'citaId']),
      horaInicio: inicio != null ? Formatos.hora(inicio.toIso8601String()) : '--:--',
      horaFin: fin != null ? Formatos.hora(fin.toIso8601String()) : '--:--',
      cliente: cliente,
      servicio: servicio.isEmpty ? 'Servicio' : servicio,
      profesional: profesional.isEmpty ? 'Sin asignar' : profesional,
      estado: estado,
      precio: Json.decimal(json, ['precio', 'valor', 'total']) != 0
          ? Json.decimal(json, ['precio', 'valor', 'total'])
          : Json.decimal(servicioJson, ['precio', 'valor', 'tarifa', 'costo']),
      profesionalId: profesionalId,
      clienteId: Json.entero(json, ['clienteId']) != 0
          ? Json.entero(json, ['clienteId'])
          : Json.entero(Json.mapa(json, ['cliente']), ['id']),
      servicioId: Json.entero(json, ['servicioId']) != 0
          ? Json.entero(json, ['servicioId'])
          : Json.entero(servicioJson, ['id']),
      inicio: inicio,
      fin: fin,
    );
  }

  int get duracion =>
      inicio != null && fin != null ? fin!.difference(inicio!).inMinutes : 0;

  bool get vigente =>
      estado == EstadoCita.pendiente || estado == EstadoCita.confirmada;

  static DateTime? _combinar(DateTime? dia, dynamic hora) {
    if (hora == null) return null;
    final h = hora.toString();
    if (h.contains('T') || h.contains('-')) return _fecha(h);
    final partes = h.split(':');
    if (dia == null || partes.length < 2) return null;
    final hh = int.tryParse(partes[0]);
    final mm = int.tryParse(partes[1]);
    if (hh == null || mm == null) return null;
    return DateTime(dia.year, dia.month, dia.day, hh, mm);
  }

  static EstadoCita _estadoDesdeApi(
      dynamic valor, DateTime? inicio, DateTime? fin) {
    if (valor == null) return _estadoPorHora(inicio, fin);
    final n = valor is num ? valor.toInt() : int.tryParse(valor.toString());
    if (n != null) {
      final mapeado = ApiConfig.estadosReserva[n];
      if (mapeado == null) return _estadoPorHora(inicio, fin);
      return estadoCitaDesde(mapeado);
    }
    return estadoCitaDesde(valor);
  }

  static DateTime? _fecha(dynamic v) {
    if (v == null) return null;
    final s = v.toString().replaceFirst(' ', 'T');
    return DateTime.tryParse(s)?.toLocal();
  }

  static EstadoCita _estadoPorHora(DateTime? inicio, DateTime? fin) {
    if (inicio == null) return EstadoCita.confirmada;
    final ahora = DateTime.now();
    if (ahora.isBefore(inicio)) return EstadoCita.confirmada;
    if (fin != null && ahora.isAfter(fin)) return EstadoCita.finalizada;
    return EstadoCita.enCurso;
  }

  Cita copyWith({EstadoCita? estado}) => Cita(
        id: id,
        horaInicio: horaInicio,
        horaFin: horaFin,
        cliente: cliente,
        servicio: servicio,
        profesional: profesional,
        estado: estado ?? this.estado,
        precio: precio,
        profesionalId: profesionalId,
        clienteId: clienteId,
        servicioId: servicioId,
        inicio: inicio,
        fin: fin,
      );
}
