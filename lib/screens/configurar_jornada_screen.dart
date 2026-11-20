import 'package:flutter/material.dart';

import '../models/catalogos.dart';
import '../services/api_client.dart';
import '../services/catalogo_service.dart';
import '../theme/app_colors.dart';
import '../widgets/comunes.dart';

class _Dia {
  final int diaSemana;
  final String nombre;
  int? id;
  bool laborable = false;
  TimeOfDay entrada = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay salida = const TimeOfDay(hour: 18, minute: 0);
  bool almuerzo = true;
  TimeOfDay iniAlm = const TimeOfDay(hour: 12, minute: 0);
  TimeOfDay finAlm = const TimeOfDay(hour: 13, minute: 0);

  _Dia(this.diaSemana, this.nombre);

  static int m(TimeOfDay t) => t.hour * 60 + t.minute;

  int get minutosTrabajo {
    if (!laborable) return 0;
    var total = m(salida) - m(entrada);
    if (almuerzo) total -= m(finAlm) - m(iniAlm);
    return total < 0 ? 0 : total;
  }

  String? get error {
    if (!laborable) return null;
    if (m(salida) <= m(entrada)) return 'La salida debe ser después de la entrada.';
    if (almuerzo) {
      if (m(finAlm) <= m(iniAlm)) return 'El fin del almuerzo debe ser después del inicio.';
      if (m(iniAlm) < m(entrada) || m(finAlm) > m(salida)) {
        return 'El almuerzo debe estar dentro de la jornada.';
      }
    }
    return null;
  }
}

class ConfigurarJornadaScreen extends StatefulWidget {
  final Profesional profesional;
  const ConfigurarJornadaScreen({super.key, required this.profesional});

  @override
  State<ConfigurarJornadaScreen> createState() => _ConfigurarJornadaScreenState();
}

