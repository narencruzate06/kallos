import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';

class KallosLogo extends StatelessWidget {
  final double alto;
  final bool completo;
  const KallosLogo({super.key, this.alto = 56, this.completo = false});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      completo ? 'assets/logo_kallos.png' : 'assets/logo_kallos_emblema.png',
      height: alto,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      semanticLabel: 'Kallos',
      errorBuilder: (_, __, ___) => Container(
        width: alto,
        height: alto,
        decoration: BoxDecoration(
          color: AppColors.primarioSuave,
          borderRadius: BorderRadius.circular(alto * 0.28),
        ),
        child: Icon(Icons.spa_rounded, color: AppColors.primario, size: alto * 0.5),
      ),
    );
  }
}

class TarjetaKallos extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const TarjetaKallos({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.superficie,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.borde),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class Etiqueta extends StatelessWidget {
  final String texto;
  final Color fondo;
  final Color color;
  final IconData? icono;
  final bool punto;

  const Etiqueta({
    super.key,
    required this.texto,
    required this.fondo,
    required this.color,
    this.icono,
    this.punto = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (punto) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
          ],
          if (icono != null) ...[
            Icon(icono, size: 12, color: color),
            const SizedBox(width: 3),
          ],
          Text(
            texto,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class DivisorTexto extends StatelessWidget {
  final String texto;
  const DivisorTexto(this.texto, {super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            texto,
            style: const TextStyle(
              fontSize: 10,
              letterSpacing: 1,
              color: AppColors.textoSecundario,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}

class EncabezadoSeccion extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final Widget? trailing;
  const EncabezadoSeccion(
      {super.key, required this.icono, required this.titulo, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icono, size: 20, color: AppColors.texto),
        const SizedBox(width: 8),
        Expanded(
          child: Text(titulo,
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class TextoAyuda extends StatelessWidget {
  final String texto;
  final Color color;
  const TextoAyuda(this.texto,
      {super.key, this.color = AppColors.textoSecundario});

  @override
  Widget build(BuildContext context) => Text(texto,
      style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500));
}

class AvatarIniciales extends StatelessWidget {
  final String nombre;
  final double radio;
  final Color fondo;
  final Color color;
  const AvatarIniciales(this.nombre,
      {super.key,
      this.radio = 20,
      this.fondo = AppColors.primarioSuave,
      this.color = AppColors.primario});

  @override
  Widget build(BuildContext context) {
    final partes = nombre.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    final ini = partes.isEmpty
        ? '?'
        : partes.length == 1
            ? partes[0][0].toUpperCase()
            : (partes[0][0] + partes[1][0]).toUpperCase();
    return CircleAvatar(
      radius: radio,
      backgroundColor: fondo,
      child: Text(ini,
          style: TextStyle(
              fontSize: radio * 0.65, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class CargandoBoton extends StatelessWidget {
  final Color color;
  const CargandoBoton({super.key, this.color = Colors.white});
  @override
  Widget build(BuildContext context) => SizedBox(
      width: 18,
      height: 18,
      child: CircularProgressIndicator(strokeWidth: 2, color: color));
}

Future<bool> confirmar(
  BuildContext context, {
  required String titulo,
  required String mensaje,
  String textoAceptar = 'Aceptar',
  bool peligroso = false,
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(titulo),
      content: Text(mensaje),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancelar',
              style: TextStyle(color: AppColors.textoSecundario)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(textoAceptar,
              style: TextStyle(
                  color: peligroso ? AppColors.error : AppColors.primario,
                  fontWeight: FontWeight.w600)),
        ),
      ],
    ),
  );
  return r ?? false;
}

void mostrarMensaje(BuildContext context, String texto, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(texto),
      backgroundColor: error ? AppColors.error : AppColors.texto,
    ));
}

Future<void> copiarTexto(BuildContext context, String texto,
    {required String titulo, String? mensajeOk}) async {
  try {
    await Clipboard.setData(ClipboardData(text: texto));
    if (context.mounted) mostrarMensaje(context, mensajeOk ?? 'Copiado al portapapeles');
  } catch (_) {
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titulo),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Selecciona el texto y cópialo (Ctrl + C):',
                    style: TextStyle(fontSize: 13, color: AppColors.textoSecundario)),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.neutroSuave,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(texto,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
        ],
      ),
    );
  }
}
