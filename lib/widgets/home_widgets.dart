import 'package:flutter/material.dart';

import '../models/cita.dart';
import '../theme/app_colors.dart';
import 'comunes.dart';

class KpiCard extends StatelessWidget {
  final String titulo;
  final String valor;
  final String? valorSecundario;
  final String detalle;
  final Widget? etiqueta;

  const KpiCard({
    super.key,
    required this.titulo,
    required this.valor,
    required this.detalle,
    this.valorSecundario,
    this.etiqueta,
  });

  @override
  Widget build(BuildContext context) {
    return TarjetaKallos(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(titulo,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textoSecundario)),
              ),
              if (etiqueta != null) etiqueta!,
            ],
          ),
          const SizedBox(height: 6),
          Text.rich(
            TextSpan(children: [
              TextSpan(
                text: valor,
                style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    color: AppColors.texto),
              ),
              if (valorSecundario != null)
                TextSpan(
                  text: ' $valorSecundario',
                  style: const TextStyle(
                      fontSize: 16, color: AppColors.textoSecundario),
                ),
            ]),
          ),
          const SizedBox(height: 2),
          Text(detalle,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textoSecundario)),
        ],
      ),
    );
  }
}

class AccesoRapidoTile extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String subtitulo;
  final VoidCallback onTap;

  const AccesoRapidoTile({
    super.key,
    required this.icono,
    required this.titulo,
    required this.subtitulo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TarjetaKallos(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
                color: AppColors.primarioSuave, shape: BoxShape.circle),
            child: Icon(icono, size: 18, color: AppColors.primario),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                Text(subtitulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textoSecundario)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class EtiquetaEstadoCita extends StatelessWidget {
  final EstadoCita estado;
  const EtiquetaEstadoCita(this.estado, {super.key});

  @override
  Widget build(BuildContext context) {
    final (fondo, color) = switch (estado) {
      EstadoCita.enCurso => (AppColors.exitoSuave, AppColors.exito),
      EstadoCita.confirmada => (AppColors.infoSuave, AppColors.info),
      EstadoCita.pendiente => (AppColors.neutroSuave, AppColors.neutro),
      EstadoCita.finalizada => (AppColors.neutroSuave, AppColors.textoTenue),
      EstadoCita.cancelada => (AppColors.errorSuave, AppColors.error),
    };
    return Etiqueta(
      texto: estado.etiqueta,
      fondo: fondo,
      color: color,
      punto: estado == EstadoCita.enCurso,
    );
  }
}

enum AccionCitaMenu { reprogramar, cancelar }

class CitaCard extends StatelessWidget {
  final Cita cita;
  final bool procesando;
  final ValueChanged<AccionCitaMenu> onMenu;
  final VoidCallback? onTap;

  const CitaCard({
    super.key,
    required this.cita,
    required this.procesando,
    required this.onMenu,
    this.onTap,
  });

  bool get _enCurso => cita.estado == EstadoCita.enCurso;
  bool get _cerrada =>
      cita.estado == EstadoCita.finalizada ||
      cita.estado == EstadoCita.cancelada;
  bool get _gestionable =>
      cita.estado == EstadoCita.confirmada ||
      cita.estado == EstadoCita.pendiente;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.superficie,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borde),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Material(
         color: Colors.transparent,
         child: InkWell(
          onTap: onTap,
          child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_enCurso) Container(width: 4, color: AppColors.primario),
              Expanded(
                child: Opacity(
                  opacity: _cerrada ? 0.6 : 1,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(12, 12, _gestionable ? 0 : 12, 12),
                    child: _contenido(),
                  ),
                ),
              ),
            ],
          ),
          ),
         ),
        ),
      ),
    );
  }

  Widget _contenido() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 54,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.fondo,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Text(cita.horaInicio,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700)),
              Text(cita.horaFin,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textoSecundario)),
            ],
          ),
        ),
        const SizedBox(width: 10),
        CircleAvatar(
          radius: 18,
          backgroundColor: AppColors.avatar,
          child: Text(cita.inicialesCliente,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.avatarTexto)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(cita.cliente,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  EtiquetaEstadoCita(cita.estado),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                '${cita.servicio} • Prof: ${cita.profesionalCorto}',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textoSecundario),
              ),
            ],
          ),
        ),
        if (_gestionable)
          procesando
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : PopupMenuButton<AccionCitaMenu>(
                  tooltip: 'Opciones',
                  icon: const Icon(Icons.more_vert,
                      size: 20, color: AppColors.textoSecundario),
                  onSelected: onMenu,
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: AccionCitaMenu.reprogramar,
                      child: Text('Reagendar'),
                    ),
                    PopupMenuItem(
                      value: AccionCitaMenu.cancelar,
                      child: Text('Cancelar reserva',
                          style: TextStyle(color: AppColors.error)),
                    ),
                  ],
                ),
      ],
    );
  }
}
