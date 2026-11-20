import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/catalogos.dart';
import '../services/api_client.dart';
import '../services/catalogo_service.dart';
import '../theme/app_colors.dart';
import '../utils/formatos.dart';
import '../utils/validadores.dart';
import 'comunes.dart';

Future<T?> abrirFormulario<T>(BuildContext context, Widget formulario) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.superficie,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: formulario,
    ),
  );
}

class _HojaFormulario extends StatelessWidget {
  final String titulo;
  final String? subtitulo;
  final GlobalKey<FormState> formKey;
  final List<Widget> campos;
  final String textoBoton;
  final bool guardando;
  final String? error;
  final VoidCallback onGuardar;

  const _HojaFormulario({
    required this.titulo,
    this.subtitulo,
    required this.formKey,
    required this.campos,
    required this.textoBoton,
    required this.guardando,
    required this.error,
    required this.onGuardar,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
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
                    borderRadius: BorderRadius.circular(4)),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(titulo,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700)),
                ),
                IconButton(
                  onPressed: guardando ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            if (subtitulo != null)
              Text(subtitulo!,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textoSecundario)),
            const SizedBox(height: 14),
            ...campos,
            if (error != null) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: AppColors.errorSuave,
                    borderRadius: BorderRadius.circular(8)),
                child: Text(error!,
                    style:
                        const TextStyle(color: AppColors.error, fontSize: 13)),
              ),
            ],
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: guardando ? null : onGuardar,
              child: guardando ? const CargandoBoton() : Text(textoBoton),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _campo(String etiqueta, Widget campo) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(etiqueta, style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 6),
          campo,
        ],
      ),
    );

class _CampoFecha extends StatelessWidget {
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final DateTime primera;
  final DateTime ultima;
  final DateTime inicial;
  const _CampoFecha({
    required this.controller,
    required this.primera,
    required this.ultima,
    required this.inicial,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      validator: validator,
      decoration: const InputDecoration(
        hintText: 'AAAA-MM-DD',
        prefixIcon: Icon(Icons.cake_outlined, size: 20),
      ),
      onTap: () async {
        final actual = DateTime.tryParse(controller.text);
        final f = await showDatePicker(
          context: context,
          initialDate: actual ?? inicial,
          firstDate: primera,
          lastDate: ultima,
          helpText: 'Fecha de nacimiento',
        );
        if (f != null) controller.text = Formatos.fechaApi(f);
      },
    );
  }
}

class ClienteFormSheet extends StatefulWidget {
  final String documentoInicial;
  final Cliente? cliente;
  const ClienteFormSheet({super.key, this.documentoInicial = '', this.cliente});

  @override
  State<ClienteFormSheet> createState() => _ClienteFormSheetState();
}

