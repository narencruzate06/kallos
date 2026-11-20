import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class ProximamenteView extends StatelessWidget {
  final String titulo;
  final IconData icono;
  const ProximamenteView(
      {super.key, required this.titulo, this.icono = Icons.construction});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                  color: AppColors.primarioSuave, shape: BoxShape.circle),
              child: Icon(icono, color: AppColors.primario, size: 30),
            ),
            const SizedBox(height: 16),
            Text(titulo,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            const Text(
              'Este módulo está en construcción.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textoSecundario),
            ),
          ],
        ),
      ),
    );
  }
}

class ProximamenteScreen extends StatelessWidget {
  final String titulo;
  final IconData icono;
  const ProximamenteScreen(
      {super.key, required this.titulo, this.icono = Icons.construction});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(titulo)),
      body: ProximamenteView(titulo: titulo, icono: icono),
    );
  }
}
