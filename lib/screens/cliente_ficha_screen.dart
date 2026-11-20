import 'package:flutter/material.dart';

import '../models/catalogos.dart';
import '../models/cita.dart';
import '../models/resumen_cliente.dart';
import '../services/api_client.dart';
import '../services/catalogo_service.dart';
import '../services/notas_cliente.dart';
import '../theme/app_colors.dart';
import '../utils/formatos.dart';
import '../widgets/comunes.dart';
import '../widgets/contacto.dart';
import '../widgets/formularios.dart';
import '../widgets/home_widgets.dart';
import '../widgets/reserva_sheets.dart';
import 'nueva_reserva_screen.dart';

class ClienteFichaScreen extends StatefulWidget {
  final Cliente cliente;
  const ClienteFichaScreen({super.key, required this.cliente});

  @override
  State<ClienteFichaScreen> createState() => _ClienteFichaScreenState();
}

class _ClienteFichaScreenState extends State<ClienteFichaScreen> {
  static const _meses = [
    'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio',
    'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
  ];
  static const _mesesCortos = [
    'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
  ];

  late Cliente _cliente;
  ResumenCliente? _resumen;
  NotaCliente _nota = const NotaCliente();
  bool _cargando = true;
  String? _error;
  bool _verProximas = false;
  bool _verTodo = false;

