import 'package:flutter/material.dart';

import '../models/catalogos.dart';
import '../services/api_client.dart';
import '../services/catalogo_service.dart';
import '../theme/app_colors.dart';
import '../utils/formatos.dart';
import '../widgets/comunes.dart';
import '../widgets/formularios.dart';
import 'especialidad_form_screen.dart';

class EspecialidadesScreen extends StatefulWidget {
  const EspecialidadesScreen({super.key});

  @override
  State<EspecialidadesScreen> createState() => _EspecialidadesScreenState();
}

class _EspecialidadesScreenState extends State<EspecialidadesScreen> {
  final _api = CatalogoService.instance;
  final _busqueda = TextEditingController();

  bool _cargando = true;
  String? _error;
  List<Especialidad> _especialidades = [];
  List<Servicio> _servicios = [];
  List<Profesional> _profesionales = [];
  final Set<int> _cerradas = {};
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
      if (_especialidades.isEmpty) _cargando = true;
    });
    try {
      final r = await Future.wait([
        _api.especialidades(),
        _api.servicios(),
        _api.profesionales(),
      ]);
      if (!mounted) return;
      setState(() {
        _especialidades = (r[0] as List<Especialidad>)
          ..sort((a, b) {
            if (a.activa != b.activa) return a.activa ? -1 : 1;
            return a.nombre.compareTo(b.nombre);
          });
        _servicios = r[1] as List<Servicio>;
        _profesionales = r[2] as List<Profesional>;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  List<Servicio> _serviciosDe(Especialidad e) =>
      _servicios.where((s) => s.especialidadId == e.id).toList();

  List<Profesional> _profesionalesDe(Especialidad e) =>
      _profesionales.where((p) => p.especialidadId == e.id && p.estado).toList();

  List<Especialidad> get _visibles {
    final q = _busqueda.text.trim().toLowerCase();
    if (q.isEmpty) return _especialidades;
    return _especialidades
        .where((e) =>
            e.nombre.toLowerCase().contains(q) ||
            _serviciosDe(e).any((s) => s.nombre.toLowerCase().contains(q)))
        .toList();
  }

  Future<void> _abrirFormulario([Especialidad? e]) async {
    final ok = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => EspecialidadFormScreen(especialidad: e)));
    if (ok == true) _cargar();
  }

  Future<void> _formServicio(Especialidad e, [Servicio? s]) async {
    final ok = await abrirFormulario<bool>(
        context,
        ServicioFormSheet(
            servicio: s, especialidades: _especialidades, especialidadInicial: e.id));
    if (ok == true && mounted) {
      mostrarMensaje(context, s == null ? 'Servicio creado' : 'Servicio actualizado');
      _cargar();
    }
  }

  Future<void> _pausar(Especialidad e) async {
    setState(() => _procesando.add(e.id));
    try {
      await _api.actualizarEspecialidad(e.id, e.nombre, !e.activa);
      if (!mounted) return;
      mostrarMensaje(context,
          e.activa ? '${e.nombre} quedó en pausa' : '${e.nombre} está activa de nuevo');
      await _cargar();
    } on ApiException catch (err) {
      if (mounted) mostrarMensaje(context, err.mensaje, error: true);
    } finally {
      if (mounted) setState(() => _procesando.remove(e.id));
    }
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
          IconButton(onPressed: _cargar, icon: const Icon(Icons.refresh), tooltip: 'Actualizar'),
        ],
        bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider()),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _especialidades.isEmpty
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
    );
  }

  Widget _contenido() {
    final activas = _especialidades.where((e) => e.activa).length;
    final serviciosActivos = _servicios.where((s) => s.activo).toList();
    final precioMedio = serviciosActivos.isEmpty
        ? 0.0
        : serviciosActivos.fold<double>(0, (t, s) => t + s.precio) / serviciosActivos.length;
    final visibles = _visibles;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        const Text.rich(TextSpan(children: [
          TextSpan(text: 'Configuración / ', style: TextStyle(color: AppColors.textoSecundario)),
          TextSpan(
              text: 'Especialidades',
              style: TextStyle(color: AppColors.primario, fontWeight: FontWeight.w600)),
        ]), style: TextStyle(fontSize: 13)),
        const SizedBox(height: 4),
        const Text('Especialidades & Servicios',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
        const Text('Catálogo y tarifas del centro',
            style: TextStyle(color: AppColors.textoSecundario)),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _kpi('Categorías', '${_especialidades.length}', '$activas act.')),
          const SizedBox(width: 8),
          Expanded(child: _kpi('Servicios', '${serviciosActivos.length}', 'Activos')),
          const SizedBox(width: 8),
          Expanded(child: _kpi('Precio medio', Formatos.moneda(precioMedio), null)),
        ]),
        const SizedBox(height: 14),
        TextField(
          controller: _busqueda,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            hintText: 'Buscar categoría o servicio...',
            prefixIcon: Icon(Icons.search, size: 20),
          ),
        ),
        const SizedBox(height: 8),
        Text('Mostrando ${visibles.length} especialidades registradas',
            style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
        const SizedBox(height: 12),
        for (final e in visibles) ...[
          e.activa ? _tarjeta(e) : _tarjetaPausada(e),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 8),
        Center(
          child: OutlinedButton.icon(
            onPressed: () => _abrirFormulario(),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 50),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              shape: const StadiumBorder(),
            ),
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('Crear Especialidad'),
          ),
        ),
      ],
    );
  }

  Widget _kpi(String titulo, String valor, String? etiqueta) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.superficie,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borde),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
            if (etiqueta != null) ...[
              const SizedBox(height: 2),
              Etiqueta(texto: etiqueta, fondo: AppColors.exitoSuave, color: AppColors.exito),
            ],
            const SizedBox(height: 4),
            FittedBox(
              child: Text(valor,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );

  Widget _tarjeta(Especialidad e) {
    final servicios = _serviciosDe(e);
    final profesionales = _profesionalesDe(e);
    final abierta = !_cerradas.contains(e.id);
    return TarjetaKallos(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 4, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                      color: const Color(0xFFEEF0FA), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.spa_outlined, color: AppColors.primario),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                        Text(e.nombre.isEmpty ? '(Sin nombre)' : e.nombre,
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                        const Etiqueta(
                            texto: 'Activa', fondo: AppColors.exitoSuave, color: AppColors.exito),
                      ]),
                      Text(servicios.length == 1
                          ? '1 servicio registrado'
                          : '${servicios.length} servicios registrados',
                          style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Configurar',
                  onPressed: () => _abrirFormulario(e),
                  icon: const Icon(Icons.more_vert, color: AppColors.textoSecundario),
                ),
                IconButton(
                  onPressed: () => setState(() =>
                      abierta ? _cerradas.add(e.id) : _cerradas.remove(e.id)),
                  icon: Icon(abierta ? Icons.expand_less : Icons.expand_more),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: Row(children: [
              const Icon(Icons.badge_outlined, size: 16, color: AppColors.textoSecundario),
              const SizedBox(width: 6),
              Text('Profesionales (${profesionales.length}): ',
                  style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
              Expanded(
                child: profesionales.isEmpty
                    ? const Text('Sin asignar',
                        style: TextStyle(fontSize: 12, color: AppColors.textoTenue))
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(children: [
                          for (final p in profesionales) ...[
                            AvatarIniciales(p.nombreCompleto, radio: 10),
                            const SizedBox(width: 4),
                            Text(p.nombreCorto,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            const SizedBox(width: 10),
                          ],
                        ]),
                      ),
              ),
            ]),
          ),
          if (abierta) ...[
            Container(
              color: const Color(0xFFF8F9FC),
              child: Column(children: [
                const Divider(),
                if (servicios.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(14),
                    child: Text('Sin servicios. Añade el primero.',
                        style: TextStyle(color: AppColors.textoSecundario)),
                  ),
                for (final s in servicios) _filaServicio(e, s),
                const Divider(),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 2, 8, 2),
              child: Row(children: [
                TextButton.icon(
                  onPressed: () => _formServicio(e),
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  label: const Text('Añadir servicio'),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => _abrirFormulario(e),
                  child: const Text('Configurar',
                      style: TextStyle(color: AppColors.textoSecundario)),
                ),
                TextButton(
                  onPressed: _procesando.contains(e.id) ? null : () => _pausar(e),
                  child: const Text('Pausar', style: TextStyle(color: AppColors.textoSecundario)),
                ),
              ]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _filaServicio(Especialidad e, Servicio s) {
    return InkWell(
      onTap: () => _formServicio(e, s),
      child: Opacity(
        opacity: s.activo ? 1 : 0.5,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
          child: Row(children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                  color: s.activo ? AppColors.primario : AppColors.textoTenue,
                  shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.nombre + (s.activo ? '' : ' (inactivo)'),
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  Row(children: [
                    const Icon(Icons.schedule, size: 13, color: AppColors.textoSecundario),
                    const SizedBox(width: 3),
                    Text('${s.duracion} min',
                        style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
                    if (s.descripcion.isNotEmpty)
                      Expanded(
                        child: Text('  •  ${s.descripcion}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
                      ),
                  ]),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(Formatos.moneda(s.precio),
                style: const TextStyle(fontWeight: FontWeight.w700)),
            IconButton(
              tooltip: 'Editar',
              onPressed: () => _formServicio(e, s),
              icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.textoSecundario),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _tarjetaPausada(Especialidad e) {
    final servicios = _serviciosDe(e);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.superficie.withAlpha(180),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.textoTenue),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.spa_outlined, color: AppColors.textoTenue),
            const SizedBox(width: 10),
            Expanded(
              child: Text(e.nombre,
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textoSecundario,
                      decoration: TextDecoration.lineThrough)),
            ),
            const Etiqueta(texto: 'En pausa', fondo: AppColors.neutroSuave, color: AppColors.neutro),
            const SizedBox(width: 6),
            TextButton(
              onPressed: _procesando.contains(e.id) ? null : () => _pausar(e),
              style: TextButton.styleFrom(backgroundColor: const Color(0xFFEEF0FA)),
              child: const Text('Reactivar'),
            ),
          ]),
          Text('${servicios.length} servicios en catálogo (no se pueden reservar)',
              style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
          if (servicios.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(children: [
              Expanded(
                child: Text(
                    'Incluye: ${servicios.map((s) => '${s.nombre} (${Formatos.moneda(s.precio)})').join(', ')}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
              ),
              TextButton(onPressed: () => _abrirFormulario(e), child: const Text('Editar')),
            ]),
          ],
        ],
      ),
    );
  }
}
