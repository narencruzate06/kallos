import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/catalogos.dart';
import '../models/cita.dart';
import '../services/api_client.dart';
import '../services/catalogo_service.dart';
import '../services/disponibilidad.dart';
import '../services/notas_cliente.dart';
import '../theme/app_colors.dart';
import '../utils/formatos.dart';
import 'comunes.dart';
import 'formularios.dart';
import 'home_widgets.dart';
import '../screens/cliente_ficha_screen.dart';

Future<void> abrirWhatsApp(BuildContext context, String celular, String mensaje) async {
  final numero = celular.replaceAll(RegExp(r'\D'), '');
  if (numero.length < 10) {
    mostrarMensaje(context, 'El cliente no tiene un celular válido.', error: true);
    return;
  }
  final completo = numero.length == 10 ? '57$numero' : numero;
  final uri = Uri.parse(
      'https://wa.me/$completo?text=${Uri.encodeComponent(mensaje)}');
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    mostrarMensaje(context, 'No se pudo abrir WhatsApp.', error: true);
  }
}

Future<bool?> abrirDetalleReserva(BuildContext context, Cita cita,
    {Cliente? cliente}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.superficie,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => ReservaDetalleSheet(cita: cita, cliente: cliente),
  );
}

class ReservaDetalleSheet extends StatefulWidget {
  final Cita cita;
  final Cliente? cliente;
  const ReservaDetalleSheet({super.key, required this.cita, this.cliente});

  @override
  State<ReservaDetalleSheet> createState() => _ReservaDetalleSheetState();
}

class _ReservaDetalleSheetState extends State<ReservaDetalleSheet> {
  bool _cancelando = false;

  Cita get c => widget.cita;

  Future<void> _cancelar() async {
    final r = await abrirCancelarReserva(context, c, cliente: widget.cliente);
    if (!mounted) return;
    if (r == true) Navigator.pop(context, true);
  }

  Future<void> _confirmarConCliente() async {
    final r = await abrirConfirmarCita(context, c, cliente: widget.cliente);
    if (r == true && mounted) Navigator.pop(context, true);
  }

  Future<void> _editar() async {
    final ok = await abrirFormulario<bool>(context, EditarReservaSheet(cita: c));
    if (ok == true && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final celular = widget.cliente?.celular ?? '';
    final fecha = c.inicio == null ? '' : Formatos.fechaLarga(c.inicio!);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.borde,
                    borderRadius: BorderRadius.circular(4))),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(c.cliente,
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.w700)),
                        EtiquetaEstadoCita(c.estado),
                      ],
                    ),
                    if (celular.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(children: [
                        const Icon(Icons.phone_outlined,
                            size: 15, color: AppColors.textoSecundario),
                        const SizedBox(width: 4),
                        Text(celular,
                            style: const TextStyle(color: AppColors.textoSecundario)),
                      ]),
                    ],
                  ],
                ),
              ),
              IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close)),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF0FA),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _dato('SERVICIO', c.servicio)),
                    const SizedBox(width: 12),
                    Expanded(child: _dato('ESPECIALISTA', c.profesional)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _dato('FECHA', fecha)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _dato('HORARIO',
                            '${c.horaInicio} - ${c.horaFin} (${c.duracion} min)')),
                  ],
                ),
                if (c.precio > 0) ...[
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: _dato('VALOR', Formatos.moneda(c.precio))),
                  ]),
                ],
              ],
            ),
          ),
          if (widget.cliente != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () {
                  final cliente = widget.cliente!;
                  final navegador = Navigator.of(context);
                  navegador.pop();
                  navegador.push(MaterialPageRoute(
                      builder: (_) => ClienteFichaScreen(cliente: cliente)));
                },
                icon: const Icon(Icons.person_outline, size: 18),
                label: const Text('Ver ficha del cliente'),
              ),
            ),
          ],
          if (c.vigente) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _confirmarConCliente,
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  foregroundColor: AppColors.exito),
              icon: const Icon(Icons.mark_chat_read_outlined, size: 18),
              label: const Text('Confirmar cita con el cliente'),
            ),
          ],
          const SizedBox(height: 16),
          if (c.vigente)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _cancelando ? null : _editar,
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48)),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Editar'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _cancelando ? null : _cancelar,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      backgroundColor: AppColors.errorSuave,
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.errorSuave),
                    ),
                    icon: _cancelando
                        ? const CargandoBoton(color: AppColors.error)
                        : const Icon(Icons.cancel_outlined, size: 18),
                    label: const Text('Cancelar'),
                  ),
                ),
              ],
            )
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.neutroSuave,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                c.estado == EstadoCita.enCurso
                    ? 'La cita está en curso. No se puede editar ni cancelar.'
                    : 'Esta reserva ya no se puede modificar.',
                style: const TextStyle(color: AppColors.textoSecundario),
              ),
            ),
        ],
      ),
    );
  }

  Widget _dato(String titulo, String valor) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo,
              style: const TextStyle(
                  fontSize: 10,
                  letterSpacing: 0.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textoSecundario)),
          const SizedBox(height: 2),
          Text(valor.isEmpty ? '—' : valor,
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      );
}

