import 'package:flutter/material.dart';

import '../models/catalogos.dart';
import '../models/cita.dart';
import '../services/api_client.dart';
import '../services/catalogo_service.dart';
import '../theme/app_colors.dart';
import '../utils/formatos.dart';
import '../utils/json_utils.dart';
import '../widgets/comunes.dart';

enum TipoPeriodo { semanal, quincenal, mensual, personalizado }

class Periodo {
  final DateTime inicio;
  final DateTime fin;
  final String etiqueta;
  const Periodo(this.inicio, this.fin, this.etiqueta);

  bool contiene(DateTime d) {
    final dia = DateTime(d.year, d.month, d.day);
    return !dia.isBefore(inicio) && !dia.isAfter(fin);
  }

  int get dias => fin.difference(inicio).inDays + 1;
}

class _Liquidacion {
  final int id;
  final DateTime? inicio;
  final DateTime? fin;
  final DateTime? creada;
  const _Liquidacion(this.id, this.inicio, this.fin, this.creada);

  static DateTime? _f(dynamic v) {
    final d = DateTime.tryParse(v?.toString() ?? '');
    return d == null ? null : DateTime(d.year, d.month, d.day);
  }

  factory _Liquidacion.fromJson(Map<String, dynamic> j) => _Liquidacion(
        Json.entero(j, ['id', 'cierreId', 'liquidacionId']),
        _f(Json.valor(j, ['fechaInicio', 'desde', 'inicio'])),
        _f(Json.valor(j, ['fechaFin', 'hasta', 'fin'])),
        _f(Json.valor(j, ['fechaCreacion', 'fechaRegistro', 'creadoEn', 'fecha'])),
      );
}

class _Resumen {
  final Profesional profesional;
  final List<Cita> servicios;
  final double bruto;
  final double comision;
  const _Resumen(this.profesional, this.servicios, this.bruto, this.comision);
}

class CierresScreen extends StatefulWidget {
  final VoidCallback? onVolver;
  const CierresScreen({super.key, this.onVolver});

  @override
  State<CierresScreen> createState() => _CierresScreenState();
}