class _ClienteFormSheetState extends State<ClienteFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _editando = widget.cliente != null;
  late final _documento = TextEditingController(
      text: widget.cliente?.documento ?? widget.documentoInicial);
  late final _nombres = TextEditingController(text: widget.cliente?.nombres ?? '');
  late final _apellidos = TextEditingController(text: widget.cliente?.apellidos ?? '');
  late final _nacimiento =
      TextEditingController(text: widget.cliente?.fechaNacimiento ?? '');
  late final _celular = TextEditingController(text: widget.cliente?.celular ?? '');
  late final _correo = TextEditingController(text: widget.cliente?.correo ?? '');
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_documento, _nombres, _apellidos, _nacimiento, _celular, _correo]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _guardando = true;
      _error = null;
    });
    final datos = Cliente(
      id: widget.cliente?.id ?? 0,
      documento: _documento.text.trim(),
      nombres: _nombres.text.trim(),
      apellidos: _apellidos.text.trim(),
      fechaNacimiento: _nacimiento.text.trim(),
      celular: _celular.text.trim(),
      correo: _correo.text.trim(),
    );
    try {
      final Cliente cliente;
      if (_editando) {
        await CatalogoService.instance.actualizarCliente(datos);
        cliente = datos;
      } else {
        cliente = await CatalogoService.instance.crearCliente(datos);
      }
      if (mounted) Navigator.pop(context, cliente);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hoy = DateTime.now();
    return _HojaFormulario(
      titulo: _editando ? 'Editar cliente' : 'Nuevo cliente',
      subtitulo: _editando
          ? 'El documento no se puede modificar.'
          : 'Se guardará en el directorio de clientes de Kallos.',
      formKey: _formKey,
      guardando: _guardando,
      error: _error,
      textoBoton: _editando ? 'Guardar cambios' : 'Guardar cliente',
      onGuardar: _guardar,
      campos: [
        _campo(
            'Documento *',
            TextFormField(
              controller: _documento,
              readOnly: _editando,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(12)
              ],
              validator: Validadores.documento,
              decoration: InputDecoration(
                  hintText: 'Ej: 1102345678',
                  filled: true,
                  fillColor: _editando ? AppColors.neutroSuave : AppColors.superficie,
                  prefixIcon: const Icon(Icons.badge_outlined, size: 20)),
            )),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _campo(
                  'Nombres *',
                  TextFormField(
                    controller: _nombres,
                    textCapitalization: TextCapitalization.words,
                    validator: (v) => Validadores.nombre(v, 'El nombre'),
                    decoration: const InputDecoration(hintText: 'María'),
                  )),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _campo(
                  'Apellidos *',
                  TextFormField(
                    controller: _apellidos,
                    textCapitalization: TextCapitalization.words,
                    validator: (v) => Validadores.nombre(v, 'El apellido'),
                    decoration: const InputDecoration(hintText: 'García'),
                  )),
            ),
          ],
        ),
        _campo(
            'Celular *',
            TextFormField(
              controller: _celular,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10)
              ],
              validator: Validadores.celular,
              decoration: const InputDecoration(
                  hintText: '3001234567',
                  prefixIcon: Icon(Icons.phone_outlined, size: 20)),
            )),
        _campo(
            'Correo electrónico',
            TextFormField(
              controller: _correo,
              keyboardType: TextInputType.emailAddress,
              validator: Validadores.emailOpcional,
              decoration: const InputDecoration(
                  hintText: 'cliente@correo.com',
                  prefixIcon: Icon(Icons.mail_outline, size: 20)),
            )),
        if (!_editando)
          _campo(
              'Fecha de nacimiento',
              _CampoFecha(
                controller: _nacimiento,
                primera: DateTime(hoy.year - 100),
                ultima: hoy,
                inicial: DateTime(hoy.year - 25),
              )),
      ],
    );
  }
}

class ProfesionalFormSheet extends StatefulWidget {
  final Profesional? profesional;
  final List<Especialidad> especialidades;
  const ProfesionalFormSheet(
      {super.key, this.profesional, required this.especialidades});

  @override
  State<ProfesionalFormSheet> createState() => _ProfesionalFormSheetState();
}