class EditarReservaSheet extends StatefulWidget {
  final Cita cita;
  const EditarReservaSheet({super.key, required this.cita});

  @override
  State<EditarReservaSheet> createState() => _EditarReservaSheetState();
}

class _EditarReservaSheetState extends State<EditarReservaSheet> {
  final _api = CatalogoService.instance;
  List<Servicio> _servicios = [];
  List<HorarioLaboral> _horarios = [];
  Servicio? _servicio;
  late DateTime _dia;
  String? _hora;
  List<String> _horas = [];
  bool _cargando = true;
  bool _cargandoHoras = false;
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final hoy = DateTime.now();
    final inicio = widget.cita.inicio ?? hoy;
    _dia = inicio.isBefore(DateTime(hoy.year, hoy.month, hoy.day))
        ? DateTime(hoy.year, hoy.month, hoy.day)
        : DateTime(inicio.year, inicio.month, inicio.day);
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final r = await Future.wait([
        _api.servicios(),
        _api.horariosLaborales().catchError((_) => <HorarioLaboral>[]),
      ]);
      _servicios = (r[0] as List<Servicio>).where((s) => s.activo).toList();
      _horarios = r[1] as List<HorarioLaboral>;
      for (final s in _servicios) {
        if (s.id == widget.cita.servicioId) _servicio = s;
      }
      _servicio ??= _servicios.isNotEmpty ? _servicios.first : null;
      if (mounted) setState(() => _cargando = false);
      _consultarHoras();
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _cargando = false;
          _error = e.mensaje;
        });
      }
    }
  }

  Future<void> _consultarHoras() async {
    final s = _servicio;
    if (s == null) return;
    setState(() {
      _cargandoHoras = true;
      _hora = null;
    });
    final prof = widget.cita.profesionalId == 0 ? null : widget.cita.profesionalId;
    try {
      var horas = await _api.horasDisponibles(
          fecha: _dia, servicioId: s.id, profesionalId: prof);
      if (horas == null) {
        final reservas = (await _api.reservas(desde: _dia, hasta: _dia))
            .where((r) => r.id != widget.cita.id)
            .toList();
        horas = prof == null
            ? Disponibilidad.deCualquiera(
                profesionales: [], dia: _dia, duracion: s.duracion,
                horarios: _horarios, reservas: reservas)
            : Disponibilidad.deProfesional(
                profesionalId: prof, dia: _dia, duracion: s.duracion,
                horarios: _horarios, reservas: reservas);
      }
      if (!mounted) return;
      setState(() {
        _horas = Disponibilidad.quitarPasadas(horas!, _dia);
        _cargandoHoras = false;
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _cargandoHoras = false;
          _error = e.mensaje;
        });
      }
    }
  }

  Future<void> _elegirDia() async {
    final hoy = DateTime.now();
    final f = await showDatePicker(
      context: context,
      initialDate: _dia,
      firstDate: DateTime(hoy.year, hoy.month, hoy.day),
      lastDate: hoy.add(const Duration(days: 60)),
      helpText: 'Nueva fecha',
    );
    if (f == null) return;
    setState(() => _dia = f);
    _consultarHoras();
  }

  Future<void> _guardar() async {
    if (_servicio == null || _hora == null) {
      setState(() => _error = 'Selecciona el servicio y la nueva hora.');
      return;
    }
    final p = _hora!.split(':');
    final fechaHora = DateTime(
        _dia.year, _dia.month, _dia.day, int.parse(p[0]), int.parse(p[1]));
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await _api.editarReserva(
          id: widget.cita.id, fechaHora: fechaHora, servicioId: _servicio!.id);
      if (!mounted) return;
      mostrarMensaje(context,
          'Reserva reagendada: ${Formatos.fechaLarga(_dia)} a las $_hora');
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            const Expanded(
              child: Text('Reagendar reserva',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ),
            IconButton(
                onPressed: _guardando ? null : () => Navigator.pop(context),
                icon: const Icon(Icons.close)),
          ]),
          Text('${widget.cita.cliente} · actual: ${widget.cita.horaInicio}'
              '${widget.cita.inicio == null ? '' : ' del ${Formatos.fechaLarga(widget.cita.inicio!)}'}',
              style: const TextStyle(color: AppColors.textoSecundario)),
          const SizedBox(height: 16),
          if (_cargando)
            const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()))
          else ...[
            const Text('Servicio', style: TextStyle(fontSize: 13)),
            const SizedBox(height: 6),
            InputDecorator(
              decoration: const InputDecoration(
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 4)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _servicio?.id,
                  isExpanded: true,
                  items: [
                    for (final s in _servicios)
                      DropdownMenuItem(
                          value: s.id,
                          child: Text('${s.nombre} · ${s.duracion} min',
                              overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (id) {
                    setState(() => _servicio = _servicios.firstWhere((s) => s.id == id));
                    _consultarHoras();
                  },
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text('Nueva fecha', style: TextStyle(fontSize: 13)),
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: _elegirDia,
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
              icon: const Icon(Icons.calendar_today_outlined, size: 18),
              label: Text(Formatos.fechaLarga(_dia)),
            ),
            const SizedBox(height: 14),
            const Text('Nueva hora', style: TextStyle(fontSize: 13)),
            const SizedBox(height: 8),
            if (_cargandoHoras)
              const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()))
            else if (_horas.isEmpty)
              const Text('No hay horarios disponibles ese día.',
                  style: TextStyle(color: AppColors.textoSecundario))
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final h in _horas)
                    ChoiceChip(
                      label: Text(h),
                      selected: _hora == h,
                      showCheckmark: false,
                      selectedColor: AppColors.primario,
                      labelStyle: TextStyle(
                          color: _hora == h ? Colors.white : AppColors.texto,
                          fontWeight: FontWeight.w600),
                      onSelected: (_) => setState(() => _hora = h),
                    ),
                ],
              ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.error)),
          ],
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: _guardando || _cargando ? null : _guardar,
            child: _guardando ? const CargandoBoton() : const Text('Guardar cambios'),
          ),
        ],
      ),
    );
  }
}

