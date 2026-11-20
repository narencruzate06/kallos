import 'package:flutter/material.dart';

import '../models/cita.dart';
import '../models/dashboard_resumen.dart';
import '../models/usuario.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/citas_service.dart';
import '../services/dashboard_service.dart';
import '../theme/app_colors.dart';
import '../utils/formatos.dart';
import '../widgets/comunes.dart';
import '../widgets/home_widgets.dart';
import '../models/catalogos.dart';
import '../widgets/formularios.dart';
import '../services/catalogo_service.dart';
import '../widgets/reserva_sheets.dart';
import 'agenda_screen.dart';
import 'cliente_ficha_screen.dart';
import 'clientes_screen.dart';
import 'especialidades_screen.dart';
import 'cierres_screen.dart';
import 'equipo_screen.dart';
import 'login_screen.dart';
import 'nueva_reserva_screen.dart';
import 'proximamente_screen.dart';

enum FiltroCitas { todas, enCurso, proximas }

class HomeScreen extends StatefulWidget {
  final Usuario usuario;
  const HomeScreen({super.key, required this.usuario});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final Usuario _usuario;
  DashboardResumen? _resumen;
  List<Cita> _citas = [];
  bool _cargando = true;
  String? _error;
  FiltroCitas _filtro = FiltroCitas.todas;
  int _tab = 0;
  final Set<int> _procesando = {};
  Map<int, Cliente> _clientes = {};
  final _seccionCitasKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _usuario = widget.usuario;
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _error = null;
      if (_resumen == null) _cargando = true;
    });
    try {
      await CitasService.instance.cargarCatalogos();
      final citas = await CitasService.instance.citasDeHoy();
      citas.sort((a, b) => a.horaInicio.compareTo(b.horaInicio));
      final resumen = await DashboardService.instance.calcularResumen(citas);
      if (!mounted) return;
      setState(() {
        _citas = citas;
        _resumen = resumen;
      });
      CatalogoService.instance.clientes().then((lista) {
        if (mounted) setState(() => _clientes = {for (final c in lista) c.id: c});
      }).catchError((_) {});
    } on ApiException catch (e) {
      if (e.noAutorizado) return _sesionExpirada();
      if (mounted) setState(() => _error = e.mensaje);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No se pudo cargar la información.');
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _sesionExpirada() async {
    await AuthService.instance.cerrarSesion();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const LoginScreen(
            mensajeInicial: 'Tu sesión expiró. Inicia sesión nuevamente.'),
      ),
      (_) => false,
    );
  }

  Future<void> _cerrarSesion() async {
    final ok = await confirmar(context,
        titulo: 'Cerrar sesión',
        mensaje: '¿Deseas salir de Kallos?',
        textoAceptar: 'Salir',
        peligroso: true);
    if (!ok) return;
    await AuthService.instance.cerrarSesion();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  List<Cita> get _pendientes =>
      _citas.where((c) => c.estado == EstadoCita.pendiente).toList();

  int get _totalEnCurso =>
      _citas.where((c) => c.estado == EstadoCita.enCurso).length;

  int get _totalProximas => _citas
      .where((c) =>
          c.estado == EstadoCita.confirmada || c.estado == EstadoCita.pendiente)
      .length;

  List<Cita> get _citasVisibles {
    final activas =
        _citas.where((c) => c.estado != EstadoCita.cancelada).toList();
    return switch (_filtro) {
      FiltroCitas.todas => activas,
      FiltroCitas.enCurso =>
        activas.where((c) => c.estado == EstadoCita.enCurso).toList(),
      FiltroCitas.proximas => activas
          .where((c) =>
              c.estado == EstadoCita.confirmada ||
              c.estado == EstadoCita.pendiente)
          .toList(),
    };
  }

  Future<void> _accionMenu(Cita cita, AccionCitaMenu accion) async {
    switch (accion) {
      case AccionCitaMenu.reprogramar:
        final editado =
            await abrirFormulario<bool>(context, EditarReservaSheet(cita: cita));
        if (editado == true) _cargar();
      case AccionCitaMenu.cancelar:
        final cancelada =
            await abrirCancelarReserva(context, cita, cliente: _clientes[cita.clienteId]);
        if (cancelada == true) _cargar();
    }
  }

  void _revisarPendientes() {
    setState(() => _filtro = FiltroCitas.proximas);
    final ctx = _seccionCitasKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx,
          duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
    }
  }

  void _abrirModulo(String titulo, IconData icono) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ProximamenteScreen(titulo: titulo, icono: icono),
    ));
  }

  Future<void> _nuevaReserva() async {
    final creada = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const NuevaReservaScreen()));
    if (creada == true) _cargar();
  }

  void _irATab(int i) {
    setState(() => _tab = i);
    if (i == 0) _cargar();
  }

  Future<void> _detalleCita(Cita c) async {
    final cambio = await abrirDetalleReserva(context, c, cliente: _clientes[c.clienteId]);
    if (cambio == true) _cargar();
  }

  Future<void> _nuevoCliente() async {
    final c = await abrirFormulario<Cliente>(context, const ClienteFormSheet());
    if (c == null || !mounted) return;
    mostrarMensaje(context, 'Cliente ${c.nombreCompleto} registrado');
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => ClienteFichaScreen(cliente: c)));
    _cargar();
  }

  Future<void> _abrirClientes() async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const ClientesScreen()));
    _cargar();
  }

  void _accesoRapido(String titulo, IconData icono) {
    switch (titulo) {
      case 'Nueva cita':
        _nuevaReserva();
      case 'Añadir cliente':
        _nuevoCliente();
      case 'Ver agenda':
        _irATab(1);
      case 'Directorio Clientes':
        _abrirClientes();
      case 'Especialidades':
        Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const EspecialidadesScreen()))
            .then((_) => _cargar());
      case 'Cierre rápido':
        _irATab(4);
      default:
        _abrirModulo(titulo, icono);
    }
  }

  void _verNotificaciones() {
    final n = _pendientes.length;
    mostrarMensaje(
        context,
        n == 0
            ? 'No tienes notificaciones nuevas'
            : 'Tienes $n ${n == 1 ? 'cita pendiente' : 'citas pendientes'} por confirmar');
  }

  static const _tabs = [
    (Icons.home_outlined, Icons.home, 'Inicio'),
    (Icons.calendar_month_outlined, Icons.calendar_month, 'Agenda'),
    (Icons.add_circle_outline, Icons.add_circle, 'Reservar'),
    (Icons.groups_outlined, Icons.groups, 'Equipo'),
    (Icons.point_of_sale_outlined, Icons.point_of_sale, 'Cierres'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _tab != 0 ? null : AppBar(
        titleSpacing: 16,
        title: const Row(
          children: [
            KallosLogo(alto: 30),
            SizedBox(width: 8),
            Text('Kallos',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Notificaciones',
            onPressed: _verNotificaciones,
            icon: Badge(
              isLabelVisible: _pendientes.isNotEmpty,
              smallSize: 7,
              backgroundColor: AppColors.primario,
              child: const Icon(Icons.notifications_none),
            ),
          ),
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: _cerrarSesion,
            icon: const Icon(Icons.logout, size: 20),
          ),
          const SizedBox(width: 4),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(),
        ),
      ),
      body: switch (_tab) {
        1 => AgendaScreen(onVolver: () => _irATab(0)),
        3 => EquipoScreen(onVolver: () => _irATab(0)),
        4 => CierresScreen(onVolver: () => _irATab(0)),
        _ => _inicio(),
      },
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.borde))),
        child: BottomNavigationBar(
          currentIndex: _tab,
          onTap: (i) {
            if (i == 2) {
              _nuevaReserva();
            } else {
              _irATab(i);
            }
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppColors.superficie,
          elevation: 0,
          selectedItemColor: AppColors.primario,
          unselectedItemColor: AppColors.textoSecundario,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          items: [
            for (final t in _tabs)
              BottomNavigationBarItem(
                icon: Icon(t.$1),
                activeIcon: Icon(t.$2),
                label: t.$3,
              ),
          ],
        ),
      ),
    );
  }

  Widget _inicio() {
    if (_cargando && _resumen == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _resumen == null) {
      return _vistaError();
    }

    final r = _resumen!;
    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _saludo(),
          if (_error != null) ...[
            const SizedBox(height: 12),
            _bannerError(),
          ],
          if (_pendientes.isNotEmpty) ...[
            const SizedBox(height: 16),
            _alertaPendientes(),
          ],
          const SizedBox(height: 12),
          KpiCard(
            titulo: 'Reservas hoy',
            valor: '${r.reservasHoy}',
            detalle: '${r.ocupacionAgenda}% ocupación agenda',
            etiqueta: Etiqueta(
              texto:
                  '${r.variacionVsAyer >= 0 ? '+' : ''}${r.variacionVsAyer} vs ayer',
              icono: r.variacionVsAyer >= 0
                  ? Icons.trending_up
                  : Icons.trending_down,
              fondo: r.variacionVsAyer >= 0
                  ? AppColors.exitoSuave
                  : AppColors.errorSuave,
              color: r.variacionVsAyer >= 0 ? AppColors.exito : AppColors.error,
            ),
          ),
          const SizedBox(height: 12),
          KpiCard(
            titulo: 'Ingresos est.',
            valor: Formatos.moneda(r.ingresosEstimados),
            detalle:
                'Meta diaria: ${Formatos.moneda(r.metaDiaria)} (${r.metaAlcanzada ? 'Alcanzada' : 'En progreso'})',
            etiqueta: const Etiqueta(
              texto: 'Proyección',
              fondo: AppColors.exitoSuave,
              color: AppColors.exito,
            ),
          ),
          const SizedBox(height: 12),
          KpiCard(
            titulo: 'Equipo en turno',
            valor: '${r.equipoEnTurno}',
            valorSecundario: '/${r.equipoTotal}',
            detalle: r.especialistasLibres == 1
                ? '1 especialista libre ahora'
                : '${r.especialistasLibres} especialistas libres ahora',
            etiqueta: Etiqueta(
              texto: r.equipoEnTurno > 0 ? 'Activo' : 'Sin turno',
              fondo: r.equipoEnTurno > 0
                  ? AppColors.exitoSuave
                  : AppColors.neutroSuave,
              color: r.equipoEnTurno > 0 ? AppColors.exito : AppColors.neutro,
            ),
          ),
          const SizedBox(height: 20),
          const Text('ACCESOS OPERATIVOS RÁPIDOS',
              style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textoSecundario)),
          const SizedBox(height: 10),
          _accesosRapidos(),
          const SizedBox(height: 22),
          _seccionCitas(),
        ],
      ),
    );
  }

  Widget _saludo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.event_outlined,
                size: 14, color: AppColors.textoSecundario),
            const SizedBox(width: 6),
            Text(Formatos.fechaLarga(DateTime.now()),
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textoSecundario)),
          ],
        ),
        const SizedBox(height: 6),
        Text.rich(TextSpan(children: [
          TextSpan(
            text: 'Hola, ${Formatos.primerNombre(_usuario.nombreSaludo)}',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          TextSpan(
            text: ' (${_usuario.rolVisible})',
            style:
                const TextStyle(fontSize: 13, color: AppColors.textoSecundario),
          ),
        ])),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.superficie,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.borde),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.spa_outlined,
                  size: 14, color: AppColors.primario),
              const SizedBox(width: 6),
              Text('${_usuario.sede} • Activo',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _alertaPendientes() {
    final n = _pendientes.length;
    final desde = _pendientes.first.horaInicio;
    return TarjetaKallos(
      onTap: _revisarPendientes,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.primarioSuave,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.phone_in_talk_outlined,
                size: 20, color: AppColors.primario),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  n == 1
                      ? '1 cita requiere confirmación telefónica'
                      : '$n citas requieren confirmación telefónica',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text('Turnos previstos a partir de las $desde hrs',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textoSecundario)),
              ],
            ),
          ),
          const Text('Revisar',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primario)),
          const Icon(Icons.chevron_right, size: 18, color: AppColors.primario),
        ],
      ),
    );
  }

  Widget _accesosRapidos() {
    final accesos = [
      (Icons.add_circle_outline, 'Nueva cita', 'Agendar turno'),
      (Icons.calendar_month_outlined, 'Ver agenda', 'Parrilla completa'),
      (Icons.person_add_alt_1_outlined, 'Añadir cliente', 'Ficha nueva'),
      (Icons.point_of_sale_outlined, 'Cierre rápido', 'Caja y cobros'),
      (Icons.contacts_outlined, 'Directorio Clientes', 'Fichas e historial'),
      (Icons.spa_outlined, 'Especialidades', 'Servicios y tarifas'),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.5,
      children: [
        for (final a in accesos)
          AccesoRapidoTile(
            icono: a.$1,
            titulo: a.$2,
            subtitulo: a.$3,
            onTap: () => _accesoRapido(a.$2, a.$1),
          ),
      ],
    );
  }

  Widget _seccionCitas() {
    final visibles = _citasVisibles;
    return Column(
      key: _seccionCitasKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Próximas citas de hoy',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        const Text('Horarios sincronizados en tiempo real',
            style: TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
        const SizedBox(height: 10),
        _filtros(),
        const SizedBox(height: 12),
        if (visibles.isEmpty)
          _sinCitas()
        else
          for (final c in visibles) ...[
            CitaCard(
              cita: c,
              procesando: _procesando.contains(c.id),
              onMenu: (a) => _accionMenu(c, a),
              onTap: () => _detalleCita(c),
            ),
            const SizedBox(height: 10),
          ],
      ],
    );
  }

  Widget _filtros() {
    final opciones = [
      (FiltroCitas.todas, 'Todas'),
      (FiltroCitas.enCurso, 'En curso ($_totalEnCurso)'),
      (FiltroCitas.proximas, 'Próximas ($_totalProximas)'),
    ];
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.neutroSuave,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final o in opciones)
            GestureDetector(
              onTap: () => setState(() => _filtro = o.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _filtro == o.$1
                      ? AppColors.superficie
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: _filtro == o.$1
                      ? Border.all(color: AppColors.borde)
                      : null,
                ),
                child: Text(o.$2,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: _filtro == o.$1
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: _filtro == o.$1
                          ? AppColors.texto
                          : AppColors.textoSecundario,
                    )),
              ),
            ),
        ],
      ),
    );
  }

  Widget _sinCitas() {
    final texto = switch (_filtro) {
      FiltroCitas.todas => 'No hay citas programadas para hoy.',
      FiltroCitas.enCurso => 'No hay citas en curso en este momento.',
      FiltroCitas.proximas => 'No hay citas próximas por atender.',
    };
    return TarjetaKallos(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      child: Column(
        children: [
          const Icon(Icons.event_available_outlined,
              color: AppColors.textoTenue, size: 32),
          const SizedBox(height: 8),
          Text(texto,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textoSecundario)),
        ],
      ),
    );
  }

  Widget _bannerError() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.errorSuave,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 18, color: AppColors.error),
          const SizedBox(width: 8),
          Expanded(
              child: Text(_error!,
                  style:
                      const TextStyle(fontSize: 13, color: AppColors.error))),
          TextButton(onPressed: _cargar, child: const Text('Reintentar')),
        ],
      ),
    );
  }

  Widget _vistaError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined,
                size: 48, color: AppColors.textoTenue),
            const SizedBox(height: 12),
            Text(_error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textoSecundario)),
            const SizedBox(height: 16),
            SizedBox(
              width: 180,
              child: ElevatedButton.icon(
                onPressed: _cargar,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Reintentar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
