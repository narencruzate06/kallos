import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/catalogos.dart';
import '../services/api_client.dart';
import '../services/catalogo_service.dart';
import '../theme/app_colors.dart';
import '../utils/formatos.dart';
import '../widgets/comunes.dart';
import '../widgets/formularios.dart';

class EspecialidadFormScreen extends StatefulWidget {
  final Especialidad? especialidad;
  const EspecialidadFormScreen({super.key, this.especialidad});

  @override
  State<EspecialidadFormScreen> createState() => _EspecialidadFormScreenState();
}

class _EspecialidadFormScreenState extends State<EspecialidadFormScreen> {
  final _api = CatalogoService.instance;
  final _formKey = GlobalKey<FormState>();
  late final _nombre = TextEditingController(text: widget.especialidad?.nombre ?? '');
  late bool _activa = widget.especialidad?.activa ?? true;

  final _nuevoNombre = TextEditingController();
  final _nuevoMin = TextEditingController();
  final _nuevaTarifa = TextEditingController();

  List<Servicio> _servicios = [];
  List<Profesional> _profesionales = [];
  List<Especialidad> _especialidades = [];
  bool _cargando = true;
  bool _guardando = false;
  bool _agregando = false;
  bool _huboCambios = false;

  bool get _esNueva => widget.especialidad == null;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    for (final c in [_nombre, _nuevoNombre, _nuevoMin, _nuevaTarifa]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _cargar() async {
    if (_esNueva) {
      setState(() => _cargando = false);
      return;
    }
    try {
      final r = await Future.wait([_api.servicios(), _api.profesionales(), _api.especialidades()]);
      if (!mounted) return;
      final id = widget.especialidad!.id;
      setState(() {
        _servicios = (r[0] as List<Servicio>).where((s) => s.especialidadId == id).toList();
        _profesionales =
            (r[1] as List<Profesional>).where((p) => p.especialidadId == id).toList();
        _especialidades = r[2] as List<Especialidad>;
      });
    } on ApiException catch (e) {
      if (mounted) mostrarMensaje(context, e.mensaje, error: true);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _guardar() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _guardando = true);
    try {
      if (_esNueva) {
        await _api.crearEspecialidad(_nombre.text);
      } else {
        await _api.actualizarEspecialidad(widget.especialidad!.id, _nombre.text, _activa);
      }
      if (!mounted) return;
      mostrarMensaje(context, _esNueva ? 'Especialidad creada' : 'Especialidad guardada');
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) mostrarMensaje(context, e.mensaje, error: true);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _insertarServicio() async {
    final nombre = _nuevoNombre.text.trim();
    final min = int.tryParse(_nuevoMin.text.trim());
    final tarifa = int.tryParse(_nuevaTarifa.text.trim());
    String? error;
    if (nombre.length < 3) {
      error = 'Escribe el nombre del servicio (mínimo 3 letras).';
    } else if (min == null || min < 10 || min > 480) {
      error = 'La duración debe estar entre 10 y 480 minutos.';
    } else if (tarifa == null || tarifa < 1000) {
      error = 'La tarifa debe ser de al menos \$1.000.';
    }
    if (error != null) {
      mostrarMensaje(context, error, error: true);
      return;
    }
    setState(() => _agregando = true);
    try {
      await _api.crearServicio(Servicio(
        id: 0,
        nombre: nombre,
        descripcion: '',
        precio: tarifa!.toDouble(),
        duracion: min!,
        activo: true,
        especialidadId: widget.especialidad!.id,
      ));
      _nuevoNombre.clear();
      _nuevoMin.clear();
      _nuevaTarifa.clear();
      _huboCambios = true;
      if (!mounted) return;
      mostrarMensaje(context, 'Servicio "$nombre" añadido');
      await _cargar();
    } on ApiException catch (e) {
      if (mounted) mostrarMensaje(context, e.mensaje, error: true);
    } finally {
      if (mounted) setState(() => _agregando = false);
    }
  }

  Future<void> _menuServicio(Servicio s, String accion) async {
    switch (accion) {
      case 'editar':
        final ok = await abrirFormulario<bool>(
            context, ServicioFormSheet(servicio: s, especialidades: _especialidades));
        if (ok == true) {
          _huboCambios = true;
          _cargar();
        }
      case 'estado':
        try {
          await _api.actualizarServicio(s.copyWith(activo: !s.activo));
          _huboCambios = true;
          _cargar();
        } on ApiException catch (e) {
          if (mounted) mostrarMensaje(context, e.mensaje, error: true);
        }
      case 'eliminar':
        final seguro = await confirmar(context,
            titulo: 'Eliminar servicio',
            mensaje: '¿Eliminar "${s.nombre}"? Las reservas pasadas conservan su registro.',
            textoAceptar: 'Eliminar',
            peligroso: true);
        if (!seguro) return;
        try {
          await _api.eliminarServicio(s.id);
          _huboCambios = true;
          _cargar();
        } on ApiException catch (e) {
          if (mounted) mostrarMensaje(context, e.mensaje, error: true);
        }
    }
  }

  Future<void> _eliminar() async {
    final e = widget.especialidad!;
    final ok = await confirmar(context,
        titulo: 'Eliminar especialidad',
        mensaje: _servicios.isEmpty && _profesionales.isEmpty
            ? '¿Eliminar "${e.nombre}"?'
            : '"${e.nombre}" tiene ${_servicios.length} servicio(s) y '
                '${_profesionales.length} profesional(es). Si la API no lo permite, '
                'muévelos primero a otra especialidad. ¿Intentar eliminar?',
        textoAceptar: 'Eliminar',
        peligroso: true);
    if (!ok || !mounted) return;
    setState(() => _guardando = true);
    try {
      await _api.eliminarEspecialidad(e.id);
      if (!mounted) return;
      mostrarMensaje(context, '"${e.nombre}" fue eliminada');
      Navigator.pop(context, true);
    } on ApiException catch (err) {
      if (mounted) mostrarMensaje(context, err.mensaje, error: true);
    } finally {
      if (mounted) setState(() => _guardando = false);
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
          title: Text(_esNueva ? 'Nueva especialidad' : 'Editar especialidad',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider()),
        ),
        body: _cargando
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    _datosPrincipales(),
                    if (!_esNueva) ...[
                      const SizedBox(height: 14),
                      _equipo(),
                      const SizedBox(height: 14),
                      _serviciosSeccion(),
                      const SizedBox(height: 14),
                      _zonaPeligro(),
                    ] else
                      const Padding(
                        padding: EdgeInsets.only(top: 14),
                        child: Text(
                            'Después de crearla podrás añadirle servicios desde el catálogo.',
                            style: TextStyle(color: AppColors.textoSecundario)),
                      ),
                  ],
                ),
              ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            decoration: const BoxDecoration(
                color: AppColors.superficie,
                border: Border(top: BorderSide(color: AppColors.borde))),
            child: Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _guardando ? null : () => Navigator.pop(context, _huboCambios),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  child: const Text('Descartar'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _guardando ? null : _guardar,
                  icon: _guardando
                      ? const CargandoBoton()
                      : const Icon(Icons.check_circle_outline, size: 20),
                  label: Text(_esNueva ? 'Crear especialidad' : 'Guardar cambios'),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _datosPrincipales() => TarjetaKallos(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              CircleAvatar(radius: 5, backgroundColor: AppColors.primario),
              SizedBox(width: 8),
              Expanded(
                child: Text('Datos Principales',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
              TextoAyuda('Requerido'),
            ]),
            const SizedBox(height: 12),
            const Text('Nombre de la especialidad', style: TextStyle(fontSize: 13)),
            const SizedBox(height: 6),
            TextFormField(
              controller: _nombre,
              textCapitalization: TextCapitalization.words,
              inputFormatters: [LengthLimitingTextInputFormatter(60)],
              validator: (v) =>
                  (v ?? '').trim().length < 3 ? 'Escribe un nombre de al menos 3 letras' : null,
              decoration: const InputDecoration(
                hintText: 'Ej: Peluquería & Color',
                suffixIcon: Icon(Icons.edit_outlined, size: 18),
              ),
            ),
            if (!_esNueva) ...[
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _activa,
                title: const Text('Activa en agenda',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Si la pausas, sus servicios no se pueden reservar.'),
                onChanged: (v) => setState(() => _activa = v),
              ),
            ],
          ],
        ),
      );