Future<T?> _abrirHoja<T>(BuildContext context, Widget hoja) => showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      barrierColor: const Color(0x47111827),
      backgroundColor: AppColors.superficie,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: hoja,
      ),
    );

Widget _agarre() => Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(bottom: 12),
        decoration:
            BoxDecoration(color: AppColors.borde, borderRadius: BorderRadius.circular(4)),
      ),
    );

String _cuando(Cita c) {
  final f = c.inicio;
  if (f == null) return c.horaInicio;
  final hoy = DateTime.now();
  final manana = hoy.add(const Duration(days: 1));
  final dia = f.year == hoy.year && f.month == hoy.month && f.day == hoy.day
      ? 'Hoy'
      : f.year == manana.year && f.month == manana.month && f.day == manana.day
          ? 'Mañana'
          : Formatos.fechaLarga(f);
  return '$dia · ${c.horaInicio} - ${c.horaFin}';
}

Widget _resumenReserva(Cita c, Cliente? cliente) => Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F7FB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            AvatarIniciales(c.cliente,
                radio: 18, fondo: AppColors.primario, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.cliente,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  if ((cliente?.celular ?? '').isNotEmpty)
                    Text(cliente!.celular,
                        style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
                ],
              ),
            ),
            if (c.precio > 0)
              Text(Formatos.moneda(c.precio),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.primario)),
          ]),
          const SizedBox(height: 10),
          const Divider(),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('SERVICIO',
                        style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 0.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textoSecundario)),
                    const SizedBox(height: 2),
                    Text(c.servicio, style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text('${c.duracion} min',
                        style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('HORARIO & ESPECIALISTA',
                        style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 0.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textoSecundario)),
                    const SizedBox(height: 2),
                    Text(_cuando(c), style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(c.profesional,
                        style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );

Future<bool?> abrirCancelarReserva(BuildContext context, Cita cita, {Cliente? cliente}) =>
    _abrirHoja<bool>(context, CancelarReservaSheet(cita: cita, cliente: cliente));

class CancelarReservaSheet extends StatefulWidget {
  final Cita cita;
  final Cliente? cliente;
  const CancelarReservaSheet({super.key, required this.cita, this.cliente});

  @override
  State<CancelarReservaSheet> createState() => _CancelarReservaSheetState();
}

class _CancelarReservaSheetState extends State<CancelarReservaSheet> {
  late bool _avisar = (widget.cliente?.celular ?? '').isNotEmpty;
  bool _cancelando = false;

  Cita get c => widget.cita;

  String get _mensaje =>
      'Hola ${c.cliente.split(' ').first}, te informamos que tu cita en Kallos '
      '(${c.servicio}, ${_cuando(c)}) fue cancelada. Si deseas, te ayudamos a agendar una nueva fecha.';

  Future<void> _confirmar() async {
    setState(() => _cancelando = true);
    try {
      await CatalogoService.instance.cancelarReserva(c.id);
      if (!mounted) return;
      if (_avisar) await abrirWhatsApp(context, widget.cliente!.celular, _mensaje);
      if (!mounted) return;
      mostrarMensaje(context, 'Reserva de ${c.cliente} cancelada. El turno quedó libre.');
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) mostrarMensaje(context, e.mensaje, error: true);
    } finally {
      if (mounted) setState(() => _cancelando = false);
    }
  }

  Future<void> _reprogramar() async {
    final ok = await abrirFormulario<bool>(context, EditarReservaSheet(cita: c));
    if (ok == true && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final tieneCel = (widget.cliente?.celular ?? '').isNotEmpty;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _agarre(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: AppColors.errorSuave, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.event_busy_outlined, color: AppColors.error),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Cancelar Reserva',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                    Text('Esta acción libera la franja horaria en la agenda del especialista.',
                        style: TextStyle(fontSize: 13, color: AppColors.textoSecundario)),
                  ],
                ),
              ),
              IconButton(onPressed: () => Navigator.pop(context, false), icon: const Icon(Icons.close)),
            ],
          ),
          const SizedBox(height: 14),
          _resumenReserva(c, widget.cliente),
          if (tieneCel) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borde),
              ),
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _avisar,
                onChanged: (v) => setState(() => _avisar = v),
                title: Text('Avisar a ${c.cliente.split(' ').first} por WhatsApp',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: const Text('Se abre WhatsApp con el mensaje listo para enviar.',
                    style: TextStyle(fontSize: 12)),
              ),
            ),
          ],
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: _cancelando ? null : _confirmar,
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                disabledBackgroundColor: const Color(0xFFF2A3A3)),
            icon: _cancelando ? const CargandoBoton() : const Icon(Icons.cancel_outlined),
            label: const Text('Confirmar cancelación y liberar turno'),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _cancelando ? null : _reprogramar,
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                icon: const Icon(Icons.edit_calendar_outlined, size: 18),
                label: const Text('Reprogramar'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: _cancelando ? null : () => Navigator.pop(context, false),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                child: const Text('Mantener reserva'),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

enum CanalAviso { whatsapp, sms, email }

Future<bool?> abrirConfirmarCita(BuildContext context, Cita cita, {Cliente? cliente}) =>
    _abrirHoja<bool>(context, ConfirmarCitaSheet(cita: cita, cliente: cliente));

class ConfirmarCitaSheet extends StatefulWidget {
  final Cita cita;
  final Cliente? cliente;
  const ConfirmarCitaSheet({super.key, required this.cita, this.cliente});

  @override
  State<ConfirmarCitaSheet> createState() => _ConfirmarCitaSheetState();
}

class _ConfirmarCitaSheetState extends State<ConfirmarCitaSheet> {
  CanalAviso _canal = CanalAviso.whatsapp;
  late final _mensaje = TextEditingController(
      text: 'Hola ${widget.cita.cliente.split(' ').first}, tu cita de ${widget.cita.servicio} '
          'para ${_cuando(widget.cita).toLowerCase()} está confirmada en Kallos. ¡Te esperamos!');
  NotaCliente _nota = const NotaCliente();

  @override
  void initState() {
    super.initState();
    NotasClienteService.instance.todas().then((m) {
      if (mounted) setState(() => _nota = m[widget.cita.clienteId] ?? const NotaCliente());
    });
  }

  @override
  void dispose() {
    _mensaje.dispose();
    super.dispose();
  }

  String get _celular => widget.cliente?.celular ?? '';
  String get _correo => widget.cliente?.correo ?? '';

  bool _disponible(CanalAviso c) => switch (c) {
        CanalAviso.whatsapp || CanalAviso.sms => _celular.isNotEmpty,
        CanalAviso.email => _correo.contains('@'),
      };

  Future<void> _enviar() async {
    if (!_disponible(_canal)) {
      mostrarMensaje(context, 'El cliente no tiene datos de contacto para ese canal.',
          error: true);
      return;
    }
    final texto = _mensaje.text.trim();
    if (texto.isEmpty) {
      mostrarMensaje(context, 'Escribe el mensaje para el cliente.', error: true);
      return;
    }
    switch (_canal) {
      case CanalAviso.whatsapp:
        await abrirWhatsApp(context, _celular, texto);
      case CanalAviso.sms:
        final numero = _celular.replaceAll(RegExp(r'\D'), '');
        await launchUrl(Uri(scheme: 'sms', path: numero, queryParameters: {'body': texto}));
      case CanalAviso.email:
        await launchUrl(Uri(
            scheme: 'mailto',
            path: _correo,
            query: 'subject=${Uri.encodeComponent('Confirmación de tu cita en Kallos')}'
                '&body=${Uri.encodeComponent(texto)}'));
    }
    if (mounted) {
      mostrarMensaje(context, 'Aviso de confirmación preparado para ${widget.cita.cliente}');
      Navigator.pop(context, false);
    }
  }

  Future<void> _modificar() async {
    final ok = await abrirFormulario<bool>(context, EditarReservaSheet(cita: widget.cita));
    if (ok == true && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final destino = switch (_canal) {
      CanalAviso.whatsapp || CanalAviso.sms => _celular.isEmpty ? 'Sin celular' : _celular,
      CanalAviso.email => _correo.isEmpty ? 'Sin correo' : _correo,
    };
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _agarre(),
          Row(children: [
            const CircleAvatar(radius: 5, backgroundColor: AppColors.primario),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('Confirmar Cita',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            ),
            IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
          ]),
          const SizedBox(height: 10),
          _resumenReserva(widget.cita, widget.cliente),
          if (_nota.tieneAlerta) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.warning_amber_rounded, color: AppColors.alerta),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Alerta de Ficha Técnica',
                          style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.alerta)),
                      Text(_nota.alerta, style: const TextStyle(color: Color(0xFF78350F))),
                    ],
                  ),
                ),
              ]),
            ),
          ],
          const SizedBox(height: 14),
          const Text('CANAL DE ENVÍO',
              style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 0.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textoSecundario)),
          const SizedBox(height: 8),
          Row(children: [
            for (final c in [
              (CanalAviso.whatsapp, 'WhatsApp'),
              (CanalAviso.sms, 'SMS'),
              (CanalAviso.email, 'Email'),
            ]) ...[
              Expanded(
                child: Opacity(
                  opacity: _disponible(c.$1) ? 1 : 0.4,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: _disponible(c.$1) ? () => setState(() => _canal = c.$1) : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _canal == c.$1 ? AppColors.primarioSuave : AppColors.superficie,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: _canal == c.$1 ? AppColors.primario : AppColors.borde),
                      ),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(
                            _canal == c.$1
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            size: 16,
                            color: AppColors.primario),
                        const SizedBox(width: 6),
                        Text(c.$2, style: const TextStyle(fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ),
                ),
              ),
              if (c.$1 != CanalAviso.email) const SizedBox(width: 8),
            ],
          ]),
          const SizedBox(height: 12),
          Text('MENSAJE A: $destino',
              style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
          const SizedBox(height: 6),
          TextField(
            controller: _mensaje,
            maxLines: 3,
            maxLength: 300,
            decoration: const InputDecoration(fillColor: Color(0xFFF6F7FB)),
          ),
          const SizedBox(height: 6),
          ElevatedButton.icon(
            onPressed: _enviar,
            icon: const Icon(Icons.check_circle),
            label: const Text('Confirmar y notificar'),
          ),
          TextButton(
            onPressed: _modificar,
            child: const Text('Modificar hora o servicio antes de confirmar',
                style: TextStyle(
                    color: AppColors.textoSecundario, decoration: TextDecoration.underline)),
          ),
        ],
      ),
    );
  }
}

