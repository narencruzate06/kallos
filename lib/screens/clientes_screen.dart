import 'package:flutter/material.dart';

import '../models/catalogos.dart';
import '../models/cita.dart';
import '../models/resumen_cliente.dart';
import '../services/api_client.dart';
import '../services/catalogo_service.dart';
import '../services/notas_cliente.dart';
import '../theme/app_colors.dart';
import '../widgets/comunes.dart';
import '../widgets/contacto.dart';
import '../widgets/formularios.dart';
import '../widgets/reserva_sheets.dart';
import 'cliente_ficha_screen.dart';
import 'nueva_reserva_screen.dart';

enum FiltroClientes { todos, habituales, nuevos, conCita, alertas, inactivos }

enum OrdenClientes { nombre, ultimaVisita, visitas }

class ClientesScreen extends StatefulWidget {
  const ClientesScreen({super.key});

  @override
  State<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends State<ClientesScreen> {
  final _api = CatalogoService.instance;
  final _busqueda = TextEditingController();

  bool _cargando = true;
  String? _error;
  List<ResumenCliente> _resumenes = [];
  List<Cita> _reservas = [];
  Map<int, NotaCliente> _notas = {};
  FiltroClientes _filtro = FiltroClientes.todos;
  OrdenClientes _orden = OrdenClientes.nombre;

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
      if (_resumenes.isEmpty) _cargando = true;
    });
    try {
      final r = await Future.wait([
        _api.clientes(),
        _api.reservas(),
        NotasClienteService.instance.todas(),
      ]);
      final clientes = r[0] as List<Cliente>;
      final reservas = r[1] as List<Cita>;
      if (!mounted) return;
      setState(() {
        _reservas = reservas;
        _notas = r[2] as Map<int, NotaCliente>;
        _resumenes = [for (final c in clientes) ResumenCliente.calcular(c, reservas)];
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo cargar el directorio.');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  bool _pasaFiltro(ResumenCliente r, [FiltroClientes? filtro]) =>
      switch (filtro ?? _filtro) {
        FiltroClientes.todos => true,
        FiltroClientes.habituales => r.segmento == SegmentoCliente.habitual ||
            r.segmento == SegmentoCliente.frecuente,
        FiltroClientes.nuevos => r.segmento == SegmentoCliente.nuevo ||
            r.segmento == SegmentoCliente.primeraVisita,
        FiltroClientes.conCita => r.proxima != null,
        FiltroClientes.alertas => _notas[r.cliente.id]?.tieneAlerta ?? false,
        FiltroClientes.inactivos => r.segmento == SegmentoCliente.inactivo,
      };

  int _contar(FiltroClientes f) => _resumenes.where((r) => _pasaFiltro(r, f)).length;

  List<ResumenCliente> get _visibles {
    final q = _busqueda.text.trim().toLowerCase();
    final lista = _resumenes.where((r) {
      if (!_pasaFiltro(r)) return false;
      if (q.isEmpty) return true;
      final c = r.cliente;
      return c.nombreCompleto.toLowerCase().contains(q) ||
          c.celular.contains(q) ||
          c.documento.contains(q) ||
          c.correo.toLowerCase().contains(q) ||
          r.etiquetaSegmento.toLowerCase().contains(q);
    }).toList();
    switch (_orden) {
      case OrdenClientes.nombre:
        lista.sort((a, b) => a.cliente.nombreCompleto
            .toLowerCase()
            .compareTo(b.cliente.nombreCompleto.toLowerCase()));
      case OrdenClientes.ultimaVisita:
        lista.sort((a, b) => (b.ultima?.inicio ?? DateTime(2000))
            .compareTo(a.ultima?.inicio ?? DateTime(2000)));
      case OrdenClientes.visitas:
        lista.sort((a, b) => b.visitas.compareTo(a.visitas));
    }
    return lista;
  }

  Future<void> _nuevoCliente() async {
    final c = await abrirFormulario<Cliente>(context, const ClienteFormSheet());
    if (c == null || !mounted) return;
    mostrarMensaje(context, 'Cliente ${c.nombreCompleto} registrado');
    await _cargar();
    if (mounted) _abrirFicha(c);
  }

  Future<void> _abrirFicha(Cliente c) async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => ClienteFichaScreen(cliente: c)));
    _cargar();
  }

  Future<void> _agendar(Cliente c) async {
    final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => NuevaReservaScreen(clienteInicial: c)));
    if (ok == true) _cargar();
  }

  Future<void> _editar(Cliente c) async {
    final editado =
        await abrirFormulario<Cliente>(context, ClienteFormSheet(cliente: c));
    if (editado != null && mounted) {
      mostrarMensaje(context, 'Datos de ${editado.nombreCompleto} actualizados');
      _cargar();
    }
  }

  Future<void> _eliminar(ResumenCliente r) async {
    if (r.proxima != null) {
      mostrarMensaje(context,
          'No se puede eliminar: ${r.cliente.nombres} tiene una cita programada.',
          error: true);
      return;
    }
    final ok = await confirmar(context,
        titulo: 'Eliminar cliente',
        mensaje: '¿Seguro que deseas eliminar a ${r.cliente.nombreCompleto}?',
        textoAceptar: 'Eliminar',
        peligroso: true);
    if (!ok || !mounted) return;
    try {
      await _api.eliminarCliente(r.cliente.id);
      await NotasClienteService.instance.guardar(r.cliente.id, const NotaCliente());
      if (!mounted) return;
      mostrarMensaje(context, '${r.cliente.nombreCompleto} fue eliminado');
      _cargar();
    } on ApiException catch (e) {
      if (mounted) mostrarMensaje(context, e.mensaje, error: true);
    }
  }

  void _whatsApp(ResumenCliente r, {bool promo = false}) {
    final nombre = r.cliente.nombres.split(' ').first;
    final mensaje = promo
        ? 'Hola $nombre, ¡te extrañamos en Kallos! Esta semana tienes 15% de '
            'descuento en tu próximo servicio. ¿Te agendamos?'
        : r.proxima != null
            ? 'Hola $nombre, te escribimos de Kallos para confirmar tu cita del '
                '${haceCuanto(r.proxima!.inicio!).toLowerCase()} a las ${r.proxima!.horaInicio} '
                '(${r.proxima!.servicio}). ¿Nos confirmas tu asistencia?'
            : 'Hola $nombre, te saludamos de Kallos. ¿Te gustaría agendar tu próxima cita?';
    abrirWhatsApp(context, r.cliente.celular, mensaje);
  }

  void _elegirOrden() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Ordenar por',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
            for (final o in [
              (OrdenClientes.nombre, 'Nombre (A-Z)', Icons.sort_by_alpha),
              (OrdenClientes.ultimaVisita, 'Última visita', Icons.history),
              (OrdenClientes.visitas, 'Más visitas', Icons.trending_up),
            ])
              ListTile(
                leading: Icon(o.$3),
                title: Text(o.$2),
                trailing: _orden == o.$1
                    ? const Icon(Icons.check, color: AppColors.primario)
                    : null,
                onTap: () {
                  setState(() => _orden = o.$1);
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
        title: const Row(children: [
          KallosLogo(alto: 28),
          SizedBox(width: 8),
          Text('Kallos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        ]),
        actions: [
          IconButton(
              tooltip: 'Actualizar', onPressed: _cargar, icon: const Icon(Icons.refresh)),
        ],
        bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider()),
      ),
      body: _cuerpo(),
    );
  }

  Widget _cuerpo() {
    if (_cargando) return const Center(child: CircularProgressIndicator());
    if (_error != null && _resumenes.isEmpty) {
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

    final visibles = _visibles;
    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Clientes',
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
                    Text('Base de datos operativa & fidelización',
                        style: TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
                  ],
                ),
              ),
              SizedBox(
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: _nuevoCliente,
                  style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 14)),
                  icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                  label: const Text('Nuevo'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _indicadores(),
          const SizedBox(height: 14),
          TextField(
            controller: _busqueda,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Buscar por nombre, teléfono o documento...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: IconButton(
                tooltip: 'Ordenar',
                icon: const Icon(Icons.tune, size: 20),
                onPressed: _elegirOrden,
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _chip(FiltroClientes.todos, 'Todos'),
                _chip(FiltroClientes.habituales, 'Habituales'),
                _chip(FiltroClientes.nuevos, 'Nuevos'),
                _chip(FiltroClientes.conCita, 'Con cita'),
                _chip(FiltroClientes.alertas, 'Con alertas', punto: AppColors.alerta),
                _chip(FiltroClientes.inactivos, 'Inactivos'),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (visibles.isEmpty)
            TarjetaKallos(
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
              child: Column(children: [
                const Icon(Icons.person_search_outlined,
                    size: 32, color: AppColors.textoTenue),
                const SizedBox(height: 8),
                const Text('No hay clientes con esos filtros.',
                    style: TextStyle(color: AppColors.textoSecundario)),
                if (_busqueda.text.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _nuevoCliente,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Registrar cliente nuevo'),
                  ),
                ],
              ]),
            )
          else
            for (final r in visibles) ...[
              _tarjeta(r),
              const SizedBox(height: 12),
            ],
          const SizedBox(height: 4),
          Center(
            child: Text(
                'Mostrando ${visibles.length} de ${_resumenes.length} clientes registrados',
                style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
          ),
        ],
      ),
    );
  }

  Widget _indicadores() {
    final ahora = DateTime.now();
    bool esteMes(DateTime? d) => d != null && d.year == ahora.year && d.month == ahora.month;
    final nuevosMes = _resumenes.where((r) => esteMes(r.primeraCita)).length;
    final citasMes = _reservas
        .where((c) => c.estado != EstadoCita.cancelada && esteMes(c.inicio))
        .length;
    final realizadasMes = _reservas
        .where((c) => c.estado == EstadoCita.finalizada && esteMes(c.inicio))
        .length;
    final conVisitas = _resumenes.where((r) => r.visitas > 0).length;
    final recurrentes = _resumenes.where((r) => r.visitas >= 2).length;
    final recurrencia = conVisitas == 0 ? 0 : (recurrentes * 100 / conVisitas).round();

    return Row(children: [
      Expanded(
          child: _kpi('TOTAL', '${_resumenes.length}', Icons.groups_outlined,
              '+$nuevosMes este mes')),
      const SizedBox(width: 8),
      Expanded(
          child: _kpi('CITAS MES', '$citasMes', Icons.event_available_outlined,
              '$realizadasMes realizadas')),
      const SizedBox(width: 8),
      Expanded(
          child: _kpi('RECURRENCIA', '$recurrencia%', Icons.autorenew,
              recurrencia >= 50 ? 'Tasa sólida' : 'Por mejorar')),
    ]);
  }

  Widget _kpi(String titulo, String valor, IconData icono, String detalle) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.superficie,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borde),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(titulo,
                    style: const TextStyle(
                        fontSize: 10,
                        letterSpacing: 0.4,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textoSecundario)),
              ),
              Icon(icono, size: 15, color: AppColors.primario),
            ]),
            const SizedBox(height: 4),
            Text(valor, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            Text(detalle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: AppColors.primario)),
          ],
        ),
      );

  Widget _chip(FiltroClientes f, String texto, {Color? punto}) {
    final sel = _filtro == f;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        avatar: punto == null
            ? null
            : CircleAvatar(radius: 4, backgroundColor: punto),
        label: Text('$texto (${_contar(f)})'),
        selected: sel,
        showCheckmark: false,
        selectedColor: AppColors.primario,
        backgroundColor: AppColors.superficie,
        side: BorderSide(color: sel ? AppColors.primario : AppColors.borde),
        shape: const StadiumBorder(),
        labelStyle: TextStyle(
            color: sel ? Colors.white : AppColors.texto,
            fontWeight: FontWeight.w600,
            fontSize: 12),
        onSelected: (_) => setState(() => _filtro = f),
      ),
    );
  }

  (Color, Color) _coloresSegmento(SegmentoCliente s) => switch (s) {
        SegmentoCliente.habitual => (AppColors.exitoSuave, AppColors.exito),
        SegmentoCliente.frecuente => (const Color(0xFFDCFCE7), const Color(0xFF166534)),
        SegmentoCliente.primeraVisita => (AppColors.infoSuave, AppColors.info),
        SegmentoCliente.nuevo => (AppColors.infoSuave, AppColors.info),
        SegmentoCliente.inactivo => (AppColors.neutroSuave, AppColors.neutro),
      };

  Widget _tarjeta(ResumenCliente r) {
    final c = r.cliente;
    final nota = _notas[c.id];
    final inactivo = r.segmento == SegmentoCliente.inactivo;
    final colores = _coloresSegmento(r.segmento);
    final proxima = r.proxima;
    final ultima = r.ultima;

    final Widget linea;
    if (proxima != null) {
      linea = Row(children: [
        const Icon(Icons.event_outlined, size: 15, color: AppColors.primario),
        const SizedBox(width: 6),
        Expanded(
          child: Text.rich(TextSpan(children: [
            const TextSpan(text: 'Próxima cita: '),
            TextSpan(
                text: '${haceCuanto(proxima.inicio!)} ${proxima.horaInicio}',
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ]), style: const TextStyle(fontSize: 13, color: AppColors.primario)),
        ),
      ]);
    } else if (ultima != null) {
      linea = Row(children: [
        Icon(Icons.history, size: 15,
            color: inactivo ? AppColors.textoTenue : AppColors.textoSecundario),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
              'Última: ${haceCuanto(ultima.inicio!)} (${ultima.servicio})',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 13,
                  color: inactivo ? AppColors.textoTenue : AppColors.textoSecundario)),
        ),
      ]);
    } else {
      linea = const Text('Aún sin citas registradas',
          style: TextStyle(fontSize: 13, color: AppColors.textoSecundario));
    }

    return Opacity(
      opacity: inactivo ? 0.8 : 1,
      child: TarjetaKallos(
        onTap: () => _abrirFicha(c),
        padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AvatarIniciales(c.nombreCompleto,
                    radio: 21,
                    fondo: inactivo ? const Color(0xFFE8EAFB) : const Color(0xFFBDEBCB),
                    color: inactivo ? AppColors.avatarTexto : const Color(0xFF14532D)),
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
                          Text(c.nombreCompleto,
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w700)),
                          if (nota?.tieneAlerta ?? false)
                            const Etiqueta(
                                texto: 'Alerta',
                                icono: Icons.warning_amber_rounded,
                                fondo: AppColors.alertaSuave,
                                color: AppColors.alerta),
                          Etiqueta(
                              texto: r.etiquetaSegmento,
                              fondo: colores.$1,
                              color: colores.$2),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(c.celular.isEmpty ? 'CC ${c.documento}' : c.celular,
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.textoSecundario)),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: AppColors.textoSecundario),
                  onSelected: (v) {
                    switch (v) {
                      case 'editar':
                        _editar(c);
                      case 'eliminar':
                        _eliminar(r);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'editar', child: Text('Editar datos')),
                    PopupMenuItem(
                        value: 'eliminar',
                        child: Text('Eliminar', style: TextStyle(color: AppColors.error))),
                  ],
                ),
              ],
            ),
            if (nota?.tieneAlerta ?? false) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Text('Nota clínica: ${nota!.alerta}',
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.alerta,
                          fontWeight: FontWeight.w600)),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Row(children: [
                Expanded(child: linea),
                const SizedBox(width: 6),
                Etiqueta(
                  texto: proxima != null && r.visitas == 0
                      ? 'Nuevo cliente'
                      : r.visitas == 1
                          ? '1 visita'
                          : '${r.visitas} visitas',
                  fondo: const Color(0xFFEEF0FA),
                  color: AppColors.textoSecundario,
                ),
              ]),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (!inactivo && c.celular.isNotEmpty) ...[
                    _iconoAccion(
                        proxima != null ? Icons.chat_outlined : Icons.call_outlined,
                        proxima != null ? 'WhatsApp' : 'Llamar',
                        () {
                          if (proxima != null) {
                            abrirConfirmarCita(context, proxima, cliente: c)
                                .then((x) => x == true ? _cargar() : null);
                          } else {
                            llamar(context, c.celular);
                          }
                        }),
                    const SizedBox(width: 8),
                  ],
                  if (inactivo)
                    OutlinedButton.icon(
                      onPressed: () => _whatsApp(r, promo: true),
                      icon: const Icon(Icons.campaign_outlined, size: 18),
                      label: const Text('Reactivar promo'),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: () => _agendar(c),
                      icon: const Icon(Icons.edit_calendar_outlined, size: 18),
                      label: const Text('Agendar'),
                    ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => _abrirFicha(c),
                    style: TextButton.styleFrom(
                      backgroundColor: const Color(0xFFEEF0FA),
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Ver ficha',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconoAccion(IconData icono, String tooltip, VoidCallback onTap) => SizedBox(
        width: 38,
        height: 36,
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
          child: Tooltip(
              message: tooltip,
              child: Icon(icono, size: 18, color: AppColors.primario)),
        ),
      );
}