class _CierresScreenState extends State<CierresScreen> {
  final _api = CatalogoService.instance;
  static const _meses = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio',
    'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
  ];

  TipoPeriodo _tipo = TipoPeriodo.quincenal;
  late Periodo _periodo;
  bool _cargando = true;
  bool _generando = false;
  String? _error;

  List<Cita> _reservas = [];
  List<Profesional> _profesionales = [];
  List<_Liquidacion> _liquidaciones = [];
  Map<int, double> _comisionesApi = {};

  @override
  void initState() {
    super.initState();
    _periodo = _calcular(_tipo, DateTime.now());
    _cargar();
  }

  Periodo _calcular(TipoPeriodo tipo, DateTime ref, [Periodo? personalizado]) {
    final d = DateTime(ref.year, ref.month, ref.day);
    final ultimoDia = DateTime(d.year, d.month + 1, 0).day;
    switch (tipo) {
      case TipoPeriodo.semanal:
        final lunes = d.subtract(Duration(days: d.weekday - 1));
        final domingo = lunes.add(const Duration(days: 6));
        return Periodo(lunes, domingo,
            'Semana ${lunes.day}/${lunes.month} - ${domingo.day}/${domingo.month}');
      case TipoPeriodo.quincenal:
        return d.day <= 15
            ? Periodo(DateTime(d.year, d.month, 1), DateTime(d.year, d.month, 15),
                '1ª Quincena ${_meses[d.month - 1]}')
            : Periodo(DateTime(d.year, d.month, 16), DateTime(d.year, d.month, ultimoDia),
                '2ª Quincena ${_meses[d.month - 1]}');
      case TipoPeriodo.mensual:
        return Periodo(DateTime(d.year, d.month, 1), DateTime(d.year, d.month, ultimoDia),
            '${_meses[d.month - 1]} ${d.year}');
      case TipoPeriodo.personalizado:
        return personalizado ?? _periodo;
    }
  }

  Periodo _anterior(Periodo p) {
    if (_tipo == TipoPeriodo.personalizado) {
      final fin = p.inicio.subtract(const Duration(days: 1));
      return Periodo(fin.subtract(Duration(days: p.dias - 1)), fin, 'Anterior');
    }
    return _calcular(_tipo, p.inicio.subtract(const Duration(days: 1)));
  }

  String _rango(Periodo p) =>
      '${p.inicio.day} ${_meses[p.inicio.month - 1].substring(0, 3)} - '
      '${p.fin.day} ${_meses[p.fin.month - 1].substring(0, 3)} ${p.fin.year}';

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final anterior = _anterior(_periodo);
      final r = await Future.wait([
        _api.reservas(desde: anterior.inicio, hasta: _periodo.fin),
        _api.profesionales(),
        _api.liquidaciones().catchError((_) => <Map<String, dynamic>>[]),
      ]);
      final liquidaciones = (r[2] as List<Map<String, dynamic>>)
          .map(_Liquidacion.fromJson)
          .toList();
      final cierre = _liquidacionDe(_periodo, liquidaciones);
      final comisiones = cierre == null || cierre.id == 0
          ? <int, double>{}
          : await _api.comisionesDeCierre(cierre.id).catchError((_) => <int, double>{});
      if (!mounted) return;
      setState(() {
        _reservas = r[0] as List<Cita>;
        _profesionales = r[1] as List<Profesional>;
        _liquidaciones = liquidaciones;
        _comisionesApi = comisiones;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo cargar la información del cierre.');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  _Liquidacion? _liquidacionDe(Periodo p, List<_Liquidacion> lista) {
    for (final l in lista) {
      if (l.inicio == p.inicio && l.fin == p.fin) return l;
    }
    return null;
  }

  List<Cita> _realizadas(Periodo p) => _reservas
      .where((c) =>
          c.inicio != null && p.contiene(c.inicio!) && c.estado == EstadoCita.finalizada)
      .toList();

  List<_Resumen> _desglose(List<Cita> realizadas) {
    final lista = <_Resumen>[];
    for (final p in _profesionales) {
      final servicios = realizadas.where((c) => c.profesionalId == p.id).toList();
      if (servicios.isEmpty) continue;
      final bruto = servicios.fold<double>(0, (t, c) => t + c.precio);
      final comision = _comisionesApi[p.id] ?? bruto * p.porcentaje / 100;
      lista.add(_Resumen(p, servicios, bruto, comision));
    }
    lista.sort((a, b) => b.bruto.compareTo(a.bruto));
    return lista;
  }

  Future<void> _cambiarTipo(TipoPeriodo t) async {
    if (t == TipoPeriodo.personalizado) {
      final hoy = DateTime.now();
      final rango = await showDateRangePicker(
        context: context,
        firstDate: DateTime(hoy.year - 2),
        lastDate: DateTime(hoy.year, hoy.month, hoy.day),
        initialDateRange: DateTimeRange(start: _periodo.inicio, end: _periodo.fin.isAfter(hoy) ? hoy : _periodo.fin),
        helpText: 'Periodo personalizado',
      );
      if (rango == null) return;
      setState(() {
        _tipo = t;
        _periodo = Periodo(
            DateTime(rango.start.year, rango.start.month, rango.start.day),
            DateTime(rango.end.year, rango.end.month, rango.end.day),
            'Personalizado');
      });
    } else {
      setState(() {
        _tipo = t;
        _periodo = _calcular(t, DateTime.now());
      });
    }
    _cargar();
  }

  void _elegirPeriodo() {
    if (_tipo == TipoPeriodo.personalizado) {
      _cambiarTipo(TipoPeriodo.personalizado);
      return;
    }
    final opciones = <Periodo>[];
    var p = _calcular(_tipo, DateTime.now());
    for (var i = 0; i < 6; i++) {
      opciones.add(p);
      p = _anterior(p);
    }
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final o in opciones)
              ListTile(
                title: Text(o.etiqueta),
                subtitle: Text(_rango(o)),
                trailing: _liquidacionDe(o, _liquidaciones) != null
                    ? const Etiqueta(
                        texto: 'Liquidado',
                        fondo: AppColors.exitoSuave,
                        color: AppColors.exito)
                    : null,
                selected: o.inicio == _periodo.inicio,
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _periodo = o);
                  _cargar();
                },
              ),
          ],
        ),
      ),
    );
  }

  String _csv(List<_Resumen> desglose) {
    final b = StringBuffer(
        'Periodo;${Formatos.fechaApi(_periodo.inicio)} a ${Formatos.fechaApi(_periodo.fin)}\n'
        'Profesional;Documento;Servicios;Facturacion;Porcentaje;Comision\n');
    for (final r in desglose) {
      b.writeln('${r.profesional.nombreCompleto};${r.profesional.documento};'
          '${r.servicios.length};${r.bruto.round()};'
          '${r.profesional.porcentaje.toStringAsFixed(0)};${r.comision.round()}');
    }
    return b.toString();
  }

  Future<void> _exportar(List<_Resumen> desglose) async {
    if (desglose.isEmpty) {
      mostrarMensaje(context, 'No hay servicios realizados en este periodo.', error: true);
      return;
    }
    await copiarTexto(context, _csv(desglose),
        titulo: 'Nómina ${_periodo.etiqueta} (CSV)',
        mensajeOk: 'Nómina copiada (formato CSV). Pégala en Excel o Google Sheets.');
  }

  Future<void> _generarCierre(List<_Resumen> desglose) async {
    final total = desglose.fold<double>(0, (t, r) => t + r.comision);
    final ok = await confirmar(context,
        titulo: 'Generar cierre',
        mensaje: 'Se liquidarán las comisiones de ${_periodo.etiqueta} '
            '(${_rango(_periodo)}) por ${Formatos.moneda(total)} '
            'para ${desglose.length} profesionales. ¿Continuar?',
        textoAceptar: 'Generar cierre');
    if (!ok || !mounted) return;
    setState(() => _generando = true);
    try {
      await _api.crearLiquidacion(_periodo.inicio, _periodo.fin);
      if (!mounted) return;
      await copiarTexto(context, _csv(desglose),
          titulo: 'Cierre generado · Nómina (CSV)',
          mensajeOk: 'Cierre generado. La nómina quedó copiada en formato CSV.');
      if (!mounted) return;
      await _cargar();
    } on ApiException catch (e) {
      if (mounted) mostrarMensaje(context, e.mensaje, error: true);
    } finally {
      if (mounted) setState(() => _generando = false);
    }
  }

  void _verServicios(_Resumen r) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: AppColors.fondo,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.92,
        builder: (_, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            Text(r.profesional.nombreCompleto,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            Text('${_periodo.etiqueta} · ${r.servicios.length} servicios',
                style: const TextStyle(color: AppColors.textoSecundario)),
            const SizedBox(height: 12),
            for (final c in r.servicios) ...[
              TarjetaKallos(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.servicio, style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text('${c.cliente} · ${Formatos.fechaApi(c.inicio!)} ${c.horaInicio}',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textoSecundario)),
                      ],
                    ),
                  ),
                  Text(Formatos.moneda(c.precio),
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ]),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final realizadas = _realizadas(_periodo);
    final desglose = _desglose(realizadas);
    return Scaffold(
      appBar: AppBar(
        leading: widget.onVolver == null
            ? null
            : IconButton(icon: const Icon(Icons.arrow_back), onPressed: widget.onVolver),
        titleSpacing: widget.onVolver == null ? null : 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cierres y Liquidaciones',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            Text('Kallos', style: TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Exportar nómina (CSV)',
            onPressed: _cargando ? null : () => _exportar(desglose),
            icon: const Icon(Icons.download_outlined),
          ),
          IconButton(
              tooltip: 'Actualizar', onPressed: _cargar, icon: const Icon(Icons.refresh)),
        ],
        bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider()),
      ),
      body: _cargando && _reservas.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _vistaError()
              : RefreshIndicator(
                  onRefresh: _cargar,
                  child: _contenido(realizadas, desglose),
                ),
    );
  }

  Widget _vistaError() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            SizedBox(
                width: 180,
                child: ElevatedButton(onPressed: _cargar, child: const Text('Reintentar'))),
          ]),
        ),
      );

  Widget _contenido(List<Cita> realizadas, List<_Resumen> desglose) {
    final total = realizadas.fold<double>(0, (t, c) => t + c.precio);
    final totalAnterior =
        _realizadas(_anterior(_periodo)).fold<double>(0, (t, c) => t + c.precio);
    final variacion = totalAnterior == 0 ? null : ((total - totalAnterior) / totalAnterior) * 100;
    final comisiones = desglose.fold<double>(0, (t, r) => t + r.comision);
    final margen = total - comisiones;
    final rendimiento = total == 0 ? 0 : (margen / total) * 100;
    final cierre = _liquidacionDe(_periodo, _liquidaciones);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _selectorTipo(),
        const SizedBox(height: 12),
        TarjetaKallos(
          onTap: _elegirPeriodo,
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            const Icon(Icons.calendar_month_outlined, color: AppColors.textoSecundario),
            const SizedBox(width: 10),
            Expanded(
              child: Text(_rango(_periodo),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
            Etiqueta(
                texto: _periodo.etiqueta,
                fondo: const Color(0xFFE8EAFB),
                color: const Color(0xFF3730A3)),
            const Icon(Icons.expand_more),
          ]),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: _kpi(
              'Total Facturado',
              Formatos.moneda(total),
              Icons.payments_outlined,
              variacion == null
                  ? 'Sin datos del periodo anterior'
                  : '${variacion >= 0 ? '↗ +' : '↘ '}${variacion.toStringAsFixed(1)}% vs anterior',
              colorDetalle: variacion == null
                  ? AppColors.textoSecundario
                  : (variacion >= 0 ? AppColors.exito : AppColors.error),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _kpi('Citas Realizadas', '${realizadas.length}',
                Icons.check_circle_outline, 'servicios finalizados'),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: _kpi('Comisiones', Formatos.moneda(comisiones),
                Icons.pie_chart_outline, 'a liquidar al equipo'),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _kpi('Margen Centro', Formatos.moneda(margen),
                Icons.account_balance_outlined,
                '${rendimiento.toStringAsFixed(1)}% rendimiento neto',
                destacado: true),
          ),
        ]),
        const SizedBox(height: 22),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: Text('Desglose por Profesional',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            ),
            Text(
                desglose.length == 1
                    ? '1 profesional'
                    : '${desglose.length} profesionales',
                style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
          ],
        ),
        const SizedBox(height: 12),
        if (desglose.isEmpty)
          const TarjetaKallos(
            padding: EdgeInsets.symmetric(vertical: 26, horizontal: 16),
            child: Column(children: [
              Icon(Icons.receipt_long_outlined, size: 32, color: AppColors.textoTenue),
              SizedBox(height: 8),
              Text('No hay servicios realizados en este periodo.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textoSecundario)),
            ]),
          )
        else
          for (final r in desglose) ...[
            _tarjetaProfesional(r, cierre),
            const SizedBox(height: 12),
          ],
        const SizedBox(height: 6),
        _tarjetaCierre(desglose, cierre),
      ],
    );
  }

  Widget _selectorTipo() {
    const opciones = [
      (TipoPeriodo.semanal, 'Semanal'),
      (TipoPeriodo.quincenal, 'Quincenal'),
      (TipoPeriodo.mensual, 'Mensual'),
      (TipoPeriodo.personalizado, 'Personalizado'),
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.superficie,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borde),
      ),
      child: Row(
        children: [
          for (final o in opciones)
            Expanded(
              child: GestureDetector(
                onTap: () => _cambiarTipo(o.$1),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: _tipo == o.$1 ? AppColors.primario : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(o.$2,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _tipo == o.$1 ? Colors.white : AppColors.texto)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _kpi(String titulo, String valor, IconData icono, String detalle,
      {Color colorDetalle = AppColors.textoSecundario, bool destacado = false}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.superficie,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(titulo,
                  style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
            ),
            Icon(icono, size: 18, color: AppColors.primario),
          ]),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(valor,
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: destacado ? AppColors.primario : AppColors.texto)),
          ),
          const SizedBox(height: 2),
          Text(detalle, style: TextStyle(fontSize: 11, color: colorDetalle)),
        ],
      ),
    );
  }

  Widget _celda(String titulo, String valor) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            color: const Color(0xFFEEF0FA), borderRadius: BorderRadius.circular(8)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo,
                style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
            const SizedBox(height: 2),
            Text(valor, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ],
        ),
      );

  Widget _tarjetaProfesional(_Resumen r, _Liquidacion? cierre) {
    final p = r.profesional;
    final liquidado = cierre != null;
    return TarjetaKallos(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AvatarIniciales(p.nombreCompleto, radio: 22,
                  fondo: liquidado ? const Color(0xFFBDEBCB) : const Color(0xFFE8EAFB),
                  color: liquidado ? const Color(0xFF14532D) : const Color(0xFF3730A3)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(p.nombreCompleto,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                        liquidado
                            ? Etiqueta(
                                texto: cierre.creada == null
                                    ? 'Liquidado'
                                    : 'Liquidado el ${cierre.creada!.day}/${cierre.creada!.month}',
                                icono: Icons.done_all,
                                fondo: AppColors.exitoSuave,
                                color: AppColors.exito)
                            : const Etiqueta(
                                texto: 'Pendiente de liquidar',
                                fondo: AppColors.alertaSuave,
                                color: AppColors.alerta),
                      ],
                    ),
                    Text(
                        '${p.especialidad.isEmpty ? 'Especialista' : p.especialidad} · '
                        '${r.servicios.length} servicios',
                        style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text('COMISIÓN GENERADA',
              style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 0.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textoSecundario)),
          Text(Formatos.moneda(r.comision),
              style: const TextStyle(
                  fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.primario)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _celda('Facturación bruta', Formatos.moneda(r.bruto))),
            const SizedBox(width: 10),
            Expanded(child: _celda('% Pactado', '${p.porcentaje.toStringAsFixed(0)}%')),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _celda('Citas atendidas', '${r.servicios.length} servicios')),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: () => _verServicios(r),
                  icon: Icon(liquidado ? Icons.receipt_outlined : Icons.list_alt, size: 18),
                  label: Text(liquidado ? 'Ver recibo' : 'Ver servicios'),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _tarjetaCierre(List<_Resumen> desglose, _Liquidacion? cierre) {
    final hoy = DateTime.now();
    final terminado = DateTime(hoy.year, hoy.month, hoy.day).isAfter(_periodo.fin);
    final String detalle;
    if (cierre != null) {
      detalle = 'Este periodo ya fue liquidado. Puedes volver a exportar la nómina.';
    } else if (!terminado) {
      detalle = 'El periodo termina el ${_periodo.fin.day}/${_periodo.fin.month}. '
          'El cierre se habilita cuando finalice.';
    } else if (desglose.isEmpty) {
      detalle = 'No hay servicios realizados para liquidar.';
    } else {
      detalle = '${desglose.length} liquidaciones pendientes por '
          '${Formatos.moneda(desglose.fold<double>(0, (t, r) => t + r.comision))}.';
    }
    final puedeGenerar = cierre == null && terminado && desglose.isNotEmpty;

    return TarjetaKallos(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Cierre de ${_periodo.etiqueta}',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(detalle, style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _generando
                ? null
                : cierre != null
                    ? () => _exportar(desglose)
                    : puedeGenerar
                        ? () => _generarCierre(desglose)
                        : null,
            icon: _generando
                ? const CargandoBoton()
                : Icon(cierre != null ? Icons.download_outlined : Icons.lock_clock_outlined,
                    size: 20),
            label: FittedBox(
              child: Text(cierre != null
                  ? 'Exportar nómina'
                  : 'Generar cierre y exportar nómina'),
            ),
          ),
        ],
      ),
    );
  }
}