Future<bool?> abrirAgendarRapido(BuildContext context, Cliente cliente,
        {int? servicioSugerido, String profesionalHabitual = '', String alerta = ''}) =>
    _abrirHoja<bool>(
        context,
        AgendarRapidoSheet(
            cliente: cliente,
            servicioSugerido: servicioSugerido,
            profesionalHabitual: profesionalHabitual,
            alerta: alerta));

class AgendarRapidoSheet extends StatefulWidget {
  final Cliente cliente;
  final int? servicioSugerido;
  final String profesionalHabitual;
  final String alerta;
  const AgendarRapidoSheet({
    super.key,
    required this.cliente,
    this.servicioSugerido,
    this.profesionalHabitual = '',
    this.alerta = '',
  });

  @override
  State<AgendarRapidoSheet> createState() => _AgendarRapidoSheetState();
}

class _AgendarRapidoSheetState extends State<AgendarRapidoSheet> {
  final _api = CatalogoService.instance;
  List<Servicio> _servicios = [];
  List<Profesional> _profesionales = [];
  List<HorarioLaboral> _horarios = [];
  List<Cita> _reservas = [];
  Servicio? _servicio;
  int? _profesionalId;
  late final List<DateTime> _dias;
  late DateTime _dia;
  String? _hora;
  List<String> _horas = [];
  bool _cargando = true;
  bool _cargandoHoras = false;
  bool _guardando = false;
  int _consulta = 0;