class _ProfesionalFormSheetState extends State<ProfesionalFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final p = widget.profesional;
  late final _documento = TextEditingController(text: p?.documento ?? '');
  late final _nombres = TextEditingController(text: p?.nombres ?? '');
  late final _apellidos = TextEditingController(text: p?.apellidos ?? '');
  late final _nacimiento = TextEditingController(text: p?.fechaNacimiento ?? '');
  late final _porcentaje = TextEditingController(
      text: p == null ? '' : p!.porcentaje.toStringAsFixed(0));
  late int? _especialidad = widget.especialidades.any((e) => e.id == p?.especialidadId)
      ? p!.especialidadId
      : null;
  late bool _activo = p?.estado ?? true;
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_documento, _nombres, _apellidos, _nacimiento, _porcentaje]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _guardando = true;
      _error = null;
    });
    final datos = Profesional(
      id: p?.id ?? 0,
      documento: _documento.text.trim(),
      nombres: _nombres.text.trim(),
      apellidos: _apellidos.text.trim(),
      fechaNacimiento: _nacimiento.text.trim(),
      porcentaje: double.parse(_porcentaje.text.trim().replaceAll(',', '.')),
      estado: _activo,
      especialidadId: _especialidad!,
      especialidad: '',
    );
    try {
      if (p == null) {
        await CatalogoService.instance.crearProfesional(datos);
      } else {
        await CatalogoService.instance.actualizarProfesional(datos);
      }
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hoy = DateTime.now();
    return _HojaFormulario(
      titulo: p == null ? 'Añadir profesional' : 'Editar ficha',
      subtitulo: p == null ? 'Registra un nuevo especialista del equipo.' : p!.nombreCompleto,
      formKey: _formKey,
      guardando: _guardando,
      error: _error,
      textoBoton: p == null ? 'Registrar profesional' : 'Guardar cambios',
      onGuardar: _guardar,
      campos: [
        _campo(
            'Documento *',
            TextFormField(
              controller: _documento,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(12)
              ],
              validator: Validadores.documento,
              decoration: const InputDecoration(
                  hintText: 'Ej: 1102345678',
                  prefixIcon: Icon(Icons.badge_outlined, size: 20)),
            )),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _campo(
                  'Nombres *',
                  TextFormField(
                    controller: _nombres,
                    textCapitalization: TextCapitalization.words,
                    validator: (v) => Validadores.nombre(v, 'El nombre'),
                  )),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _campo(
                  'Apellidos *',
                  TextFormField(
                    controller: _apellidos,
                    textCapitalization: TextCapitalization.words,
                    validator: (v) => Validadores.nombre(v, 'El apellido'),
                  )),
            ),
          ],
        ),
        _campo(
            'Especialidad *',
            FormField<int>(
              initialValue: _especialidad,
              validator: (v) => v == null ? 'Selecciona una especialidad' : null,
              builder: (campo) => InputDecorator(
                decoration: InputDecoration(
                  errorText: campo.errorText,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: campo.value,
                    isExpanded: true,
                    hint: const Text('Selecciona una especialidad'),
                    items: [
                      for (final e in widget.especialidades)
                        DropdownMenuItem(value: e.id, child: Text(e.nombre)),
                    ],
                    onChanged: (v) {
                      campo.didChange(v);
                      setState(() => _especialidad = v);
                    },
                  ),
                ),
              ),
            )),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _campo(
                  'Fecha de nacimiento *',
                  _CampoFecha(
                    controller: _nacimiento,
                    primera: DateTime(hoy.year - 80),
                    ultima: DateTime(hoy.year - 18, hoy.month, hoy.day),
                    inicial: DateTime(hoy.year - 28),
                    validator: (v) =>
                        Validadores.requerido(v, 'La fecha de nacimiento'),
                  )),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _campo(
                  'Comisión (%) *',
                  TextFormField(
                    controller: _porcentaje,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                      LengthLimitingTextInputFormatter(5)
                    ],
                    validator: Validadores.porcentaje,
                    decoration: const InputDecoration(
                        hintText: '35',
                        prefixIcon: Icon(Icons.percent, size: 18)),
                  )),
            ),
          ],
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _activo,
          title: const Text('Activo (en turno)'),
          subtitle: Text(_activo
              ? 'Puede recibir reservas'
              : 'En pausa: no recibe reservas'),
          onChanged: (v) => setState(() => _activo = v),
        ),
      ],
    );
  }
}

class HorarioFormSheet extends StatefulWidget {
  final Profesional profesional;
  const HorarioFormSheet({super.key, required this.profesional});

  @override
  State<HorarioFormSheet> createState() => _HorarioFormSheetState();
}

class _HorarioFormSheetState extends State<HorarioFormSheet> {
  final _formKey = GlobalKey<FormState>();
  static const _dias = [(1, 'Lun'), (2, 'Mar'), (3, 'Mié'), (4, 'Jue'), (5, 'Vie'), (6, 'Sáb'), (0, 'Dom')];
  final Set<int> _seleccion = {1, 2, 3, 4, 5, 6};
  TimeOfDay _inicio = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _fin = const TimeOfDay(hour: 18, minute: 0);
  bool _almuerzo = true;
  TimeOfDay _iniAlm = const TimeOfDay(hour: 12, minute: 0);
  TimeOfDay _finAlm = const TimeOfDay(hour: 13, minute: 0);
  bool _guardando = false;
  String? _error;