  Widget _equipo() => TarjetaKallos(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Equipo Habilitado',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    Text('Profesionales de esta especialidad',
                        style: TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
                  ],
                ),
              ),
              Etiqueta(
                  texto: '${_profesionales.length} asignados',
                  fondo: AppColors.exitoSuave,
                  color: AppColors.exito),
            ]),
            const SizedBox(height: 8),
            if (_profesionales.isEmpty)
              const Text('Ningún profesional tiene esta especialidad todavía.',
                  style: TextStyle(color: AppColors.textoSecundario)),
            for (final p in _profesionales)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  AvatarIniciales(p.nombreCompleto, radio: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.nombreCompleto, style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text('Comisión ${p.porcentaje.toStringAsFixed(0)}%',
                            style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
                      ],
                    ),
                  ),
                  Etiqueta(
                    texto: p.estado ? 'Activo' : 'En pausa',
                    fondo: p.estado ? AppColors.exitoSuave : AppColors.neutroSuave,
                    color: p.estado ? AppColors.exito : AppColors.neutro,
                  ),
                ]),
              ),
            const SizedBox(height: 4),
            const Text('Para cambiar la especialidad de un profesional, edita su ficha en Equipo.',
                style: TextStyle(fontSize: 11, color: AppColors.textoTenue)),
          ],
        ),
      );

  Widget _serviciosSeccion() {
    final activos = _servicios.where((s) => s.activo).length;
    return TarjetaKallos(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Servicios en esta Especialidad',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  Text('Duración y tarifa base',
                      style: TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
                ],
              ),
            ),
            TextoAyuda('$activos activos'),
          ]),
          const SizedBox(height: 10),
          for (final s in _servicios)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.fromLTRB(12, 8, 0, 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.borde),
              ),
              child: Opacity(
                opacity: s.activo ? 1 : 0.5,
                child: Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.nombre + (s.activo ? '' : ' (inactivo)'),
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        Row(children: [
                          const Icon(Icons.schedule, size: 13, color: AppColors.textoSecundario),
                          const SizedBox(width: 3),
                          Text('${s.duracion} min  ·  ',
                              style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
                          Text(Formatos.moneda(s.precio),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        ]),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (a) => _menuServicio(s, a),
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'editar', child: Text('Editar')),
                      PopupMenuItem(
                          value: 'estado', child: Text(s.activo ? 'Desactivar' : 'Activar')),
                      const PopupMenuItem(
                          value: 'eliminar',
                          child: Text('Eliminar', style: TextStyle(color: AppColors.error))),
                    ],
                  ),
                ]),
              ),
            ),
          const SizedBox(height: 4),
          CustomPaint(
            painter: _Punteado(),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('AÑADIR SERVICIO RÁPIDO',
                      style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 0.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textoSecundario)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nuevoNombre,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(hintText: 'Nombre del servicio...'),
                  ),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _nuevoMin,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(3)
                        ],
                        decoration: const InputDecoration(hintText: 'Min', suffixText: 'min'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _nuevaTarifa,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(8)
                        ],
                        decoration: const InputDecoration(hintText: 'Tarifa', prefixText: '\$ '),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _agregando ? null : _insertarServicio,
                      style: TextButton.styleFrom(backgroundColor: const Color(0xFFEEF0FA)),
                      icon: _agregando
                          ? const CargandoBoton(color: AppColors.primario)
                          : const Icon(Icons.add, size: 18),
                      label: const Text('Insertar servicio'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _zonaPeligro() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.superficie,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFECACA)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: AppColors.errorSuave, borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.warning_amber_rounded, color: AppColors.error),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Zona de peligro',
                      style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                      'Al eliminar esta especialidad se quita del catálogo. Tiene '
                      '${_servicios.length} servicio(s) vinculados.',
                      style: const TextStyle(fontSize: 13, color: AppColors.textoSecundario)),
                  TextButton.icon(
                    onPressed: _guardando ? null : _eliminar,
                    style: TextButton.styleFrom(
                        foregroundColor: AppColors.error, padding: EdgeInsets.zero),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Eliminar esta especialidad'),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _Punteado extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.textoTenue
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)));
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, d + 5), paint);
        d += 10;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
