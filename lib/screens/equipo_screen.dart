import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../models/catalogos.dart';
import '../models/cita.dart';
import '../services/api_client.dart';
import '../services/catalogo_service.dart';
import '../theme/app_colors.dart';
import '../utils/formatos.dart';
import '../widgets/comunes.dart';
import '../widgets/formularios.dart';
import '../widgets/home_widgets.dart';
import 'configurar_jornada_screen.dart';
import 'profesional_ficha_screen.dart';

enum FiltroEquipo { activos, pausa, todos }

class EquipoScreen extends StatefulWidget {
  final VoidCallback? onVolver;
  const EquipoScreen({super.key, this.onVolver});

  @override
  State<EquipoScreen> createState() => _EquipoScreenState();
}

class _EquipoScreenState extends State<EquipoScreen> {
  final _api = CatalogoService.instance;
  final _busqueda = TextEditingController();

  bool _cargando = true;
  String? _error;
  List<Profesional> _profesionales = [];
  List<Especialidad> _especialidades = [];
  List<Servicio> _servicios = [];
  List<HorarioLaboral> _horarios = [];
  List<Cita> _citasHoy = [];

  FiltroEquipo _filtro = FiltroEquipo.activos;
  int? _especialidadFiltro;
  int? _expandido;
  final Set<int> _procesando = {};

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _error = null;
      if (_profesionales.isEmpty) _cargando = true;
    });
    try {
      final hoy = DateTime.now();
      final r = await Future.wait([
        _api.profesionales(),
        _api.especialidades(),
        _api.servicios(),
        _api.horariosLaborales().catchError((_) => <HorarioLaboral>[]),
        _api.reservas(desde: hoy, hasta: hoy),
      ]);
      if (!mounted) return;
      setState(() {
        _profesionales = (r[0] as List<Profesional>)
          ..sort((a, b) => a.nombreCompleto.compareTo(b.nombreCompleto));
        _especialidades = r[1] as List<Especialidad>;
        _servicios = r[2] as List<Servicio>;
        _horarios = r[3] as List<HorarioLaboral>;
        _citasHoy = (r[4] as List<Cita>)
            .where((c) =>
                c.estado != EstadoCita.cancelada &&
                c.inicio != null &&
                c.inicio!.day == hoy.day &&
                c.inicio!.month == hoy.month &&
                c.inicio!.year == hoy.year)
            .toList()
          ..sort((a, b) => a.horaInicio.compareTo(b.horaInicio));
        _expandido ??= _visibles.isNotEmpty ? _visibles.first.id : null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo cargar el equipo.');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  String _nombreEspecialidad(Profesional p) {
    if (p.especialidad.isNotEmpty) return p.especialidad;
    for (final e in _especialidades) {
      if (e.id == p.especialidadId) return e.nombre;
    }
    return 'Sin especialidad';
  }

  List<Servicio> _serviciosDe(Profesional p) =>
      _servicios.where((s) => s.especialidadId == p.especialidadId).toList();

  List<Cita> _citasDe(Profesional p) =>
      _citasHoy.where((c) => c.profesionalId == p.id).toList();

  HorarioLaboral? _horarioHoy(Profesional p) {
    final dia = HorarioLaboral.diaApi(DateTime.now());
    for (final h in _horarios) {
      if (h.profesionalId == p.id && h.diaSemana == dia) return h;
    }
    return null;
  }

  List<Profesional> get _visibles {
    final q = _busqueda.text.trim().toLowerCase();
    return _profesionales.where((p) {
      final pasaFiltro = switch (_filtro) {
        FiltroEquipo.activos => p.estado,
        FiltroEquipo.pausa => !p.estado,
        FiltroEquipo.todos => true,
      };
      if (!pasaFiltro) return false;
      if (_especialidadFiltro != null && p.especialidadId != _especialidadFiltro) {
        return false;
      }
      if (q.isEmpty) return true;
      return p.nombreCompleto.toLowerCase().contains(q) ||
          _nombreEspecialidad(p).toLowerCase().contains(q) ||
          _serviciosDe(p).any((s) => s.nombre.toLowerCase().contains(q));
    }).toList();
  }

  Future<void> _formularioProfesional([Profesional? p]) async {
    if (_especialidades.isEmpty) {
      mostrarMensaje(context, 'Primero debe existir al menos una especialidad.',
          error: true);
      return;
    }
    final ok = await abrirFormulario<bool>(context,
        ProfesionalFormSheet(profesional: p, especialidades: _especialidades));
    if (ok == true && mounted) {
      mostrarMensaje(context,
          p == null ? 'Profesional registrado' : 'Ficha de ${p.nombreCompleto} actualizada');
      _cargar();
    }
  }

  Future<void> _cambiarEstado(Profesional p, bool activo) async {
    if (!activo) {
      final pendientes = _citasDe(p).where((c) => c.vigente).length;
      final seguir = await confirmar(context,
          titulo: 'Poner en pausa',
          mensaje: '${p.nombreCompleto} quedará en la pestaña "En pausa" y no '
              'recibirá nuevas reservas hasta que lo reactives.'
              '${pendientes > 0 ? '\n\nOjo: tiene $pendientes reserva(s) pendiente(s) hoy.' : ''}',
          textoAceptar: 'Pausar',
          peligroso: true);
      if (!seguir || !mounted) return;
    }
    setState(() => _procesando.add(p.id));
    try {
      await _api.actualizarProfesional(p.copyWith(estado: activo));
      if (!mounted) return;
      mostrarMensaje(context,
          activo ? '${p.nombres} está en turno' : '${p.nombres} quedó en pausa');
      setState(() {
        if (!activo) _filtro = FiltroEquipo.pausa;
        if (activo) _filtro = FiltroEquipo.activos;
        _expandido = p.id;
      });
      await _cargar();
    } on ApiException catch (e) {
      if (mounted) mostrarMensaje(context, e.mensaje, error: true);
    } finally {
      if (mounted) setState(() => _procesando.remove(p.id));
    }
  }

  Future<void> _eliminar(Profesional p) async {
    if (_citasDe(p).isNotEmpty) {
      mostrarMensaje(context,
          'No se puede eliminar: ${p.nombres} tiene reservas hoy. Ponlo en pausa.',
          error: true);
      return;
    }
    final ok = await confirmar(context,
        titulo: 'Eliminar profesional',
        mensaje: '¿Seguro que deseas eliminar a ${p.nombreCompleto}? Esta acción no se puede deshacer.',
        textoAceptar: 'Eliminar',
        peligroso: true);
    if (!ok || !mounted) return;
    setState(() => _procesando.add(p.id));
    try {
      await _api.eliminarProfesional(p.id);
      if (!mounted) return;
      mostrarMensaje(context, '${p.nombreCompleto} fue eliminado');
      await _cargar();
    } on ApiException catch (e) {
      if (mounted) mostrarMensaje(context, e.mensaje, error: true);
    } finally {
      if (mounted) setState(() => _procesando.remove(p.id));
    }
  }

  Future<void> _configurarHorario(Profesional p) async {
    final ok = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => ConfigurarJornadaScreen(profesional: p)));
    if (ok == true) _cargar();
  }

  Future<void> _abrirFicha(Profesional p) async {
    await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => ProfesionalFichaScreen(profesional: p)));
    _cargar();
  }

  void _verAgenda(Profesional p) {
    final citas = _citasDe(p);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.fondo,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        maxChildSize: 0.9,
        builder: (_, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            Text('Agenda de hoy · ${p.nombreCompleto}',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            Text(Formatos.fechaLarga(DateTime.now()),
                style: const TextStyle(color: AppColors.textoSecundario)),
            const SizedBox(height: 14),
            if (citas.isEmpty)
              const TarjetaKallos(
                child: Text('No tiene reservas para hoy.',
                    style: TextStyle(color: AppColors.textoSecundario)),
              )
            else
              for (final c in citas) ...[
                TarjetaKallos(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Text('${c.horaInicio}\n${c.horaFin}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.cliente,
                                style: const TextStyle(fontWeight: FontWeight.w600)),
                            Text(c.servicio,
                                style: const TextStyle(
                                    fontSize: 12, color: AppColors.textoSecundario)),
                          ],
                        ),
                      ),
                      EtiquetaEstadoCita(c.estado),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
          ],
        ),
      ),
    );
  }

  void _filtrarEspecialidad() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('Filtrar por especialidad',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            for (final e in [null, ..._especialidades])
              ListTile(
                title: Text(e?.nombre ?? 'Todas'),
                trailing: _especialidadFiltro == e?.id
                    ? const Icon(Icons.check, color: AppColors.primario)
                    : null,
                onTap: () {
                  setState(() => _especialidadFiltro = e?.id);
                  Navigator.pop(ctx);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: widget.onVolver == null
            ? null
            : IconButton(icon: const Icon(Icons.arrow_back), onPressed: widget.onVolver),
        titleSpacing: widget.onVolver == null ? null : 0,
        title: const Text('Equipo de Profesionales',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _cargar,
            icon: const Icon(Icons.refresh),
          ),
        ],
        bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1), child: Divider()),
      ),
      body: _cuerpo(),
    );
  }

  Widget _cuerpo() {
    if (_cargando) return const Center(child: CircularProgressIndicator());
    if (_error != null && _profesionales.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off_outlined, size: 48, color: AppColors.textoTenue),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            SizedBox(
                width: 180,
                child: ElevatedButton(onPressed: _cargar, child: const Text('Reintentar'))),
          ]),
        ),
      );
    }

    final activos = _profesionales.where((p) => p.estado).length;
    final pausa = _profesionales.length - activos;
    final visibles = _visibles;

    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          TextField(
            controller: _busqueda,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Buscar especialista o servicio...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _busqueda.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => setState(_busqueda.clear),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _formularioProfesional(),
                  icon: const Icon(Icons.person_add_alt_1_outlined, size: 20),
                  label: const Text('Añadir Profesional'),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 50,
                height: 50,
                child: OutlinedButton(
                  onPressed: _filtrarEspecialidad,
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    backgroundColor: _especialidadFiltro == null
                        ? AppColors.superficie
                        : AppColors.primarioSuave,
                  ),
                  child: const Icon(Icons.tune, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            children: [
              _chipFiltro(FiltroEquipo.activos, 'Activos ($activos)'),
              _chipFiltro(FiltroEquipo.pausa, 'En pausa ($pausa)'),
              _chipFiltro(FiltroEquipo.todos, 'Todos (${_profesionales.length})'),
            ],
          ),
          const SizedBox(height: 14),
          if (visibles.isEmpty)
            const TarjetaKallos(
              padding: EdgeInsets.symmetric(vertical: 28, horizontal: 16),
              child: Column(children: [
                Icon(Icons.person_search_outlined, size: 32, color: AppColors.textoTenue),
                SizedBox(height: 8),
                Text('No hay profesionales con esos filtros.',
                    style: TextStyle(color: AppColors.textoSecundario)),
              ]),
            )
          else
            for (final p in visibles) ...[
              p.id == _expandido ? _tarjetaExpandida(p) : _tarjetaCompacta(p),
              const SizedBox(height: 12),
            ],
          _tarjetaCapacidad(activos),
        ],
      ),
    );
  }

  Widget _chipFiltro(FiltroEquipo f, String texto) {
    final sel = _filtro == f;
    return ChoiceChip(
      label: Text(texto),
      selected: sel,
      showCheckmark: false,
      selectedColor: AppColors.primario,
      backgroundColor: AppColors.superficie,
      side: BorderSide(color: sel ? AppColors.primario : AppColors.borde),
      shape: const StadiumBorder(),
      labelStyle: TextStyle(
          color: sel ? Colors.white : AppColors.texto,
          fontWeight: FontWeight.w600,
          fontSize: 13),
      onSelected: (_) => setState(() => _filtro = f),
    );
  }

  Widget _estadoTexto(Profesional p) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
                color: p.estado ? AppColors.exito : AppColors.error,
                shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(p.estado ? 'Activo' : 'En pausa',
              style: TextStyle(
                  fontSize: 11,
                  color: p.estado ? AppColors.exito : AppColors.error,
                  fontWeight: FontWeight.w500)),
        ],
      );

  String _textoHorario(HorarioLaboral? h) =>
      h == null ? 'Sin horario hoy' : '${h.horaInicio} - ${h.horaFin}';

  Widget _tarjetaCompacta(Profesional p) {
    final citas = _citasDe(p).length;
    final procesando = _procesando.contains(p.id);
    return Opacity(
      opacity: p.estado ? 1 : 0.75,
      child: TarjetaKallos(
        onTap: () => _abrirFicha(p),
        padding: const EdgeInsets.fromLTRB(14, 14, 6, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AvatarIniciales(p.nombreCompleto,
                    radio: 22,
                    fondo: p.estado ? AppColors.primarioSuave : const Color(0xFFE8EAFB),
                    color: p.estado ? AppColors.primario : AppColors.avatarTexto),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(p.nombreCompleto,
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w700)),
                          p.estado
                              ? _estadoTexto(p)
                              : const Etiqueta(
                                  texto: 'En pausa',
                                  fondo: AppColors.errorSuave,
                                  color: AppColors.error),
                        ],
                      ),
                      Text(_nombreEspecialidad(p),
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textoSecundario)),
                      const SizedBox(height: 6),
                      if (p.estado)
                        Wrap(
                          spacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Etiqueta(
                                texto: citas == 1 ? '1 cita hoy' : '$citas citas hoy',
                                fondo: const Color(0xFFEEF0FA),
                                color: AppColors.texto),
                            Text('• ${_textoHorario(_horarioHoy(p))}',
                                style: const TextStyle(
                                    fontSize: 12, color: AppColors.textoSecundario)),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 6),
            Row(
              children: [
                if (p.estado)
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _expandido = p.id),
                    icon: const Icon(Icons.schedule, size: 18),
                    label: const Text('Acceso a horario'),
                  )
                else ...[
                  const Text('SIN CITAS ASIGNADAS',
                      style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 0.5,
                          color: AppColors.textoSecundario,
                          fontWeight: FontWeight.w600)),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: procesando ? null : () => _cambiarEstado(p, true),
                    icon: procesando
                        ? const CargandoBoton(color: AppColors.primario)
                        : const Icon(Icons.restart_alt, size: 18),
                    label: const Text('Reactivar'),
                  ),
                ],
                if (p.estado) const Spacer(),
                _menu(p),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _menu(Profesional p) => PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert, color: AppColors.textoSecundario),
        onSelected: (v) {
          switch (v) {
            case 'ficha':
              _abrirFicha(p);
            case 'editar':
              _formularioProfesional(p);
            case 'horario':
              _configurarHorario(p);
            case 'agenda':
              _verAgenda(p);
            case 'eliminar':
              _eliminar(p);
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'ficha', child: Text('Ver ficha')),
          PopupMenuItem(value: 'editar', child: Text('Editar ficha')),
          PopupMenuItem(value: 'horario', child: Text('Configurar jornada')),
          PopupMenuItem(value: 'agenda', child: Text('Ver agenda de hoy')),
          PopupMenuItem(
              value: 'eliminar',
              child: Text('Eliminar', style: TextStyle(color: AppColors.error))),
        ],
      );

  Widget _tarjetaExpandida(Profesional p) {
    final citas = _citasDe(p);
    final horario = _horarioHoy(p);
    final servicios = _serviciosDe(p);
    final ahora = Formatos.hhmm(DateTime.now());
    Cita? proxima;
    for (final c in citas) {
      if (c.horaInicio.compareTo(ahora) >= 0) {
        proxima = c;
        break;
      }
    }
    final procesando = _procesando.contains(p.id);
    final hoy = DateTime.now();
    const dias = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.superficie,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borde),
        boxShadow: const [
          BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0, 4))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                  width: 5,
                  color: p.estado ? AppColors.primario : AppColors.textoTenue),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 12, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AvatarIniciales(p.nombreCompleto, radio: 26),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p.nombreCompleto,
                                    style: const TextStyle(
                                        fontSize: 19, fontWeight: FontWeight.w600)),
                                Text(
                                    'Comisión ${p.porcentaje.toStringAsFixed(0)}% • CC ${p.documento}',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textoSecundario)),
                              ],
                            ),
                          ),
                          Etiqueta(
                            texto: _nombreEspecialidad(p),
                            fondo: const Color(0xFFBDEBCB),
                            color: const Color(0xFF14532D),
                            punto: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF6F7FB),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.borde),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            procesando
                                ? const Padding(
                                    padding: EdgeInsets.all(14),
                                    child: CargandoBoton(color: AppColors.primario))
                                : Switch(
                                    value: p.estado,
                                    onChanged: (v) => _cambiarEstado(p, v),
                                  ),
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Text(p.estado ? 'En turno hoy' : 'En pausa',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: p.estado
                                          ? AppColors.primario
                                          : AppColors.textoSecundario)),
                            ),
                          ],
                        ),
                      ),
                      if (servicios.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final s in servicios.take(4))
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEEF0FA),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppColors.borde),
                                ),
                                child: Text(s.nombre,
                                    style: const TextStyle(fontSize: 12)),
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),
                      const Divider(),
                      const SizedBox(height: 10),
                      _dato(
                        Icons.schedule,
                        'HORARIO VIGENTE',
                        horario == null
                            ? '${dias[hoy.weekday - 1]}: sin horario registrado'
                            : '${dias[hoy.weekday - 1]}: ${horario.horaInicio} - ${horario.horaFin}',
                        horario != null && horario.tieneAlmuerzo
                            ? 'Almuerzo programado: ${horario.inicioAlmuerzo} - ${horario.finAlmuerzo}'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      _dato(
                        Icons.check_circle_outline,
                        'ACTIVIDAD DIARIA',
                        citas.length == 1 ? '1 cita hoy' : '${citas.length} citas hoy',
                        proxima == null
                            ? (citas.isEmpty ? 'Sin reservas para hoy' : 'Sin más servicios hoy')
                            : 'Próximo servicio: ${proxima.horaInicio} (${proxima.servicio})',
                        colorDetalle: AppColors.primario,
                      ),
                      const SizedBox(height: 12),
                      const Divider(),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _configurarHorario(p),
                              icon: const Icon(Icons.edit_calendar_outlined, size: 18),
                              label: const FittedBox(child: Text('Configurar horario')),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _formularioProfesional(p),
                              icon: const Icon(Icons.badge_outlined, size: 18),
                              label: const FittedBox(child: Text('Editar ficha')),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          IconButton(
                            tooltip: 'Eliminar',
                            onPressed: procesando ? null : () => _eliminar(p),
                            icon: const Icon(Icons.delete_outline, color: AppColors.error),
                          ),
                          const Spacer(),
                          ElevatedButton.icon(
                            onPressed: () => _abrirFicha(p),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(0, 40),
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                            ),
                            icon: const Icon(Icons.person_outline, size: 18),
                            label: const Text('Ver ficha'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dato(IconData icono, String titulo, String valor, String? detalle,
      {Color colorDetalle = AppColors.textoSecundario}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icono, size: 18, color: AppColors.textoSecundario),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo,
                  style: const TextStyle(
                      fontSize: 10,
                      letterSpacing: 0.6,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textoSecundario)),
              const SizedBox(height: 2),
              Text(valor,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              if (detalle != null)
                Text(detalle, style: TextStyle(fontSize: 12, color: colorDetalle)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tarjetaCapacidad(int activos) {
    final franjas = activos * ApiConfig.turnosPorProfesional;
    final cubiertas = _citasHoy.length;
    final porcentaje = franjas == 0 ? 0 : ((cubiertas / franjas) * 100).round().clamp(0, 100);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF0FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borde),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: AppColors.primarioSuave,
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.fact_check_outlined, color: AppColors.primario),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Capacidad del Salón Hoy: $porcentaje%',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text('$cubiertas de $franjas franjas cubiertas por $activos especialistas activos.',
                    style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
