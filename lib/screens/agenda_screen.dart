import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../models/catalogos.dart';
import '../models/cita.dart';
import '../services/api_client.dart';
import '../services/catalogo_service.dart';
import '../theme/app_colors.dart';
import '../utils/formatos.dart';
import '../widgets/comunes.dart';
import '../widgets/home_widgets.dart';
import '../widgets/reserva_sheets.dart';
import 'nueva_reserva_screen.dart';

class AgendaScreen extends StatefulWidget {
  final VoidCallback? onVolver;
  const AgendaScreen({super.key, this.onVolver});

  @override
  State<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen> {
  final _api = CatalogoService.instance;

  bool _cargando = true;
  String? _error;
  bool _vistaSemana = false;
  late DateTime _dia;
  late DateTime _lunes;
  int? _profesionalId;

  List<Cita> _reservas = [];
  List<Profesional> _profesionales = [];
  Map<int, Cliente> _clientes = {};

  @override
  void initState() {
    super.initState();
    final hoy = DateTime.now();
    _dia = DateTime(hoy.year, hoy.month, hoy.day);
    _lunes = _dia.subtract(Duration(days: _dia.weekday - 1));
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _error = null;
      _cargando = true;
    });
    try {
      final desde = _lunes.subtract(const Duration(days: 1));
      final hasta = _lunes.add(const Duration(days: 6));
      final r = await Future.wait([
        _api.reservas(desde: desde, hasta: hasta),
        if (_profesionales.isEmpty) _api.profesionales(),
        if (_clientes.isEmpty) _api.clientes(),
      ]);
      if (!mounted) return;
      setState(() {
        _reservas = (r[0] as List<Cita>)
            .where((c) => c.inicio != null && c.estado != EstadoCita.cancelada)
            .toList()
          ..sort((a, b) => a.inicio!.compareTo(b.inicio!));
        var i = 1;
        if (_profesionales.isEmpty) {
          _profesionales = (r[i++] as List<Profesional>).where((p) => p.estado).toList();
        }
        if (_clientes.isEmpty && r.length > i) {
          _clientes = {for (final c in r[i] as List<Cliente>) c.id: c};
        }
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo cargar la agenda.');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  bool _mismoDia(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  List<Cita> _citasDe(DateTime dia) => _reservas
      .where((c) =>
          _mismoDia(c.inicio!, dia) &&
          (_profesionalId == null || c.profesionalId == _profesionalId))
      .toList();

  int _ocupacion(int citas) {
    final cap = (_profesionalId == null ? _profesionales.length : 1) *
        ApiConfig.turnosPorProfesional;
    return cap == 0 ? 0 : ((citas / cap) * 100).round().clamp(0, 100).toInt();
  }

  void _cambiarSemana(int semanas) {
    setState(() {
      _lunes = _lunes.add(Duration(days: 7 * semanas));
      _dia = _lunes.add(Duration(days: _dia.weekday - 1));
    });
    _cargar();
  }

  Future<void> _detalle(Cita c) async {
    final cambio = await abrirDetalleReserva(context, c, cliente: _clientes[c.clienteId]);
    if (cambio == true) _cargar();
  }

  Future<void> _nuevaReserva([DateTime? dia]) async {
    final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => NuevaReservaScreen(fechaInicial: dia ?? _dia)));
    if (ok == true) _cargar();
  }

  Future<void> _whatsApp(Cita c) async {
    final cambio = await abrirConfirmarCita(context, c, cliente: _clientes[c.clienteId]);
    if (cambio == true) _cargar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: widget.onVolver == null
            ? null
            : IconButton(icon: const Icon(Icons.arrow_back), onPressed: widget.onVolver),
        titleSpacing: widget.onVolver == null ? null : 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Kallos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            Text('Agenda de Citas',
                style: TextStyle(
                    fontSize: 12, color: AppColors.primario, fontWeight: FontWeight.w600)),
          ],
        ),
        actions: [
          _selectorVista(),
          IconButton(
              tooltip: 'Nueva reserva',
              onPressed: _nuevaReserva,
              icon: const Icon(Icons.add_circle_outline)),
        ],
        bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider()),
      ),
      body: Column(
        children: [
          _cabeceraSemana(),
          _filtroProfesionales(),
          const Divider(),
          Expanded(child: _contenido()),
        ],
      ),
    );
  }

  Widget _selectorVista() {
    Widget opcion(String texto, bool semana) {
      final sel = _vistaSemana == semana;
      return GestureDetector(
        onTap: () => setState(() => _vistaSemana = semana),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: sel ? AppColors.superficie : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(texto,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                  color: sel ? AppColors.texto : AppColors.textoSecundario)),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
          color: AppColors.neutroSuave, borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        opcion('Día', false),
        opcion('Semana', true),
      ]),
    );
  }

  Widget _cabeceraSemana() {
    final hoy = DateTime.now();
    final esHoy = _mismoDia(_dia, hoy);
    const letras = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
    const dias = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
    const meses = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
    return Container(
      color: AppColors.superficie,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                _vistaSemana
                    ? 'Semana del ${_lunes.day} ${meses[_lunes.month - 1]}'
                    : '${esHoy ? 'Hoy - ' : ''}${_dia.day} ${meses[_dia.month - 1]}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 8),
              if (!_vistaSemana)
                Etiqueta(
                    texto: dias[_dia.weekday - 1],
                    fondo: AppColors.exitoSuave,
                    color: AppColors.exito),
              const Spacer(),
              _botonFlecha(Icons.chevron_left, () => _cambiarSemana(-1)),
              const SizedBox(width: 6),
              _botonFlecha(Icons.chevron_right, () => _cambiarSemana(1)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(child: _diaSemana(_lunes.add(Duration(days: i)), letras[i])),
            ],
          ),
        ],
      ),
    );
  }

  Widget _botonFlecha(IconData icono, VoidCallback onTap) => InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.borde),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icono, size: 20),
        ),
      );

  Widget _diaSemana(DateTime d, String letra) {
    final sel = _mismoDia(d, _dia);
    final hoy = _mismoDia(d, DateTime.now());
    final citas = _cargando ? 0 : _citasDe(d).length;
    return GestureDetector(
      onTap: () => setState(() {
        _dia = d;
        _vistaSemana = false;
      }),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: sel ? AppColors.primario : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(letra,
                style: TextStyle(
                    fontSize: 11,
                    color: sel ? Colors.white70 : AppColors.textoSecundario)),
            const SizedBox(height: 2),
            Text('${d.day}',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: sel
                        ? Colors.white
                        : hoy
                            ? AppColors.primario
                            : AppColors.texto)),
            const SizedBox(height: 3),
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: citas == 0
                    ? Colors.transparent
                    : sel
                        ? Colors.white
                        : AppColors.primario,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filtroProfesionales() {
    final citasDia = _reservas.where((c) => _mismoDia(c.inicio!, _dia)).length;
    return Container(
      color: AppColors.superficie,
      height: 50,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
        children: [
          _chip('Todos ($citasDia)', _profesionalId == null, () => setState(() => _profesionalId = null)),
          for (final p in _profesionales)
            _chip(p.nombreCorto, _profesionalId == p.id,
                () => setState(() => _profesionalId = p.id)),
        ],
      ),
    );
  }

  Widget _chip(String texto, bool sel, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(texto),
          selected: sel,
          showCheckmark: false,
          selectedColor: AppColors.texto,
          backgroundColor: AppColors.superficie,
          side: BorderSide(color: sel ? AppColors.texto : AppColors.borde),
          shape: const StadiumBorder(),
          labelStyle: TextStyle(
              color: sel ? Colors.white : AppColors.texto,
              fontWeight: FontWeight.w600,
              fontSize: 13),
          onSelected: (_) => onTap(),
        ),
      );

  Widget _contenido() {
    if (_cargando && _reservas.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            SizedBox(
                width: 180,
                child: ElevatedButton(onPressed: _cargar, child: const Text('Reintentar'))),
          ]),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _cargar,
      child: _vistaSemana ? _semana() : _diaVista(),
    );
  }

  Widget _diaVista() {
    final citas = _citasDe(_dia);
    final ayer = _citasDe(_dia.subtract(const Duration(days: 1))).length;
    final ocupacion = _ocupacion(citas.length);
    final variacion = ocupacion - _ocupacion(ayer);
    final profesionalesDia = citas.map((c) => c.profesionalId).toSet().length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: _kpi(
                'Ocupación Diaria',
                '$ocupacion%',
                Etiqueta(
                  texto: '${variacion >= 0 ? '+' : ''}$variacion% vs ayer',
                  fondo: variacion >= 0 ? AppColors.exitoSuave : AppColors.errorSuave,
                  color: variacion >= 0 ? AppColors.exito : AppColors.error,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _kpi(
                'Citas Programadas',
                '${citas.length}',
                Etiqueta(
                  texto: profesionalesDia == 1
                      ? '1 especialista'
                      : '$profesionalesDia especialistas',
                  fondo: AppColors.infoSuave,
                  color: AppColors.info,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (citas.isEmpty)
          _libre(ApiConfig.aperturaSalon, null, vacio: true)
        else
          ..._lineaDeTiempo(citas),
      ],
    );
  }

  Widget _kpi(String titulo, String valor, Widget etiqueta) => TarjetaKallos(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo,
                style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
            const SizedBox(height: 4),
            Text(valor, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            etiqueta,
          ],
        ),
      );

  int _min(DateTime d) => d.hour * 60 + d.minute;
  int _minTexto(String hhmm) {
    final p = hhmm.split(':');
    return int.parse(p[0]) * 60 + int.parse(p[1]);
  }

  String _hhmm(int m) =>
      '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';

  List<Widget> _lineaDeTiempo(List<Cita> citas) {
    final widgets = <Widget>[];
    final ahora = DateTime.now();
    final esHoy = _mismoDia(_dia, ahora);
    var ahoraMostrado = !esHoy;
    final apertura = _minTexto(ApiConfig.aperturaSalon);
    final cierre = _minTexto(ApiConfig.cierreSalon);
    var cursor = apertura;

    for (final c in citas) {
      final ini = _min(c.inicio!);
      if (_profesionalId != null && ini - cursor >= 30) {
        widgets.add(_libre(_hhmm(cursor), ini - cursor));
      }
      if (!ahoraMostrado && _min(ahora) < ini) {
        widgets.add(_lineaAhora(ahora));
        ahoraMostrado = true;
      }
      widgets.add(_filaCita(c, ahora));
      final fin = c.fin == null ? ini : _min(c.fin!);
      if (fin > cursor) cursor = fin;
    }
    if (_profesionalId != null && cierre - cursor >= 30) {
      widgets.add(_libre(_hhmm(cursor), cierre - cursor));
    }
    if (!ahoraMostrado) widgets.add(_lineaAhora(ahora));
    return widgets;
  }

  Widget _filaTiempo(String hora, Widget contenido, {bool resaltar = false}) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 44,
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(hora,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: resaltar ? FontWeight.w700 : FontWeight.w500,
                      color: resaltar ? AppColors.primario : AppColors.textoSecundario)),
            ),
          ),
          SizedBox(
            width: 16,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                Container(width: 1.5, color: AppColors.borde),
                Padding(
                  padding: const EdgeInsets.only(top: 15),
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                        color: resaltar ? AppColors.primario : AppColors.textoTenue,
                        shape: BoxShape.circle),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: contenido,
            ),
          ),
        ],
      ),
    );
  }

  Widget _lineaAhora(DateTime ahora) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(Formatos.hhmm(ahora),
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primario)),
          ),
          Container(
            width: 16,
            alignment: Alignment.center,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: AppColors.primario,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primarioSuave, width: 3),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: LayoutBuilder(
              builder: (_, c) => Row(
                children: [
                  for (var i = 0; i < (c.maxWidth - 60) ~/ 8; i++)
                    Container(
                        width: 4,
                        height: 1.5,
                        margin: const EdgeInsets.only(right: 4),
                        color: AppColors.primario),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: AppColors.primario, borderRadius: BorderRadius.circular(4)),
                    child: const Text('AHORA',
                        style: TextStyle(
                            color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _libre(String desde, int? minutos, {bool vacio = false}) {
    final p = desde.split(':');
    final fecha = DateTime(_dia.year, _dia.month, _dia.day, int.parse(p[0]), int.parse(p[1]));
    final pasado = fecha.isBefore(DateTime.now()) && !vacio;
    final texto = vacio
        ? 'Sin citas este día · Agendar una'
        : 'Espacio libre ($minutos min disponibles)';
    final caja = InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: pasado ? null : () => _nuevaReserva(_dia),
      child: CustomPaint(
        painter: _BordePunteado(),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_circle_outline,
                  size: 18, color: pasado ? AppColors.textoTenue : AppColors.textoSecundario),
              const SizedBox(width: 6),
              Text(texto,
                  style: TextStyle(
                      color: pasado ? AppColors.textoTenue : AppColors.textoSecundario,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
    return vacio ? caja : _filaTiempo(desde, caja);
  }

  Widget _filaCita(Cita c, DateTime ahora) {
    final enCurso = c.estado == EstadoCita.enCurso;
    final restantes = enCurso && c.fin != null ? c.fin!.difference(ahora).inMinutes : 0;
    return _filaTiempo(
      c.horaInicio,
      resaltar: enCurso,
      Material(
        color: AppColors.superficie,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
              color: enCurso ? AppColors.primario : AppColors.borde,
              width: enCurso ? 1.5 : 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _detalle(c),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(c.cliente,
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w700)),
                          EtiquetaEstadoCita(c.estado),
                        ],
                      ),
                    ),
                    Text('${c.horaInicio} - ${c.horaFin}',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: enCurso ? FontWeight.w700 : FontWeight.w500,
                            color: enCurso ? AppColors.primario : AppColors.textoSecundario)),
                  ],
                ),
                const SizedBox(height: 4),
                Text('${c.servicio} • ${c.duracion} min',
                    style: const TextStyle(fontSize: 13, color: AppColors.textoSecundario)),
                const SizedBox(height: 8),
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.person_outline, size: 15, color: AppColors.textoSecundario),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text('Prof: ${c.profesionalCorto}',
                          style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
                    ),
                    if (enCurso && restantes > 0)
                      Text('$restantes min restantes',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primario))
                    else if (c.vigente) ...[
                      _botonMini(Icons.visibility_outlined, 'Detalle', AppColors.infoSuave,
                          AppColors.info, () => _detalle(c)),
                      if ((_clientes[c.clienteId]?.celular ?? '').isNotEmpty) ...[
                        const SizedBox(width: 6),
                        _botonMini(Icons.mark_chat_read_outlined, 'Confirmar', AppColors.exitoSuave,
                            AppColors.exito, () => _whatsApp(c)),
                      ],
                    ] else if (c.precio > 0)
                      Text(Formatos.moneda(c.precio),
                          style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _botonMini(IconData icono, String texto, Color fondo, Color color, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(6)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icono, size: 14, color: color),
          const SizedBox(width: 4),
          Text(texto,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ]),
      ),
    );
  }

  Widget _semana() {
    const dias = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        for (var i = 0; i < 7; i++) ...[
          Builder(builder: (context) {
            final d = _lunes.add(Duration(days: i));
            final citas = _citasDe(d);
            final total = citas.fold<double>(0, (t, c) => t + c.precio);
            return TarjetaKallos(
              onTap: () => setState(() {
                _dia = d;
                _vistaSemana = false;
              }),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('${dias[i]} ${d.day}',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: _mismoDia(d, DateTime.now())
                                  ? AppColors.primario
                                  : AppColors.texto)),
                      const Spacer(),
                      Etiqueta(
                        texto: citas.length == 1 ? '1 cita' : '${citas.length} citas',
                        fondo: citas.isEmpty ? AppColors.neutroSuave : AppColors.exitoSuave,
                        color: citas.isEmpty ? AppColors.neutro : AppColors.exito,
                      ),
                      if (total > 0) ...[
                        const SizedBox(width: 6),
                        Text(Formatos.moneda(total),
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textoSecundario)),
                      ],
                    ],
                  ),
                  if (citas.isNotEmpty) const SizedBox(height: 8),
                  for (final c in citas.take(4))
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(children: [
                        SizedBox(
                          width: 46,
                          child: Text(c.horaInicio,
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w600)),
                        ),
                        Expanded(
                          child: Text('${c.cliente} · ${c.servicio}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.textoSecundario)),
                        ),
                      ]),
                    ),
                  if (citas.length > 4)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('+ ${citas.length - 4} más',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.primario)),
                    ),
                ],
              ),
            );
          }),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _BordePunteado extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.textoTenue
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    final rrect = RRect.fromRectAndRadius(
        Offset.zero & size, const Radius.circular(12));
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + 6), paint);
        d += 11;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
