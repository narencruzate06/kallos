import 'package:flutter/material.dart';

import '../models/usuario.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../widgets/comunes.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _iniciar();
  }

  Future<void> _iniciar() async {
    Usuario? usuario;
    String? mensaje;
    try {
      usuario = await AuthService.instance.restaurarSesion();
    } on ApiException catch (e) {
      mensaje = e.noAutorizado
          ? 'Tu contraseña cambió. Inicia sesión nuevamente.'
          : e.mensaje;
    } catch (_) {
      mensaje = 'No se pudo iniciar sesión automáticamente.';
    }
    if (!mounted) return;
    final u = usuario;
    final m = mensaje;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => u != null ? HomeScreen(usuario: u) : LoginScreen(mensajeInicial: m),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            KallosLogo(alto: 170, completo: true),
            SizedBox(height: 28),
            SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2)),
          ],
        ),
      ),
    );
  }
}