  @override
  void initState() {
    super.initState();
    final hoy = DateTime.now();
    _dias = [for (var i = 0; i < 7; i++) DateTime(hoy.year, hoy.month, hoy.day + i)];
    _dia = _dias.first;
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final r = await Future.wait([
        _api.servicios(),
        _api.profesionales(),
        _api.especialidades(),
        _api.horariosLaborales().catchError((_) => <HorarioLaboral>[]),
        _api.reservas(desde: _dias.first, hasta: _dias.last),
      ]);
      final activas = {for (final e in r[2] as List<Especialidad>) if (e.activa) e.id};
      _servicios = (r[0] as List<Servicio>)
          .where((s) => s.activo && (activas.isEmpty || activas.contains(s.especialidadId)))
          .toList();
      _profesionales = (r[1] as List<Profesional>).where((p) => p.estado).toList();
      _horarios = r[3] as List<HorarioLaboral>;
      _reservas = r[4] as List<Cita>;
      for (final s in _servicios) {
        if (s.id == widget.servicioSugerido) _servicio = s;
      }
      _servicio ??= _servicios.isNotEmpty ? _servicios.first : null;
      _sugerirProfesional();
      if (mounted) setState(() => _cargando = false);
      _consultarHoras();
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _cargando = false);
        mostrarMensaje(context, e.mensaje, error: true);
      }
    }
  }

  List<Profesional> get _delServicio => _servicio == null
      ? []
      : _profesionales.where((p) => p.especialidadId == _servicio!.especialidadId).toList();

  void _sugerirProfesional() {
    _profesionalId = null;
    for (final p in _delServicio) {
      if (p.nombreCompleto == widget.profesionalHabitual) _profesionalId = p.id;
    }
  }

  Future<void> _consultarHoras() async {
    final s = _servicio;
    if (s == null) return;
    final consulta = ++_consulta;
    setState(() {
      _cargandoHoras = true;
      _hora = null;
    });
    try {
      var horas = await _api.horasDisponibles(
          fecha: _dia, servicioId: s.id, profesionalId: _profesionalId);
      horas ??= _profesionalId == null
          ? Disponibilidad.deCualquiera(
              profesionales: _delServicio.map((p) => p.id).toList(),
              dia: _dia,
              duracion: s.duracion,
              horarios: _horarios,
              reservas: _reservas)
          : Disponibilidad.deProfesional(
              profesionalId: _profesionalId!,
              dia: _dia,
              duracion: s.duracion,
              horarios: _horarios,
              reservas: _reservas);
      if (!mounted || consulta != _consulta) return;
      setState(() {
        _horas = Disponibilidad.quitarPasadas(horas!, _dia);
        _cargandoHoras = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _cargandoHoras = false);
      mostrarMensaje(context, e.mensaje, error: true);
    }
  }

  Future<void> _confirmar() async {
    if (_servicio == null || _hora == null) {
      mostrarMensaje(context, 'Selecciona el servicio y la hora.', error: true);
      return;
    }
    final p = _hora!.split(':');
    final fecha = DateTime(_dia.year, _dia.month, _dia.day, int.parse(p[0]), int.parse(p[1]));
    setState(() => _guardando = true);
    try {
      await _api.crearReserva(
        fechaHora: fecha,
        servicioId: _servicio!.id,
        clienteId: widget.cliente.id,
        profesionalId: _profesionalId,
      );
      if (!mounted) return;
      mostrarMensaje(context,
          'Cita agendada: ${Formatos.fechaLarga(_dia)} a las $_hora');
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) mostrarMensaje(context, e.mensaje, error: true);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Widget _selector<T>(String titulo, T? valor, List<DropdownMenuItem<T>> items,
      ValueChanged<T?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo,
            style: const TextStyle(
                fontSize: 11,
                letterSpacing: 0.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textoSecundario)),
        const SizedBox(height: 6),
        InputDecorator(
          decoration: const InputDecoration(
              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 4)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
                value: valor, isExpanded: true, items: items, onChanged: onChanged),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _agarre(),
          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Agendar Nueva Cita',
                      style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
                  Text('Cliente: ${widget.cliente.nombreCompleto}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
                ],
              ),
            ),
            IconButton(
              onPressed: () => Navigator.pop(context, false),
              style: IconButton.styleFrom(backgroundColor: const Color(0xFFEEF0FA)),
              icon: const Icon(Icons.close, size: 20),
            ),
          ]),
          const Divider(),
          const SizedBox(height: 10),
          if (_cargando)
            const Padding(
                padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
          else ...[
            _selector<int>(
              widget.servicioSugerido != null ? 'SERVICIO RECOMENDADO' : 'SERVICIO',
              _servicio?.id,
              [
                for (final s in _servicios)
                  DropdownMenuItem(
                      value: s.id,
                      child: Text('${s.nombre} (${s.duracion} min)',
                          overflow: TextOverflow.ellipsis)),
              ],
              (id) {
                setState(() {
                  _servicio = _servicios.firstWhere((s) => s.id == id);
                  _sugerirProfesional();
                });
                _consultarHoras();
              },
            ),
            const SizedBox(height: 12),
            _selector<int?>(
              'PROFESIONAL ASIGNADO',
              _profesionalId,
              [
                const DropdownMenuItem<int?>(value: null, child: Text('Cualquiera (automático)')),
                for (final p in _delServicio)
                  DropdownMenuItem<int?>(
                      value: p.id,
                      child: Text(p.nombreCompleto == widget.profesionalHabitual
                          ? '${p.nombreCompleto} (Habitual)'
                          : p.nombreCompleto)),
              ],
              (id) {
                setState(() => _profesionalId = id);
                _consultarHoras();
              },
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (var i = 0; i < _dias.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(i == 0
                            ? 'Hoy'
                            : i == 1
                                ? 'Mañana'
                                : '${Formatos.diaCorto(_dias[i])} ${_dias[i].day}'),
                        selected: _dia == _dias[i],
                        showCheckmark: false,
                        selectedColor: AppColors.primarioSuave,
                        onSelected: (_) {
                          setState(() => _dia = _dias[i]);
                          _consultarHoras();
                        },
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            if (_cargandoHoras)
              const Padding(
                  padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator()))
            else if (_horas.isEmpty)
              const Text('No hay horarios disponibles ese día.',
                  style: TextStyle(color: AppColors.textoSecundario))
            else
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final h in _horas)
                  ChoiceChip(
                    label: Text(h),
                    selected: _hora == h,
                    showCheckmark: false,
                    selectedColor: AppColors.primario,
                    labelStyle: TextStyle(
                        color: _hora == h ? Colors.white : AppColors.texto,
                        fontWeight: FontWeight.w600),
                    onSelected: (_) => setState(() => _hora = h),
                  ),
              ]),
            if (widget.alerta.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(children: [
                  const Icon(Icons.info_outline, size: 18, color: AppColors.alerta),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Recordatorio: ${widget.alerta}',
                        style: const TextStyle(fontSize: 12, color: AppColors.alerta)),
                  ),
                ]),
              ),
            ],
          ],
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _guardando ? null : () => Navigator.pop(context, false),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                child: const Text('Cancelar'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _guardando || _cargando ? null : _confirmar,
                child: _guardando ? const CargandoBoton() : const Text('Confirmar en agenda'),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}