  @override
  void initState() {
    super.initState();
    _cliente = widget.cliente;
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _error = null;
      if (_resumen == null) _cargando = true;
    });
    try {
      final r = await Future.wait([
        CatalogoService.instance.reservas(),
        NotasClienteService.instance.todas(),
      ]);
      if (!mounted) return;
      setState(() {
        _resumen = ResumenCliente.calcular(_cliente, r[0] as List<Cita>);
        _nota = (r[1] as Map<int, NotaCliente>)[_cliente.id] ?? const NotaCliente();
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _editar() async {
    final c = await abrirFormulario<Cliente>(context, ClienteFormSheet(cliente: _cliente));
    if (c == null || !mounted) return;
    setState(() => _cliente = c);
    mostrarMensaje(context, 'Datos actualizados');
    _cargar();
  }

  Future<void> _eliminar() async {
    if (_resumen?.proxima != null) {
      mostrarMensaje(context, 'No se puede eliminar: tiene una cita programada.',
          error: true);
      return;
    }
    final ok = await confirmar(context,
        titulo: 'Eliminar cliente',
        mensaje: '¿Seguro que deseas eliminar a ${_cliente.nombreCompleto}?',
        textoAceptar: 'Eliminar',
        peligroso: true);
    if (!ok || !mounted) return;
    try {
      await CatalogoService.instance.eliminarCliente(_cliente.id);
      await NotasClienteService.instance.guardar(_cliente.id, const NotaCliente());
      if (!mounted) return;
      mostrarMensaje(context, '${_cliente.nombreCompleto} fue eliminado');
      Navigator.pop(context);
    } on ApiException catch (e) {
      if (mounted) mostrarMensaje(context, e.mensaje, error: true);
    }
  }

  Future<void> _agendar() async {
    final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => NuevaReservaScreen(clienteInicial: _cliente)));
    if (ok == true) _cargar();
  }

  Future<void> _agendarRapido() async {
    final r = _resumen;
    final ok = await abrirAgendarRapido(context, _cliente,
        servicioSugerido: r?.ultima?.servicioId,
        profesionalHabitual: r?.profesionalHabitual ?? '',
        alerta: _nota.alerta);
    if (ok == true) _cargar();
  }

  Future<void> _detalle(Cita c) async {
    final cambio = await abrirDetalleReserva(context, c, cliente: _cliente);
    if (cambio == true) _cargar();
  }

  Future<void> _editarNotas() async {
    final alerta = TextEditingController(text: _nota.alerta);
    final notas = TextEditingController(text: _nota.notas);
    final guardar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Notas técnicas & salud'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Alergias o restricciones',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextField(
                controller: alerta,
                maxLines: 2,
                maxLength: 200,
                decoration: const InputDecoration(
                    hintText: 'Ej: Alergia a tintes con amoníaco'),
              ),
              const SizedBox(height: 6),
              const Text('Fórmula, preferencias y observaciones',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextField(
                controller: notas,
                maxLines: 4,
                maxLength: 500,
                decoration: const InputDecoration(
                    hintText: 'Ej: Tono base 6.3 + matizador 9.12, 35 min'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar',
                  style: TextStyle(color: AppColors.textoSecundario))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Guardar',
                  style: TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
    if (guardar == true) {
      final nueva = NotaCliente(
          alerta: alerta.text.trim(), notas: notas.text.trim(), actualizada: DateTime.now());
      await NotasClienteService.instance.guardar(_cliente.id, nueva);
      if (mounted) {
        setState(() => _nota = nueva);
        mostrarMensaje(context, 'Notas guardadas');
      }
    }
    Future.delayed(const Duration(milliseconds: 500), () {
      alerta.dispose();
      notas.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: const Text('Ficha de Cliente',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        actions: [
          OutlinedButton.icon(
            onPressed: _editar,
            icon: const Icon(Icons.edit_outlined, size: 16),
            label: const Text('Editar'),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'eliminar') _eliminar();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                  value: 'eliminar',
                  child: Text('Eliminar cliente', style: TextStyle(color: AppColors.error))),
            ],
          ),
        ],
        bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider()),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _resumen == null
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
              : RefreshIndicator(onRefresh: _cargar, child: _contenido()),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: ElevatedButton.icon(
            onPressed: _agendar,
            icon: const Icon(Icons.add_circle_outline),
            label: Text('Nueva cita para ${_cliente.nombres.split(' ').first}'),
          ),
        ),
      ),
    );
  }

  Widget _contenido() {
    final r = _resumen!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _cabecera(r),
        const SizedBox(height: 12),
        _acciones(),
        const SizedBox(height: 12),
        _datos(r),
        const SizedBox(height: 12),
        _notas(),
        const SizedBox(height: 18),
        _historial(r),
      ],
    );
  }

  Widget _cabecera(ResumenCliente r) {
    final desde = r.primeraCita;
    return TarjetaKallos(
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AvatarIniciales(_cliente.nombreCompleto,
                  radio: 30,
                  fondo: const Color(0xFFE6F2EB),
                  color: AppColors.primario),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_cliente.nombreCompleto,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                    Text(
                        desde == null
                            ? 'Sin visitas registradas'
                            : 'Cliente desde ${_meses[desde.month - 1]} ${desde.year}',
                        style: const TextStyle(color: AppColors.textoSecundario)),
                    const SizedBox(height: 6),
                    Wrap(spacing: 6, runSpacing: 4, children: [
                      Etiqueta(
                          texto: 'Cliente ${r.etiquetaSegmento}',
                          punto: true,
                          fondo: AppColors.exitoSuave,
                          color: AppColors.exito),
                      if (_nota.tieneAlerta)
                        const Etiqueta(
                            texto: 'Alerta',
                            icono: Icons.warning_amber_rounded,
                            fondo: AppColors.alertaSuave,
                            color: AppColors.alerta),
                    ]),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _cajaDato('Visitas acumuladas', '${r.visitas}')),
            const SizedBox(width: 10),
            Expanded(
                child: _cajaDato('Gasto promedio', Formatos.moneda(r.gastoPromedio),
                    color: AppColors.primario)),
          ]),
        ],
      ),
    );
  }

  Widget _cajaDato(String titulo, String valor, {Color color = AppColors.texto}) =>
      Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
            color: const Color(0xFFF6F7FB), borderRadius: BorderRadius.circular(10)),
        child: Column(children: [
          Text(titulo,
              style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
          const SizedBox(height: 4),
          FittedBox(
            child: Text(valor,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: color)),
          ),
        ]),
      );

  Widget _acciones() {
    final nombre = _cliente.nombres.split(' ').first;
    Widget boton(IconData icono, String texto, VoidCallback? onTap,
        {bool destacado = false}) {
      return Expanded(
        child: Material(
          color: destacado ? AppColors.primarioSuave : AppColors.superficie,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
                color: destacado ? const Color(0xFF9FD3B4) : AppColors.borde),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Opacity(
              opacity: onTap == null ? 0.4 : 1,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(children: [
                  Icon(icono, size: 20,
                      color: destacado ? AppColors.primario : AppColors.texto),
                  const SizedBox(height: 4),
                  Text(texto,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: destacado ? AppColors.primario : AppColors.texto)),
                ]),
              ),
            ),
          ),
        ),
      );
    }

    final tieneCel = _cliente.celular.isNotEmpty;
    return Row(children: [
      boton(Icons.call_outlined, 'Llamar',
          tieneCel ? () => llamar(context, _cliente.celular) : null),
      const SizedBox(width: 8),
      boton(
          Icons.chat_outlined,
          'WhatsApp',
          tieneCel
              ? () => abrirWhatsApp(context, _cliente.celular,
                  'Hola $nombre, te saludamos de Kallos.')
              : null),
      const SizedBox(width: 8),
      boton(Icons.mail_outline, 'Email',
          _cliente.correo.contains('@')
              ? () => enviarCorreo(context, _cliente.correo, asunto: 'Kallos')
              : null),
      const SizedBox(width: 8),
      boton(Icons.edit_calendar_outlined, 'Agendar', _agendarRapido, destacado: true),
    ]);
  }

  Widget _datos(ResumenCliente r) {
    final nac = DateTime.tryParse(_cliente.fechaNacimiento);
    String? nacimiento;
    if (nac != null) {
      final hoy = DateTime.now();
      var edad = hoy.year - nac.year;
      if (hoy.month < nac.month || (hoy.month == nac.month && hoy.day < nac.day)) edad--;
      nacimiento = '${nac.day} de ${_meses[nac.month - 1]} ($edad años)';
    }
    return TarjetaKallos(
      child: Column(
        children: [
          const EncabezadoSeccion(
              icono: Icons.badge_outlined,
              titulo: 'Datos y Contacto',
              trailing: TextoAyuda('Privado')),
          const SizedBox(height: 8),
          _filaDato(Icons.credit_card, 'Documento', _cliente.documento),
          _filaDato(Icons.call_outlined, 'Teléfono',
              _cliente.celular.isEmpty ? 'Sin registrar' : _cliente.celular),
          _filaDato(Icons.alternate_email, 'Email',
              _cliente.correo.isEmpty ? 'Sin registrar' : _cliente.correo),
          if (nacimiento != null) _filaDato(Icons.cake_outlined, 'Nacimiento', nacimiento),
          _filaDato(Icons.content_cut, 'Profesional habitual',
              r.profesionalHabitual.isEmpty ? 'Aún no definido' : r.profesionalHabitual,
              ultimo: true),
        ],
      ),
    );
  }

  Widget _filaDato(IconData icono, String titulo, String valor, {bool ultimo = false}) =>
      Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          border: ultimo ? null : const Border(bottom: BorderSide(color: AppColors.borde)),
        ),
        child: Row(children: [
          Icon(icono, size: 17, color: AppColors.textoSecundario),
          const SizedBox(width: 10),
          Text(titulo, style: const TextStyle(color: AppColors.textoSecundario)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(valor,
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ]),
      );

  Widget _notas() {
    return TarjetaKallos(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: _nota.tieneAlerta ? const Color(0xFFF59E0B) : AppColors.textoTenue,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('Notas Técnicas & Salud',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
            TextButton.icon(
              onPressed: _editarNotas,
              icon: const Icon(Icons.edit_note, size: 18),
              label: const Text('Editar'),
            ),
          ]),
          const SizedBox(height: 6),
          if (_nota.vacia)
            const Text(
                'Sin notas. Registra alergias, fórmulas de color o preferencias del cliente.',
                style: TextStyle(color: AppColors.textoSecundario)),
          if (_nota.tieneAlerta)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppColors.alerta),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('ALERGIA / RESTRICCIÓN',
                            style: TextStyle(
                                fontSize: 11,
                                letterSpacing: 0.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.alerta)),
                        const SizedBox(height: 2),
                        Text(_nota.alerta,
                            style: const TextStyle(color: Color(0xFF78350F))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          if (_nota.notas.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF6F7FB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.borde),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Expanded(
                      child: Text('FÓRMULA / OBSERVACIONES',
                          style: TextStyle(
                              fontSize: 11,
                              letterSpacing: 0.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primario)),
                    ),
                    if (_nota.actualizada != null)
                      Text(
                          'Actualizada: ${_nota.actualizada!.day} '
                          '${_mesesCortos[_nota.actualizada!.month - 1]} ${_nota.actualizada!.year}',
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textoSecundario)),
                  ]),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.superficie,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.borde),
                    ),
                    child: Text(_nota.notas,
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          const Text('Se guardan en este dispositivo.',
              style: TextStyle(fontSize: 11, color: AppColors.textoTenue)),
        ],
      ),
    );
  }

  Widget _historial(ResumenCliente r) {
    final pasadas = r.citas.where((c) => !c.vigente).toList();
    final proximas = r.citas.where((c) => c.vigente).toList()
      ..sort((a, b) => (a.inicio ?? DateTime(2100)).compareTo(b.inicio ?? DateTime(2100)));
    final lista = _verProximas ? proximas : pasadas;
    final mostradas = _verTodo ? lista : lista.take(3).toList();

    Widget pestana(String texto, int n, bool activa, VoidCallback onTap) => Expanded(
          child: InkWell(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                      color: activa ? AppColors.primario : AppColors.borde,
                      width: activa ? 2.5 : 1),
                ),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(texto,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: activa ? AppColors.primario : AppColors.textoSecundario)),
                const SizedBox(width: 6),
                Etiqueta(
                    texto: '$n',
                    fondo: activa ? AppColors.exitoSuave : AppColors.neutroSuave,
                    color: activa ? AppColors.exito : AppColors.neutro),
              ]),
            ),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          pestana('Historial de Citas', pasadas.length, !_verProximas,
              () => setState(() {
                    _verProximas = false;
                    _verTodo = false;
                  })),
          pestana('Próximas', proximas.length, _verProximas, () => setState(() {
                _verProximas = true;
                _verTodo = false;
              })),
        ]),
        const SizedBox(height: 12),
        if (lista.isEmpty)
          TarjetaKallos(
            padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
            child: Text(
                _verProximas ? 'No tiene citas programadas.' : 'Aún no tiene citas atendidas.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textoSecundario)),
          )
        else
          for (final c in mostradas) ...[
            _tarjetaCita(c),
            const SizedBox(height: 10),
          ],
        if (!_verTodo && lista.length > 3)
          OutlinedButton(
            onPressed: () => setState(() => _verTodo = true),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
            child: Text('Ver las ${lista.length - 3} citas anteriores'),
          ),
      ],
    );
  }

  Widget _tarjetaCita(Cita c) {
    final hoy = DateTime.now();
    final f = c.inicio;
    final esHoy = f != null && f.year == hoy.year && f.month == hoy.month && f.day == hoy.day;
    final fecha = f == null
        ? ''
        : '${f.day.toString().padLeft(2, '0')} ${_mesesCortos[f.month - 1]} ${f.year}${esHoy ? ' (Hoy)' : ''}';
    final enCurso = c.estado == EstadoCita.enCurso;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.superficie,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: enCurso ? AppColors.primario : AppColors.borde, width: enCurso ? 1.5 : 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _detalle(c),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(spacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                        Text(fecha,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primario)),
                        EtiquetaEstadoCita(c.estado),
                      ]),
                      const SizedBox(height: 4),
                      Text(c.servicio,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text('${c.profesionalCorto} • ${c.horaInicio} - ${c.horaFin}',
                          style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
                    ],
                  ),
                ),
                Text(Formatos.moneda(c.precio),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