class _ConfigurarJornadaScreenState extends State<ConfigurarJornadaScreen> {
  final _api = CatalogoService.instance;
  late List<_Dia> _dias;
  bool _cargando = true;
  bool _guardando = false;
  bool _modificado = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _dias = _vacios();
    _cargar();
  }

  List<_Dia> _vacios() => [
        _Dia(1, 'Lunes'),
        _Dia(2, 'Martes'),
        _Dia(3, 'Miércoles'),
        _Dia(4, 'Jueves'),
        _Dia(5, 'Viernes'),
        _Dia(6, 'Sábado'),
        _Dia(0, 'Domingo'),
      ];

  TimeOfDay _t(String hhmm, TimeOfDay def) {
    final p = hhmm.split(':');
    if (p.length < 2) return def;
    final h = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    return h == null || m == null ? def : TimeOfDay(hour: h, minute: m);
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      var lista = await _api.horariosDe(widget.profesional.id);
      if (lista.isEmpty) {
        lista = (await _api.horariosLaborales())
            .where((h) => h.profesionalId == widget.profesional.id)
            .toList();
      }
      final dias = _vacios();
      for (final h in lista) {
        for (final d in dias) {
          if (d.diaSemana != h.diaSemana) continue;
          d
            ..id = h.id
            ..laborable = true
            ..entrada = _t(h.horaInicio, d.entrada)
            ..salida = _t(h.horaFin, d.salida)
            ..almuerzo = h.tieneAlmuerzo
            ..iniAlm = _t(h.inicioAlmuerzo, d.iniAlm)
            ..finAlm = _t(h.finAlmuerzo, d.finAlm);
        }
      }
      if (!mounted) return;
      setState(() {
        _dias = dias;
        _modificado = false;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  String _ver(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _elegir(TimeOfDay actual, ValueChanged<TimeOfDay> asignar) async {
    final t = await showTimePicker(context: context, initialTime: actual);
    if (t != null) {
      setState(() {
        asignar(t);
        _modificado = true;
      });
    }
  }

  void _copiarLunes() {
    final l = _dias.first;
    setState(() {
      for (final d in _dias.skip(1)) {
        if (d.diaSemana == 0 || d.diaSemana == 6) continue;
        d
          ..laborable = l.laborable
          ..entrada = l.entrada
          ..salida = l.salida
          ..almuerzo = l.almuerzo
          ..iniAlm = l.iniAlm
          ..finAlm = l.finAlm;
      }
      _modificado = true;
    });
    mostrarMensaje(context, 'Horario del lunes copiado de martes a viernes');
  }

  HorarioLaboral _aApi(_Dia d) => HorarioLaboral(
        id: d.id ?? 0,
        profesionalId: widget.profesional.id,
        diaSemana: d.diaSemana,
        horaInicio: _ver(d.entrada),
        horaFin: _ver(d.salida),
        tieneAlmuerzo: d.almuerzo,
        inicioAlmuerzo: _ver(d.iniAlm),
        finAlmuerzo: _ver(d.finAlm),
      );

  Future<void> _guardar() async {
    for (final d in _dias) {
      final e = d.error;
      if (e != null) {
        mostrarMensaje(context, '${d.nombre}: $e', error: true);
        return;
      }
    }
    if (!_dias.any((d) => d.laborable)) {
      mostrarMensaje(context, 'Activa al menos un día laborable.', error: true);
      return;
    }
    setState(() => _guardando = true);
    try {
      for (final d in _dias) {
        if (d.laborable && d.id != null) {
          await _api.actualizarHorario(_aApi(d));
        } else if (d.laborable) {
          await _api.crearHorario(_aApi(d));
        } else if (d.id != null) {
          await _api.eliminarHorario(d.id!);
        }
      }
      if (!mounted) return;
      mostrarMensaje(context, 'Horario semanal de ${widget.profesional.nombres} guardado');
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      mostrarMensaje(context, e.mensaje, error: true);
      _cargar();
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _descartar() async {
    if (!_modificado) {
      Navigator.pop(context);
      return;
    }
    final ok = await confirmar(context,
        titulo: 'Descartar cambios',
        mensaje: 'Los cambios del horario no se guardarán.',
        textoAceptar: 'Descartar',
        peligroso: true);
    if (ok && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profesional;
    return PopScope(
      canPop: !_modificado,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _descartar();
      },
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('HORARIOS Y TURNOS',
                  style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 0.6,
                      color: AppColors.textoSecundario,
                      fontWeight: FontWeight.w600)),
              Text('Configurar Jornada',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ],
          ),
          actions: [
            if (_modificado)
              const Padding(
                padding: EdgeInsets.only(right: 12),
                child: Center(
                  child: Etiqueta(
                      texto: 'Sin guardar',
                      fondo: AppColors.exitoSuave,
                      color: AppColors.exito),
                ),
              ),
          ],
          bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider()),
        ),
        body: _cargando
            ? const Center(child: CircularProgressIndicator())
            : _error != null
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
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                    children: [
                      Row(children: [
                        AvatarIniciales(p.nombreCompleto, radio: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.nombreCompleto,
                                  style: const TextStyle(
                                      fontSize: 18, fontWeight: FontWeight.w700)),
                              Text(p.especialidad.isEmpty ? 'Especialista' : p.especialidad,
                                  style: const TextStyle(color: AppColors.textoSecundario)),
                            ],
                          ),
                        ),
                      ]),
                      const SizedBox(height: 14),
                      _resumen(),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _copiarLunes,
                        style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(44),
                            backgroundColor: const Color(0xFFEEF0FA),
                            foregroundColor: AppColors.primario),
                        icon: const Icon(Icons.copy_all_outlined, size: 18),
                        label: const Text('Copiar horario del lunes a martes-viernes'),
                      ),
                      const SizedBox(height: 16),
                      const Row(children: [
                        Icon(Icons.view_week_outlined, color: AppColors.primario),
                        SizedBox(width: 8),
                        Text('Jornada Detallada Diaria',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      ]),
                      const SizedBox(height: 10),
                      for (final d in _dias) ...[
                        _tarjetaDia(d),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ),
        bottomNavigationBar: _cargando || _error != null
            ? null
            : SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  decoration: const BoxDecoration(
                    color: AppColors.superficie,
                    border: Border(top: BorderSide(color: AppColors.borde)),
                  ),
                  child: Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _guardando ? null : _descartar,
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
                        label: const FittedBox(child: Text('Guardar horario semanal')),
                      ),
                    ),
                  ]),
                ),
              ),
      ),
    );
  }

  Widget _resumen() {
    final minutos = _dias.fold<int>(0, (t, d) => t + d.minutosTrabajo);
    final laborables = _dias.where((d) => d.laborable).toList();
    final descansos = _dias.where((d) => !d.laborable).toList();
    String letras(List<_Dia> l) => l.map((d) => d.nombre.substring(0, 1)).join(' · ');
    final horas = minutos / 60;
    Widget caja(String titulo, String valor, String detalle, {double? progreso}) => Expanded(
          child: Container(
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
                const SizedBox(height: 4),
                Text(valor, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                if (progreso != null)
                  LinearProgressIndicator(
                    value: progreso.clamp(0.0, 1.0),
                    minHeight: 4,
                    backgroundColor: AppColors.borde,
                    color: AppColors.primario,
                    borderRadius: BorderRadius.circular(4),
                  )
                else
                  Text(detalle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario)),
              ],
            ),
          ),
        );
    return Row(children: [
      caja('Horas totales', '${horas.toStringAsFixed(horas % 1 == 0 ? 0 : 1)}h', '',
          progreso: horas / 48),
      const SizedBox(width: 8),
      caja('Laborables', '${laborables.length} días', letras(laborables)),
      const SizedBox(width: 8),
      caja('Descansos', '${descansos.length} días',
          descansos.isEmpty ? 'Ninguno' : letras(descansos)),
    ]);
  }

  Widget _campoHora(String titulo, TimeOfDay valor, ValueChanged<TimeOfDay> asignar) =>
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
            const SizedBox(height: 4),
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => _elegir(valor, asignar),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.borde),
                ),
                child: Row(children: [
                  Expanded(
                    child: Text(_ver(valor),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                  const Icon(Icons.schedule, size: 18, color: AppColors.textoSecundario),
                ]),
              ),
            ),
          ],
        ),
      );

  Widget _tarjetaDia(_Dia d) {
    final hoy = DateTime.now().weekday % 7 == d.diaSemana;
    final min = d.minutosTrabajo;
    final error = d.error;
    final detalle = !d.laborable
        ? 'Descanso'
        : '${(min / 60).toStringAsFixed(min % 60 == 0 ? 0 : 1)}h totales'
            '${d.almuerzo ? ' · ${_Dia.m(d.finAlm) - _Dia.m(d.iniAlm)} min almuerzo' : ' · Jornada continua'}';
    return Container(
      decoration: BoxDecoration(
        color: d.laborable ? AppColors.superficie : const Color(0xFFF1F2F8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: error != null
                ? AppColors.error
                : hoy && d.laborable
                    ? AppColors.primario
                    : AppColors.borde,
            width: hoy && d.laborable ? 1.5 : 1),
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: hoy && d.laborable ? AppColors.primario : const Color(0xFFEEF0FA),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(d.nombre.substring(0, 1),
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: hoy && d.laborable ? Colors.white : AppColors.texto)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d.nombre,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: d.laborable ? AppColors.texto : AppColors.textoSecundario)),
                  Text(hoy ? 'Hoy · $detalle' : detalle,
                      style: TextStyle(
                          fontSize: 12,
                          color: hoy ? AppColors.primario : AppColors.textoSecundario)),
                ],
              ),
            ),
            if (!d.laborable)
              const Text('NO LABORABLE',
                  style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 0.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textoSecundario)),
            Switch(
              value: d.laborable,
              onChanged: (v) => setState(() {
                d.laborable = v;
                _modificado = true;
              }),
            ),
          ]),
          if (d.laborable) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Row(children: [
                _campoHora('Entrada', d.entrada, (t) => d.entrada = t),
                const SizedBox(width: 10),
                _campoHora('Salida', d.salida, (t) => d.salida = t),
              ]),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Checkbox(
                value: d.almuerzo,
                onChanged: (v) => setState(() {
                  d.almuerzo = v ?? false;
                  _modificado = true;
                }),
              ),
              const Text('Pausa de almuerzo'),
              const Spacer(),
              if (d.almuerzo)
                TextButton(
                  onPressed: () async {
                    await _elegir(d.iniAlm, (t) => d.iniAlm = t);
                    if (mounted) await _elegir(d.finAlm, (t) => d.finAlm = t);
                  },
                  child: Text('${_ver(d.iniAlm)} - ${_ver(d.finAlm)}'),
                ),
            ]),
            if (error != null)
              Text(error, style: const TextStyle(fontSize: 12, color: AppColors.error)),
          ],
        ],
      ),
    );
  }
}