  int _m(TimeOfDay t) => t.hour * 60 + t.minute;
  String _api(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';
  String _ver(TimeOfDay t) => _api(t).substring(0, 5);

  String? _validar() {
    if (_seleccion.isEmpty) return 'Selecciona al menos un día.';
    if (_m(_fin) <= _m(_inicio)) return 'La hora de salida debe ser después de la de entrada.';
    if (_m(_fin) - _m(_inicio) < 60) return 'La jornada debe ser de al menos 1 hora.';
    if (_almuerzo) {
      if (_m(_finAlm) <= _m(_iniAlm)) return 'El fin del almuerzo debe ser después del inicio.';
      if (_m(_iniAlm) < _m(_inicio) || _m(_finAlm) > _m(_fin)) {
        return 'El almuerzo debe estar dentro de la jornada.';
      }
    }
    return null;
  }

  Future<void> _elegir(TimeOfDay actual, ValueChanged<TimeOfDay> asignar) async {
    final t = await showTimePicker(context: context, initialTime: actual);
    if (t != null) setState(() => asignar(t));
  }

  Future<void> _guardar() async {
    final e = _validar();
    if (e != null) return setState(() => _error = e);
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await ApiClient.instance.post('/horarios-laboral/masivo', body: {
        'profesionalId': widget.profesional.id,
        'dias': _seleccion.toList()..sort(),
        'horaInicio': _api(_inicio),
        'horaFin': _api(_fin),
        'tieneAlmuerzo': _almuerzo,
        if (_almuerzo) 'horaInicioAlmuerzo': _api(_iniAlm),
        if (_almuerzo) 'horaFinAlmuerzo': _api(_finAlm),
      });
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Widget _hora(String etiqueta, TimeOfDay valor, ValueChanged<TimeOfDay> asignar) {
    return Expanded(
      child: _campo(
        etiqueta,
        OutlinedButton.icon(
          onPressed: () => _elegir(valor, asignar),
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
          icon: const Icon(Icons.schedule, size: 18),
          label: Text(_ver(valor)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _HojaFormulario(
      titulo: 'Configurar horario',
      subtitulo: widget.profesional.nombreCompleto,
      formKey: _formKey,
      guardando: _guardando,
      error: _error,
      textoBoton: 'Guardar horario',
      onGuardar: _guardar,
      campos: [
        _campo(
          'Días de trabajo',
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final d in _dias)
                FilterChip(
                  label: Text(d.$2),
                  selected: _seleccion.contains(d.$1),
                  selectedColor: AppColors.primarioSuave,
                  checkmarkColor: AppColors.primario,
                  onSelected: (v) => setState(
                      () => v ? _seleccion.add(d.$1) : _seleccion.remove(d.$1)),
                ),
            ],
          ),
        ),
        Row(children: [
          _hora('Entrada', _inicio, (t) => _inicio = t),
          const SizedBox(width: 10),
          _hora('Salida', _fin, (t) => _fin = t),
        ]),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _almuerzo,
          title: const Text('Tiene almuerzo'),
          onChanged: (v) => setState(() => _almuerzo = v),
        ),
        if (_almuerzo)
          Row(children: [
            _hora('Inicio almuerzo', _iniAlm, (t) => _iniAlm = t),
            const SizedBox(width: 10),
            _hora('Fin almuerzo', _finAlm, (t) => _finAlm = t),
          ]),
      ],
    );
  }
}

class ServicioFormSheet extends StatefulWidget {
  final Servicio? servicio;
  final List<Especialidad> especialidades;
  final int? especialidadInicial;
  const ServicioFormSheet(
      {super.key,
      this.servicio,
      required this.especialidades,
      this.especialidadInicial});

  @override
  State<ServicioFormSheet> createState() => _ServicioFormSheetState();
}

class _ServicioFormSheetState extends State<ServicioFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _s = widget.servicio;
  late final _nombre = TextEditingController(text: _s?.nombre ?? '');
  late final _descripcion = TextEditingController(text: _s?.descripcion ?? '');
  late final _duracion =
      TextEditingController(text: _s == null ? '' : '${_s.duracion}');
  late final _precio =
      TextEditingController(text: _s == null ? '' : _s.precio.toStringAsFixed(0));
  late int? _especialidad = _s?.especialidadId ?? widget.especialidadInicial;
  late bool _activo = _s?.activo ?? true;
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_nombre, _descripcion, _duracion, _precio]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _guardando = true;
      _error = null;
    });
    final datos = Servicio(
      id: _s?.id ?? 0,
      nombre: _nombre.text.trim(),
      descripcion: _descripcion.text.trim(),
      precio: double.parse(_precio.text.trim()),
      duracion: int.parse(_duracion.text.trim()),
      activo: _activo,
      especialidadId: _especialidad!,
    );
    try {
      if (_s == null) {
        await CatalogoService.instance.crearServicio(datos);
      } else {
        await CatalogoService.instance.actualizarServicio(datos);
      }
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _HojaFormulario(
      titulo: _s == null ? 'Nuevo servicio' : 'Editar servicio',
      formKey: _formKey,
      guardando: _guardando,
      error: _error,
      textoBoton: _s == null ? 'Crear servicio' : 'Guardar cambios',
      onGuardar: _guardar,
      campos: [
        _campo(
            'Nombre del servicio *',
            TextFormField(
              controller: _nombre,
              textCapitalization: TextCapitalization.sentences,
              inputFormatters: [LengthLimitingTextInputFormatter(80)],
              validator: (v) => (v ?? '').trim().length < 3
                  ? 'Escribe un nombre de al menos 3 letras'
                  : null,
              decoration: const InputDecoration(hintText: 'Ej: Corte & Barba Ritual'),
            )),
        _campo(
            'Descripción',
            TextFormField(
              controller: _descripcion,
              maxLines: 2,
              inputFormatters: [LengthLimitingTextInputFormatter(150)],
              decoration: const InputDecoration(
                  hintText: 'Qué incluye el servicio (opcional)'),
            )),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _campo(
                  'Duración (min) *',
                  TextFormField(
                    controller: _duracion,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(3)
                    ],
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      if (n == null) return 'Obligatorio';
                      if (n < 10 || n > 480) return 'Entre 10 y 480 min';
                      return null;
                    },
                    decoration: const InputDecoration(
                        hintText: '45', prefixIcon: Icon(Icons.schedule, size: 18)),
                  )),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _campo(
                  'Tarifa (COP) *',
                  TextFormField(
                    controller: _precio,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(8)
                    ],
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      if (n == null) return 'Obligatorio';
                      if (n < 1000) return 'Mínimo \$1.000';
                      return null;
                    },
                    decoration: const InputDecoration(
                        hintText: '45000', prefixIcon: Icon(Icons.attach_money, size: 18)),
                  )),
            ),
          ],
        ),
        _campo(
            'Especialidad *',
            FormField<int>(
              initialValue: _especialidad,
              validator: (v) => v == null ? 'Selecciona una especialidad' : null,
              builder: (campo) => InputDecorator(
                decoration: InputDecoration(
                  errorText: campo.errorText,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: campo.value,
                    isExpanded: true,
                    hint: const Text('Selecciona una especialidad'),
                    items: [
                      for (final e in widget.especialidades)
                        DropdownMenuItem(value: e.id, child: Text(e.nombre)),
                    ],
                    onChanged: (v) {
                      campo.didChange(v);
                      setState(() => _especialidad = v);
                    },
                  ),
                ),
              ),
            )),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _activo,
          title: const Text('Servicio activo'),
          subtitle: Text(_activo
              ? 'Se puede reservar'
              : 'Oculto: no aparece al crear reservas'),
          onChanged: (v) => setState(() => _activo = v),
        ),
      ],
    );
  }
}
