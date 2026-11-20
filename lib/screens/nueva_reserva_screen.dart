import 'package:flutter/material.dart';

import '../models/catalogos.dart';
import '../models/cita.dart';
import '../services/api_client.dart';
import '../services/catalogo_service.dart';
import '../services/disponibilidad.dart';
import '../theme/app_colors.dart';
import '../utils/formatos.dart';
import '../widgets/comunes.dart';
import '../widgets/formularios.dart';

class NuevaReservaScreen extends StatefulWidget {
  final DateTime? fechaInicial;

  final Cliente? clienteInicial;
  const NuevaReservaScreen({super.key, this.fechaInicial, this.clienteInicial});

  @override
  State<NuevaReservaScreen> createState() => _NuevaReservaScreenState();
}

class _NuevaReservaScreenState extends State<NuevaReservaScreen> {
  final _api = CatalogoService.instance;

  bool _cargando = true;
  String? _error;
  List<Cliente> _clientes = [];
  List<Especialidad> _especialidades = [];
  List<Servicio> _servicios = [];
  List<Profesional> _profesionales = [];
  List<HorarioLaboral> _horarios = [];
  List<Cita> _reservas = [];

  final _busqueda = TextEditingController();
  final _notas = TextEditingController();
  Cliente? _cliente;
  int? _especialidadId;
  Servicio? _servicio;
  int? _profesionalId;
  late final List<DateTime> _dias;
  late DateTime _dia;
  String? _hora;

  int _consulta = 0;
  bool _cargandoHoras = false;
  List<String> _horas = [];
  final Map<int, List<String>> _horasPorProfesional = {};
  final Map<String, int?> _libresPorDia = {};
  bool _guardando = false;
  bool _buscandoDocumento = false;

  @override
  void initState() {
    super.initState();
    final hoy = DateTime.now();
    _dias = [
      for (var i = 0; i < 14; i++) DateTime(hoy.year, hoy.month, hoy.day + i)
    ];
    _dia = _dias.first;
    final f = widget.fechaInicial;
    if (f != null) {
      for (final d in _dias) {
        if (d.year == f.year && d.month == f.month && d.day == f.day) _dia = d;
      }
    }
    _cargar();
  }

