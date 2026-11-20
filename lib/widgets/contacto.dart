import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'comunes.dart';

Future<void> llamar(BuildContext context, String celular) async {
  final numero = celular.replaceAll(RegExp(r'[^\d+]'), '');
  if (numero.length < 7) {
    mostrarMensaje(context, 'El cliente no tiene un teléfono válido.', error: true);
    return;
  }
  final ok = await launchUrl(Uri(scheme: 'tel', path: numero));
  if (!ok && context.mounted) {
    mostrarMensaje(context, 'No se pudo abrir el marcador.', error: true);
  }
}

Future<void> enviarCorreo(BuildContext context, String correo, {String asunto = ''}) async {
  if (!correo.contains('@')) {
    mostrarMensaje(context, 'El cliente no tiene un correo registrado.', error: true);
    return;
  }
  final ok = await launchUrl(Uri(
    scheme: 'mailto',
    path: correo,
    query: asunto.isEmpty ? null : 'subject=${Uri.encodeComponent(asunto)}',
  ));
  if (!ok && context.mounted) {
    mostrarMensaje(context, 'No se pudo abrir el correo.', error: true);
  }
}

String haceCuanto(DateTime f) {
  const meses = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
  final hoy = DateTime.now();
  final d = DateTime(f.year, f.month, f.day);
  final dias = DateTime(hoy.year, hoy.month, hoy.day).difference(d).inDays;
  if (dias == 0) return 'Hoy';
  if (dias == 1) return 'Ayer';
  if (dias == -1) return 'Mañana';
  if (dias > 1 && dias < 30) return 'Hace $dias días';
  return '${f.day} ${meses[f.month - 1]}${f.year != hoy.year ? ' ${f.year}' : ''}';
}
