import 'package:flutter/material.dart';

import '../models/catalogos.dart';
import '../models/cita.dart';
import '../services/api_client.dart';
import '../services/catalogo_service.dart';
import '../theme/app_colors.dart';
import '../utils/formatos.dart';
import '../widgets/comunes.dart';
import '../widgets/formularios.dart';
import '../widgets/home_widgets.dart';
import '../widgets/reserva_sheets.dart';
import 'configurar_jornada_screen.dart';

class ProfesionalFichaScreen extends StatefulWidget {
  final Profesional profesional;
  const ProfesionalFichaScreen({super.key, required this.profesional});

  @override
  State<ProfesionalFichaScreen> createState() => _ProfesionalFichaScreenState();
}

class _ProfesionalFichaScreenState extends State<ProfesionalFichaScreen> {
  static const _meses = [
    'ENERO', 'FEBRERO', 'MARZO', 'ABRIL', 'MAYO', 'JUNIO', 'JULIO',
    'AGOSTO', 'SEPTIEMBRE', 'OCTUBRE', 'NOVIEMBRE', 'DICIEMBRE'
  ];
  static const _dias = ['Domingo', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado'];

  final _api = CatalogoService.instance;
  late Profesional _p;
  List<Cita> _reservas = [];
  List<HorarioLaboral> _horarios = [];
  List<Servicio> _servicios = [];
  List<Especialidad> _especialidades = [];
  Map<int, Cliente> _clientes = {};
  bool _cargando = true;
  bool _procesando = false;
  bool _huboCambios = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _p = widget.profesional;
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _error = null;
      if (_reservas.isEmpty) _cargando = true;
    });
    try {
      final ahora = DateTime.now();
      final inicioMesAnterior = DateTime(ahora.year, ahora.month - 1, 1);
      final finMes = DateTime(ahora.year, ahora.month + 1, 0);
      final r = await Future.wait([
        _api.reservas(desde: inicioMesAnterior, hasta: finMes),
        _api.horariosDe(_p.id).catchError((_) => <HorarioLaboral>[]),
        _api.servicios(),
        _api.especialidades(),
        _api.clientes().catchError((_) => <Cliente>[]),
      ]);
      if (!mounted) return;
      setState(() {
        _reservas = (r[0] as List<Cita>)
            .where((c) => c.profesionalId == _p.id && c.estado != EstadoCita.cancelada)
            .toList();
        _horarios = r[1] as List<HorarioLaboral>;
        _servicios = (r[2] as List<Servicio>).where((s) => s.especialidadId == _p.especialidadId).toList();
        _especialidades = r[3] as List<Especialidad>;
        _clientes = {for (final c in r[4] as List<Cliente>) c.id: c};
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _pausar() async {
    final activo = !_p.estado;
    if (!activo) {
      final ok = await confirmar(context,
          titulo: 'Poner en pausa',
          mensaje: '${_p.nombreCompleto} no recibirá nuevas reservas hasta que lo reactives.',
          textoAceptar: 'Pausar',
          peligroso: true);
      if (!ok || !mounted) return;
    }
    setState(() => _procesando = true);
    try {
      final nuevo = _p.copyWith(estado: activo);
      await _api.actualizarProfesional(nuevo);
      if (!mounted) return;
      setState(() {
        _p = nuevo;
        _huboCambios = true;
      });
      mostrarMensaje(context, activo ? '${_p.nombres} está en turno' : '${_p.nombres} quedó en pausa');
    } on ApiException catch (e) {
      if (mounted) mostrarMensaje(context, e.mensaje, error: true);
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  Future<void> _editar() async {
    final ok = await abrirFormulario<bool>(
        context, ProfesionalFormSheet(profesional: _p, especialidades: _especialidades));
    if (ok != true || !mounted) return;
    _huboCambios = true;
    final actualizado = await _api.profesionalPorId(_p.id);
    if (actualizado != null && mounted) setState(() => _p = actualizado);
    _cargar();
  }

  Future<void> _jornada() async {
    final ok = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => ConfigurarJornadaScreen(profesional: _p)));
    if (ok == true) {
      _huboCambios = true;
      _cargar();
    }
  }

  Future<void> _detalle(Cita c) async {
    final cambio = await abrirDetalleReserva(context, c, cliente: _clientes[c.clienteId]);
    if (cambio == true) _cargar();
  }

  Future<void> _eliminar() async {
    if (_reservas.any((c) => c.vigente)) {
      mostrarMensaje(context, 'Tiene reservas pendientes. Ponlo en pausa en lugar de eliminarlo.',
          error: true);
      return;
    }
    final ok = await confirmar(context,
        titulo: 'Eliminar profesional',
        mensaje: '¿Seguro que deseas eliminar a ${_p.nombreCompleto}?',
        textoAceptar: 'Eliminar',
        peligroso: true);
    if (!ok || !mounted) return;
    try {
      await _api.eliminarProfesional(_p.id);
      if (!mounted) return;
      mostrarMensaje(context, '${_p.nombreCompleto} fue eliminado');
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) mostrarMensaje(context, e.mensaje, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_huboCambios,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, true);
      },
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          title: const Text('Ficha de Profesional',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          actions: [
            PopupMenuButton<String>(
              onSelected: (v) {
                switch (v) {
                  case 'editar':
                    _editar();
                  case 'jornada':
                    _jornada();
                  case 'eliminar':
                    _eliminar();
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'editar', child: Text('Editar ficha')),
                PopupMenuItem(value: 'jornada', child: Text('Configurar jornada')),
                PopupMenuItem(
                    value: 'eliminar',
                    child: Text('Eliminar', style: TextStyle(color: AppColors.error))),
              ],
            ),
          ],
          bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider()),
        ),
        body: _cargando
            ? const Center(child: CircularProgressIndicator())
            : _error != null && _reservas.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        SizedBox(
                            width: 180,
                            child: ElevatedButton(
                                onPressed: _cargar, child: const Text('Reintentar'))),
                      ]),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _cargar,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      children: [
                        _cabecera(),
                        const SizedBox(height: 12),
                        _acciones(),
                        const SizedBox(height: 16),
                        _rendimiento(),
                        const SizedBox(height: 14),
                        _citasHoy(),
                        const SizedBox(height: 14),
                        _horario(),
                        const SizedBox(height: 14),
                        _serviciosAsignados(),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _cabecera() {
    String especialidad = _p.especialidad;
    if (especialidad.isEmpty) {
      for (final e in _especialidades) {
        if (e.id == _p.especialidadId) especialidad = e.nombre;
      }
    }
    return TarjetaKallos(
      child: Column(
        children: [
          Row(children: [
            Stack(children: [
              AvatarIniciales(_p.nombreCompleto, radio: 32),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: _p.estado ? AppColors.exito : AppColors.textoTenue,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ]),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_p.nombreCompleto,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Etiqueta(
                    texto: _p.estado ? 'En turno activo' : 'En pausa',
                    punto: true,
                    fondo: _p.estado ? AppColors.exitoSuave : AppColors.neutroSuave,
                    color: _p.estado ? AppColors.exito : AppColors.neutro,
                  ),
                  const SizedBox(height: 4),
                  Text(especialidad.isEmpty ? 'Especialista' : especialidad,
                      style: const TextStyle(color: AppColors.textoSecundario)),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 12),
          const Divider(),
          _fila(Icons.badge_outlined, 'Documento', Text(_p.documento,
              style: const TextStyle(fontWeight: FontWeight.w600))),
          _fila(
              Icons.percent,
              'Comisión pactada',
              Etiqueta(
                  texto: '${_p.porcentaje.toStringAsFixed(0)}% por servicio',
                  fondo: const Color(0xFFE8EAFB),
                  color: const Color(0xFF3730A3))),
        ],
      ),
    );
  }

  Widget _fila(IconData icono, String titulo, Widget valor) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Icon(icono, size: 17, color: AppColors.textoSecundario),
          const SizedBox(width: 10),
          Text(titulo, style: const TextStyle(color: AppColors.textoSecundario)),
          const Spacer(),
          valor,
        ]),
      );

  Widget _acciones() {
    Widget boton(IconData icono, String texto, VoidCallback? onTap) => Expanded(
          child: Material(
            color: AppColors.superficie,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.borde)),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(children: [
                  Icon(icono, size: 20),
                  const SizedBox(height: 4),
                  Text(texto,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ),
        );
    return Row(children: [
      boton(Icons.edit_outlined, 'Editar ficha', _editar),
      const SizedBox(width: 8),
      boton(Icons.edit_calendar_outlined, 'Jornada', _jornada),
      const SizedBox(width: 8),
      boton(_p.estado ? Icons.pause_circle_outline : Icons.play_circle_outline,
          _p.estado ? 'Pausar' : 'Reactivar', _procesando ? null : _pausar),
    ]);
  }

  bool _enMes(DateTime? d, DateTime ref) =>
      d != null && d.year == ref.year && d.month == ref.month;

  Widget _rendimiento() {
    final ahora = DateTime.now();
    final anterior = DateTime(ahora.year, ahora.month - 1, 1);
    List<Cita> atendidas(DateTime ref) =>
        _reservas.where((c) => c.estado == EstadoCita.finalizada && _enMes(c.inicio, ref)).toList();
    final mes = atendidas(ahora);
    final previo = atendidas(anterior);
    final facturacion = mes.fold<double>(0, (t, c) => t + c.precio);
    final facturacionPrevia = previo.fold<double>(0, (t, c) => t + c.precio);
    final comision = facturacion * _p.porcentaje / 100;
    final ticket = mes.isEmpty ? 0.0 : facturacion / mes.length;
    final ticketPrevio = previo.isEmpty ? 0.0 : facturacionPrevia / previo.length;

    String? variacion(num actual, num antes) {
      if (antes == 0) return null;
      final v = ((actual - antes) / antes * 100).round();
      return '${v >= 0 ? '↗ +' : '↘ '}$v%';
    }

    Widget caja(String titulo, String valor, String detalle, String? etiqueta,
            {bool destacado = false}) =>
        Expanded(
          child: Container(
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
                  if (etiqueta != null)
                    Text(etiqueta,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(valor,
                      style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: destacado ? AppColors.primario : AppColors.texto)),
                ),
                Text(detalle,
                    style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
              ],
            ),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Expanded(
            child: Text('Rendimiento del Mes',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
          Text('${_meses[ahora.month - 1]} ${ahora.year}',
              style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          caja('Citas atendidas', '${mes.length}', 'Mes anterior: ${previo.length}',
              variacion(mes.length, previo.length)),
          const SizedBox(width: 10),
          caja('Facturación', Formatos.moneda(facturacion), 'Bruto facturado',
              variacion(facturacion, facturacionPrevia)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          caja('Comisión neta', Formatos.moneda(comision), 'A liquidar en el cierre',
              '${_p.porcentaje.toStringAsFixed(0)}%',
              destacado: true),
          const SizedBox(width: 10),
          caja('Ticket medio', Formatos.moneda(ticket),
              ticketPrevio == 0 ? 'Por servicio' : 'Mes anterior: ${Formatos.moneda(ticketPrevio)}',
              null),
        ]),
      ],
    );
  }

  Widget _citasHoy() {
    final hoy = DateTime.now();
    final citas = _reservas
        .where((c) =>
            c.inicio != null &&
            c.inicio!.year == hoy.year &&
            c.inicio!.month == hoy.month &&
            c.inicio!.day == hoy.day)
        .toList()
      ..sort((a, b) => a.horaInicio.compareTo(b.horaInicio));
    final restantes = citas.where((c) => c.vigente || c.estado == EstadoCita.enCurso).length;
    return TarjetaKallos(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const CircleAvatar(radius: 5, backgroundColor: AppColors.primario),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('Citas para Hoy',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
            Text(restantes == 1 ? '1 cita restante' : '$restantes citas restantes',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.primario, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 10),
          if (citas.isEmpty)
            const Text('No tiene reservas para hoy.',
                style: TextStyle(color: AppColors.textoSecundario)),
          for (final c in citas)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => _detalle(c),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: const Color(0xFFF6F7FB), borderRadius: BorderRadius.circular(10)),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: c.estado == EstadoCita.enCurso
                            ? AppColors.exitoSuave
                            : const Color(0xFFE8EAFB),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(c.horaInicio, style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.cliente, style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text('${c.servicio} (${c.duracion} min)',
                              style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
                        ],
                      ),
                    ),
                    EtiquetaEstadoCita(c.estado),
                  ]),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _horario() {
    final porDia = {for (final h in _horarios) h.diaSemana: h};
    final orden = [1, 2, 3, 4, 5, 6, 0];
    final grupos = <(List<int>, HorarioLaboral?)>[];
    for (final d in orden) {
      final h = porDia[d];
      if (grupos.isNotEmpty) {
        final ultimo = grupos.last;
        final prev = ultimo.$2;
        final igual = (prev == null && h == null) ||
            (prev != null &&
                h != null &&
                prev.horaInicio == h.horaInicio &&
                prev.horaFin == h.horaFin &&
                prev.tieneAlmuerzo == h.tieneAlmuerzo &&
                prev.inicioAlmuerzo == h.inicioAlmuerzo);
        if (igual) {
          ultimo.$1.add(d);
          continue;
        }
      }
      grupos.add(([d], h));
    }
    final minutos = _horarios.fold<int>(0, (t, h) {
      int m(String s) {
        final p = s.split(':');
        return p.length < 2 ? 0 : int.parse(p[0]) * 60 + int.parse(p[1]);
      }

      var total = m(h.horaFin) - m(h.horaInicio);
      if (h.tieneAlmuerzo) total -= m(h.finAlmuerzo) - m(h.inicioAlmuerzo);
      return t + (total > 0 ? total : 0);
    });

    String nombreGrupo(List<int> dias) => dias.length == 1
        ? _dias[dias.first]
        : dias.length == 2
            ? '${_dias[dias.first].substring(0, 3)} / ${_dias[dias.last].substring(0, 3)}'
            : '${_dias[dias.first]} a ${_dias[dias.last]}';

    return TarjetaKallos(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.schedule, size: 20),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('Horario de Turno Semanal',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
            Text('Jornada ${(minutos / 60).round()}h',
                style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
          ]),
          const SizedBox(height: 10),
          if (_horarios.isEmpty)
            const Text('Sin horario registrado. Configúralo para que pueda recibir reservas.',
                style: TextStyle(color: AppColors.textoSecundario))
          else
            for (final g in grupos)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  SizedBox(
                    width: 110,
                    child: Text(nombreGrupo(g.$1),
                        style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: g.$2 == null ? AppColors.textoSecundario : AppColors.texto)),
                  ),
                  Expanded(
                    child: g.$2 == null
                        ? const Text('Descanso',
                            style: TextStyle(color: AppColors.textoSecundario))
                        : Text('${g.$2!.horaInicio} - ${g.$2!.horaFin}'),
                  ),
                  if (g.$2 == null)
                    const Etiqueta(texto: 'Libre', fondo: Color(0xFFE8EAFB), color: Color(0xFF3730A3))
                  else if (g.$2!.tieneAlmuerzo)
                    Text('Almuerzo ${g.$2!.inicioAlmuerzo} - ${g.$2!.finAlmuerzo}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
                ]),
              ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _jornada,
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
            icon: const Icon(Icons.edit_calendar_outlined, size: 18),
            label: const Text('Modificar horarios y turnos'),
          ),
        ],
      ),
    );
  }

  Widget _serviciosAsignados() {
    final activos = _servicios.where((s) => s.activo).length;
    return TarjetaKallos(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Expanded(
              child: Text('Servicios que atiende',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
            Text('$activos habilitados',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.primario, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 4),
          const Text('Según su especialidad. Se administran en Especialidades & Servicios.',
              style: TextStyle(fontSize: 11, color: AppColors.textoTenue)),
          const SizedBox(height: 10),
          if (_servicios.isEmpty)
            const Text('Su especialidad no tiene servicios todavía.',
                style: TextStyle(color: AppColors.textoSecundario)),
          for (final s in _servicios)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.borde),
              ),
              child: Row(children: [
                CircleAvatar(
                    radius: 4,
                    backgroundColor: s.activo ? AppColors.primario : AppColors.textoTenue),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.nombre, style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text('${s.duracion} min • ${Formatos.moneda(s.precio)}',
                          style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
                    ],
                  ),
                ),
                Etiqueta(
                  texto: s.activo ? 'Activo' : 'Inactivo',
                  fondo: s.activo ? AppColors.exitoSuave : AppColors.neutroSuave,
                  color: s.activo ? AppColors.exito : AppColors.neutro,
                ),
              ]),
            ),
        ],
      ),
    );
  }
}