  @override
  void dispose() {
    _busqueda.dispose();
    _notas.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final r = await Future.wait([
        _api.clientes(),
        _api.especialidades(),
        _api.servicios(),
        _api.profesionales(),
        _api.horariosLaborales().catchError((_) => <HorarioLaboral>[]),
        _api.reservas(),
      ]);
      if (!mounted) return;
      setState(() {
        _clientes = r[0] as List<Cliente>;
        _especialidades = r[1] as List<Especialidad>;
        _servicios = (r[2] as List<Servicio>).where((s) => s.activo).toList();
        _profesionales =
            (r[3] as List<Profesional>).where((p) => p.estado).toList();
        _horarios = r[4] as List<HorarioLaboral>;
        _reservas = r[5] as List<Cita>;
        final conServicios = _especialidadesConServicios;
        if (conServicios.isNotEmpty) _especialidadId = conServicios.first.id;
        final ini = widget.clienteInicial;
        if (ini != null && _cliente == null) {
          _cliente = _clientes.firstWhere((c) => c.id == ini.id, orElse: () => ini);
          _busqueda.text = _cliente!.nombreCompleto;
        }
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo cargar la información.');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  List<Especialidad> get _especialidadesConServicios => _especialidades
      .where((e) => e.activa && _servicios.any((s) => s.especialidadId == e.id))
      .toList();

  List<Servicio> get _serviciosDeEspecialidad =>
      _servicios.where((s) => s.especialidadId == _especialidadId).toList();

  List<Profesional> get _profesionalesDelServicio => _servicio == null
      ? []
      : _profesionales
          .where((p) => p.especialidadId == _servicio!.especialidadId)
          .toList();

  int _visitas(Cliente c) => _reservas
      .where((r) => r.clienteId == c.id && r.estado != EstadoCita.cancelada)
      .length;

  int get _pasosCompletos => [
        _cliente != null,
        _servicio != null,
        _servicio != null,
        _hora != null,
      ].where((x) => x).length;

  bool get _hayCambios =>
      _cliente != null || _servicio != null || _notas.text.trim().isNotEmpty;

  Profesional? get _profesional {
    for (final p in _profesionales) {
      if (p.id == _profesionalId) return p;
    }
    return null;
  }

  Future<List<String>> _horasDe(int? profesionalId, DateTime dia) async {
    final s = _servicio!;
    final api = await _api.horasDisponibles(
        fecha: dia, servicioId: s.id, profesionalId: profesionalId);
    if (api != null) return Disponibilidad.quitarPasadas(api, dia);
    return profesionalId == null
        ? Disponibilidad.deCualquiera(
            profesionales: _profesionalesDelServicio.map((p) => p.id).toList(),
            dia: dia,
            duracion: s.duracion,
            horarios: _horarios,
            reservas: _reservas)
        : Disponibilidad.deProfesional(
            profesionalId: profesionalId,
            dia: dia,
            duracion: s.duracion,
            horarios: _horarios,
            reservas: _reservas);
  }

  Future<void> _actualizarDisponibilidad({bool soloDia = false}) async {
    if (_servicio == null) return;
    final consulta = ++_consulta;
    setState(() {
      _cargandoHoras = true;
      if (!soloDia) _libresPorDia.clear();
    });
    try {
      final dia = _dia;
      final profesionales = _profesionalesDelServicio;
      final resultados = await Future.wait([
        _horasDe(_profesionalId, dia),
        for (final p in profesionales) _horasDe(p.id, dia),
      ]);
      if (!mounted || consulta != _consulta) return;
      setState(() {
        _horas = resultados.first;
        _horasPorProfesional
          ..clear()
          ..addAll({
            for (var i = 0; i < profesionales.length; i++)
              profesionales[i].id: resultados[i + 1],
          });
        _libresPorDia[Formatos.fechaApi(dia)] = _horas.length;
        if (_hora != null && !_horas.contains(_hora)) _hora = null;
        _cargandoHoras = false;
      });
      if (!soloDia) _contarLibresPorDia(consulta);
    } on ApiException catch (e) {
      if (!mounted || consulta != _consulta) return;
      setState(() => _cargandoHoras = false);
      mostrarMensaje(context, e.mensaje, error: true);
    }
  }

  Future<void> _contarLibresPorDia(int consulta) async {
    for (final d in _dias.take(7)) {
      final clave = Formatos.fechaApi(d);
      if (_libresPorDia.containsKey(clave)) continue;
      try {
        final horas = await _horasDe(_profesionalId, d);
        if (!mounted || consulta != _consulta) return;
        setState(() => _libresPorDia[clave] = horas.length);
      } on ApiException {
        return;
      }
    }
  }

  void _seleccionarServicio(Servicio s) {
    setState(() {
      _servicio = s;
      _profesionalId = null;
      _hora = null;
    });
    _actualizarDisponibilidad();
  }

  void _seleccionarProfesional(int? id) {
    if (_profesionalId == id) return;
    setState(() {
      _profesionalId = id;
      _hora = null;
    });
    _actualizarDisponibilidad();
  }

  void _seleccionarDia(DateTime d) {
    setState(() {
      _dia = d;
      _hora = null;
    });
    _actualizarDisponibilidad(soloDia: true);
  }

  Future<void> _crearCliente() async {
    final doc = RegExp(r'^\d+$').hasMatch(_busqueda.text.trim())
        ? _busqueda.text.trim()
        : '';
    final nuevo = await abrirFormulario<Cliente>(
        context, ClienteFormSheet(documentoInicial: doc));
    if (nuevo == null || !mounted) return;
    setState(() {
      _clientes = [nuevo, ..._clientes.where((c) => c.id != nuevo.id)];
      _cliente = nuevo;
      _busqueda.text = nuevo.nombreCompleto;
    });
    mostrarMensaje(context, 'Cliente ${nuevo.nombreCompleto} registrado');
  }

  Future<void> _buscarDocumentoEnApi() async {
    final doc = _busqueda.text.trim();
    setState(() => _buscandoDocumento = true);
    try {
      final c = await _api.buscarClientePorDocumento(doc);
      if (!mounted) return;
      if (c == null) {
        mostrarMensaje(context, 'No existe un cliente con el documento $doc');
      } else {
        setState(() {
          _clientes = [c, ..._clientes.where((x) => x.id != c.id)];
          _cliente = c;
          _busqueda.text = c.nombreCompleto;
        });
      }
    } on ApiException catch (e) {
      if (mounted) mostrarMensaje(context, e.mensaje, error: true);
    } finally {
      if (mounted) setState(() => _buscandoDocumento = false);
    }
  }

  Future<void> _confirmar() async {
    final faltan = [
      if (_cliente == null) 'cliente',
      if (_servicio == null) 'servicio',
      if (_hora == null) 'horario',
    ];
    if (faltan.isNotEmpty) {
      mostrarMensaje(context, 'Falta seleccionar: ${faltan.join(', ')}',
          error: true);
      return;
    }
    final partes = _hora!.split(':');
    final fechaHora = DateTime(_dia.year, _dia.month, _dia.day,
        int.parse(partes[0]), int.parse(partes[1]));
    if (fechaHora.isBefore(DateTime.now())) {
      mostrarMensaje(context, 'Esa hora ya pasó. Elige otro horario.',
          error: true);
      return;
    }

    final ok = await confirmar(
      context,
      titulo: 'Confirmar reserva',
      mensaje: '${_cliente!.nombreCompleto}\n'
          '${_servicio!.nombre} · ${Formatos.moneda(_servicio!.precio)}\n'
          '${Formatos.fechaLarga(_dia)} a las $_hora\n'
          'Profesional: ${_profesional?.nombreCompleto ?? 'Asignación automática'}',
      textoAceptar: 'Reservar',
    );
    if (!ok || !mounted) return;

    setState(() => _guardando = true);
    try {
      await _api.crearReserva(
        fechaHora: fechaHora,
        servicioId: _servicio!.id,
        clienteId: _cliente!.id,
        profesionalId: _profesionalId,
        notas: _notas.text,
      );
      if (!mounted) return;
      mostrarMensaje(context, 'Reserva creada para ${_cliente!.nombreCompleto}');
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) mostrarMensaje(context, e.mensaje, error: true);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _cerrar() async {
    if (!_hayCambios) {
      Navigator.pop(context);
      return;
    }
    final salir = await confirmar(context,
        titulo: 'Descartar reserva',
        mensaje: 'Se perderán los datos que llenaste. ¿Deseas salir?',
        textoAceptar: 'Descartar',
        peligroso: true);
    if (salir && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hayCambios,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cerrar();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
              icon: const Icon(Icons.close), onPressed: _cerrar),
          titleSpacing: 0,
          title: const Text('Nueva Reserva',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          actions: const [
            Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: Text('Borrador',
                    style: TextStyle(
                        fontSize: 13, color: AppColors.textoSecundario)),
              ),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: LinearProgressIndicator(
              value: _pasosCompletos / 4,
              minHeight: 4,
              backgroundColor: AppColors.borde,
              color: AppColors.primario,
            ),
          ),
        ),
        body: _cuerpo(),
        bottomNavigationBar: _cargando || _error != null ? null : _barraConfirmar(),
      ),
    );
  }

  Widget _cuerpo() {
    if (_cargando) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off_outlined,
                size: 48, color: AppColors.textoTenue),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            SizedBox(
              width: 180,
              child: ElevatedButton(
                  onPressed: _cargar, child: const Text('Reintentar')),
            ),
          ]),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _seccionCliente(),
        const SizedBox(height: 14),
        _seccionServicio(),
        const SizedBox(height: 14),
        _seccionProfesional(),
        const SizedBox(height: 14),
        _seccionFecha(),
        const SizedBox(height: 14),
        _seccionNotas(),
      ],
    );
  }

  Widget _seccionCliente() {
    final q = _busqueda.text.trim().toLowerCase();
    final resultados = _cliente != null || q.length < 2
        ? <Cliente>[]
        : _clientes
            .where((c) =>
                c.nombreCompleto.toLowerCase().contains(q) ||
                c.documento.contains(q) ||
                c.celular.contains(q))
            .take(5)
            .toList();
    final esDocumento = RegExp(r'^\d{6,12}$').hasMatch(q);

    return TarjetaKallos(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EncabezadoSeccion(
            icono: Icons.person_outline,
            titulo: 'Cliente',
            trailing: TextButton.icon(
              onPressed: _crearCliente,
              style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Crear nuevo cliente',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _busqueda,
            readOnly: _cliente != null,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Buscar por nombre, documento o celular',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _busqueda.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.cancel_outlined, size: 20),
                      onPressed: () => setState(() {
                        _busqueda.clear();
                        _cliente = null;
                      }),
                    ),
            ),
          ),
          if (_cliente != null) ...[
            const SizedBox(height: 10),
            _clienteSeleccionado(_cliente!),
          ] else if (q.length >= 2) ...[
            const SizedBox(height: 6),
            for (final c in resultados)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                leading: AvatarIniciales(c.nombreCompleto, radio: 18),
                title: Text(c.nombreCompleto,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('CC ${c.documento} • ${c.celular}'),
                onTap: () => setState(() {
                  _cliente = c;
                  _busqueda.text = c.nombreCompleto;
                  FocusScope.of(context).unfocus();
                }),
              ),
            if (resultados.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: esDocumento
                    ? OutlinedButton.icon(
                        onPressed:
                            _buscandoDocumento ? null : _buscarDocumentoEnApi,
                        icon: _buscandoDocumento
                            ? const CargandoBoton(color: AppColors.primario)
                            : const Icon(Icons.manage_search, size: 18),
                        label: Text('Buscar documento $q'),
                      )
                    : const Text(
                        'No se encontraron clientes. Puedes crear uno nuevo.',
                        style: TextStyle(color: AppColors.textoSecundario)),
              ),
          ],
        ],
      ),
    );
  }

  Widget _clienteSeleccionado(Cliente c) {
    final visitas = _visitas(c);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F7FB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borde),
      ),
      child: Row(
        children: [
          AvatarIniciales(c.nombreCompleto,
              radio: 18,
              fondo: const Color(0xFFBDEBCB),
              color: const Color(0xFF14532D)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(c.nombreCompleto,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    Etiqueta(
                      texto: visitas >= 3 ? 'HABITUAL' : (visitas == 0 ? 'NUEVO' : 'FRECUENTE'),
                      fondo: visitas >= 3 ? AppColors.exitoSuave : AppColors.infoSuave,
                      color: visitas >= 3 ? AppColors.exito : AppColors.info,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                    '${c.celular.isEmpty ? 'CC ${c.documento}' : c.celular} • '
                    '${visitas == 1 ? '1 visita anterior' : '$visitas visitas anteriores'}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textoSecundario)),
              ],
            ),
          ),
          const Icon(Icons.check_circle_outline, color: AppColors.primario),
        ],
      ),
    );
  }

  Widget _seccionServicio() {
    final especialidades = _especialidadesConServicios;
    final servicios = _serviciosDeEspecialidad;
    return TarjetaKallos(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EncabezadoSeccion(
            icono: Icons.content_cut,
            titulo: 'Especialidad & Servicio',
            trailing: TextoAyuda(servicios.length == 1
                ? '1 servicio activo'
                : '${servicios.length} servicios activos'),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: especialidades.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final e = especialidades[i];
                final sel = e.id == _especialidadId;
                return ChoiceChip(
                  label: Text(e.nombre),
                  selected: sel,
                  showCheckmark: false,
                  selectedColor: AppColors.primario,
                  backgroundColor: const Color(0xFFF1F2F8),
                  side: BorderSide.none,
                  shape: const StadiumBorder(),
                  labelStyle: TextStyle(
                      color: sel ? Colors.white : AppColors.texto,
                      fontWeight: sel ? FontWeight.w600 : FontWeight.w500,
                      fontSize: 13),
                  onSelected: (_) => setState(() => _especialidadId = e.id),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          if (servicios.isEmpty)
            const Text('No hay servicios activos en esta especialidad.',
                style: TextStyle(color: AppColors.textoSecundario))
          else
            for (final s in servicios) ...[
              _tarjetaServicio(s),
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }

  Widget _tarjetaServicio(Servicio s) {
    final sel = _servicio?.id == s.id;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _seleccionarServicio(s),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: sel ? const Color(0xFFF6F7FB) : AppColors.superficie,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: sel ? AppColors.primario : AppColors.borde,
              width: sel ? 1.5 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(s.nombre,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                ),
                Icon(sel ? Icons.check_circle : Icons.radio_button_unchecked,
                    size: 20,
                    color: sel ? AppColors.primario : AppColors.textoTenue),
              ],
            ),
            if (s.descripcion.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(s.descripcion,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textoSecundario)),
            ],
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.schedule,
                    size: 15, color: AppColors.textoSecundario),
                const SizedBox(width: 4),
                Text('${s.duracion} min',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textoSecundario)),
                const SizedBox(width: 12),
                Text(Formatos.moneda(s.precio),
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primario)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _seccionProfesional() {
    String? especialidad;
    for (final e in _especialidades) {
      if (e.id == _servicio?.especialidadId) especialidad = e.nombre;
    }
    final profesionales = _profesionalesDelServicio;
    return TarjetaKallos(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EncabezadoSeccion(
            icono: Icons.badge_outlined,
            titulo: 'Profesional Asignado',
            trailing: especialidad == null
                ? null
                : TextoAyuda('Especialista en $especialidad'),
          ),
          const SizedBox(height: 12),
          if (_servicio == null)
            const Text('Selecciona un servicio para ver los especialistas.',
                style: TextStyle(color: AppColors.textoSecundario))
          else
            LayoutBuilder(builder: (context, c) {
              final ancho = (c.maxWidth - 10) / 2;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SizedBox(
                    width: ancho,
                    child: _tarjetaProfesional(
                      nombre: 'Cualquiera',
                      detalle: 'Automático',
                      seleccionado: _profesionalId == null,
                      disponible: true,
                      icono: Icons.groups_2_outlined,
                      onTap: () => _seleccionarProfesional(null),
                    ),
                  ),
                  for (final p in profesionales)
                    SizedBox(width: ancho, child: _profesionalCard(p)),
                ],
              );
            }),
          if (_servicio != null && profesionales.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('No hay especialistas activos para este servicio.',
                  style: TextStyle(color: AppColors.textoSecundario)),
            ),
        ],
      ),
    );
  }

  Widget _profesionalCard(Profesional p) {
    final horas = _horasPorProfesional[p.id];
    final sel = _profesionalId == p.id;
    final String detalle;
    final bool libre;
    if (_cargandoHoras && horas == null) {
      detalle = 'Consultando…';
      libre = true;
    } else if (horas == null || horas.isEmpty) {
      detalle = 'Sin cupo';
      libre = false;
    } else {
      detalle = sel ? 'Disponible' : 'Desde ${horas.first}';
      libre = true;
    }
    return _tarjetaProfesional(
      nombre: p.nombreCorto,
      detalle: detalle,
      seleccionado: sel,
      disponible: libre,
      iniciales: p.nombreCompleto,
      onTap: libre ? () => _seleccionarProfesional(p.id) : null,
    );
  }

  Widget _tarjetaProfesional({
    required String nombre,
    required String detalle,
    required bool seleccionado,
    required bool disponible,
    IconData? icono,
    String? iniciales,
    VoidCallback? onTap,
  }) {
    final colorDetalle = !disponible
        ? AppColors.error
        : seleccionado
            ? AppColors.primario
            : AppColors.textoSecundario;
    return Opacity(
      opacity: disponible ? 1 : 0.55,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              decoration: BoxDecoration(
                color: seleccionado ? const Color(0xFFF6F7FB) : AppColors.superficie,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: seleccionado ? AppColors.primario : AppColors.borde,
                    width: seleccionado ? 1.5 : 1),
              ),
              child: Column(
                children: [
                  if (icono != null)
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: const Color(0xFFE8EAFB),
                      child: Icon(icono, color: AppColors.texto),
                    )
                  else
                    AvatarIniciales(iniciales ?? nombre, radio: 24),
                  const SizedBox(height: 8),
                  Text(nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: seleccionado ? AppColors.primario : AppColors.texto)),
                  Text(detalle,
                      style: TextStyle(
                          fontSize: 11,
                          color: colorDetalle,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            if (seleccionado)
              const Positioned(
                top: -6,
                right: -6,
                child: CircleAvatar(
                  radius: 10,
                  backgroundColor: AppColors.primario,
                  child: Icon(Icons.check, size: 13, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _seccionFecha() {
    final conQuien = _profesional?.nombreCorto ?? 'cualquier especialista';
    return TarjetaKallos(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EncabezadoSeccion(
            icono: Icons.calendar_today_outlined,
            titulo: 'Fecha & Horario',
            trailing: Text(Formatos.mesAnio(_dia),
                style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.primario,
                    fontWeight: FontWeight.w500)),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 82,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _dias.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => _tarjetaDia(_dias[i], i),
            ),
          ),
          const SizedBox(height: 14),
          if (_servicio == null)
            const Text('Selecciona un servicio para ver los horarios.',
                style: TextStyle(color: AppColors.textoSecundario))
          else ...[
            Text('Horarios disponibles con $conQuien',
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textoSecundario)),
            const SizedBox(height: 10),
            if (_cargandoHoras)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_horas.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text('No hay horarios disponibles este día. Prueba otro día u otro especialista.',
                    style: TextStyle(color: AppColors.textoSecundario)),
              )
            else
              LayoutBuilder(builder: (context, c) {
                final ancho = (c.maxWidth - 16) / 3;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final h in _horas)
                      SizedBox(width: ancho, child: _chipHora(h)),
                  ],
                );
              }),
          ],
        ],
      ),
    );
  }

  Widget _tarjetaDia(DateTime d, int i) {
    final sel = d == _dia;
    final libres = _libresPorDia[Formatos.fechaApi(d)];
    final etiqueta = i == 0
        ? 'HOY'
        : i == 1
            ? 'MAÑANA'
            : Formatos.diaCorto(d).toUpperCase();
    final textoLibres = _servicio == null
        ? ''
        : libres == null
            ? '…'
            : libres == 0
                ? 'Sin cupo'
                : '$libres libres';
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _seleccionarDia(d),
      child: Container(
        width: 96,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: sel ? const Color(0xFFF6F7FB) : AppColors.superficie,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: sel ? AppColors.primario : AppColors.borde,
              width: sel ? 1.8 : 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(etiqueta,
                style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 0.5,
                    fontWeight: FontWeight.w600,
                    color: sel ? AppColors.primario : AppColors.textoSecundario)),
            const SizedBox(height: 2),
            Text('${Formatos.diaCorto(d)} ${d.day}',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: sel ? AppColors.primario : AppColors.texto)),
            const SizedBox(height: 2),
            Text(textoLibres,
                style: TextStyle(
                    fontSize: 11,
                    color: libres == 0 ? AppColors.error : AppColors.textoSecundario)),
          ],
        ),
      ),
    );
  }

  Widget _chipHora(String h) {
    final sel = h == _hora;
    return Material(
      color: sel ? AppColors.primario : AppColors.superficie,
      shape: StadiumBorder(
          side: BorderSide(color: sel ? AppColors.primario : AppColors.borde)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: () => setState(() => _hora = h),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Center(
            child: Text(h,
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: sel ? Colors.white : AppColors.texto)),
          ),
        ),
      ),
    );
  }

  Widget _seccionNotas() {
    return TarjetaKallos(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const EncabezadoSeccion(
            icono: Icons.sticky_note_2_outlined,
            titulo: 'Notas Internas de la Reserva',
            trailing: TextoAyuda('Solo visible para\nel equipo'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _notas,
            maxLines: 3,
            maxLength: 250,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Preferencias del cliente, alergias, observaciones…',
            ),
          ),
          const Row(
            children: [
              Icon(Icons.eco_outlined, size: 15, color: AppColors.textoSecundario),
              SizedBox(width: 6),
              Expanded(
                child: Text('Ayuda al especialista a preparar el servicio.',
                    style: TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _barraConfirmar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: const BoxDecoration(
          color: AppColors.superficie,
          border: Border(top: BorderSide(color: AppColors.borde)),
        ),
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Total',
                    style: TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
                Text(_servicio == null ? '—' : Formatos.moneda(_servicio!.precio),
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primario)),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _guardando ? null : _confirmar,
                icon: _guardando
                    ? const CargandoBoton()
                    : const Icon(Icons.event_available, size: 20),
                label: const Text('Confirmar reserva'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
