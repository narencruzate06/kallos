import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/api_config.dart';
import '../data/demo_data.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/sesion_storage.dart';
import '../theme/app_colors.dart';
import '../utils/validadores.dart';
import '../widgets/comunes.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  final String? mensajeInicial;
  const LoginScreen({super.key, this.mensajeInicial});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const _correoSoporte = 'soporte.kallos@cecar.edu.co';

  final _formKey = GlobalKey<FormState>();
  final _usuarioCtrl = TextEditingController();
  final _claveCtrl = TextEditingController();
  final _claveFocus = FocusNode();

  bool _verClave = false;
  bool _recordar = false;
  bool _cargando = false;
  bool _intentoEnvio = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _error = widget.mensajeInicial;
    _precargarUsuario();
  }

  Future<void> _precargarUsuario() async {
    final cred = await SesionStorage.credenciales();
    if (!mounted) return;
    if (cred != null) {
      setState(() {
        _usuarioCtrl.text = cred.usuario;
        _claveCtrl.text = cred.clave;
        _recordar = true;
      });
      return;
    }
    final ultimo = await SesionStorage.ultimoUsuario();
    if (!mounted || ultimo == null) return;
    setState(() => _usuarioCtrl.text = ultimo);
  }

  @override
  void dispose() {
    _usuarioCtrl.dispose();
    _claveCtrl.dispose();
    _claveFocus.dispose();
    super.dispose();
  }

  Future<void> _iniciarSesion() async {
    if (_cargando) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _intentoEnvio = true;
      _error = null;
    });
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _cargando = true);
    try {
      final usuario = await AuthService.instance.iniciarSesion(
        usuario: _usuarioCtrl.text,
        clave: _claveCtrl.text,
        recordar: _recordar,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => HomeScreen(usuario: usuario)),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.mensaje);
      if (e.noAutorizado) _claveCtrl.clear();
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Ocurrió un error inesperado. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _olvideClave() async {
    final emailCtrl = TextEditingController(
      text: Validadores.esEmail(_usuarioCtrl.text) ? _usuarioCtrl.text.trim() : '',
    );
    final formKey = GlobalKey<FormState>();
    var enviando = false;

    final enviado = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text('Recuperar contraseña'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Te enviaremos las instrucciones al correo registrado.',
                  style: TextStyle(color: AppColors.textoSecundario),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  autofocus: true,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: Validadores.email,
                  decoration: const InputDecoration(
                    hintText: 'usuario@cecar.edu.co',
                    prefixIcon: Icon(Icons.mail_outline),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: enviando ? null : () => Navigator.pop(ctx, false),
              child: const Text('Cancelar',
                  style: TextStyle(color: AppColors.textoSecundario)),
            ),
            TextButton(
              onPressed: enviando
                  ? null
                  : () async {
                      if (!(formKey.currentState?.validate() ?? false)) return;
                      setStateDialog(() => enviando = true);
                      try {
                        await AuthService.instance
                            .recuperarClave(emailCtrl.text);
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      } on ApiException catch (e) {
                        setStateDialog(() => enviando = false);
                        if (mounted) mostrarMensaje(context, e.mensaje, error: true);
                      }
                    },
              child: enviando
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Enviar'),
            ),
          ],
        ),
      ),
    );
    Future.delayed(const Duration(milliseconds: 500), emailCtrl.dispose);
    if (enviado == true && mounted) {
      mostrarMensaje(context,
          'Si el correo está registrado, recibirás las instrucciones en unos minutos.');
    }
  }

  void _copiarSoporte() {
    copiarTexto(context, _correoSoporte,
        titulo: 'Soporte técnico',
        mensajeOk: 'Correo de soporte copiado: $_correoSoporte');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                children: [
                  _encabezado(),
                  const SizedBox(height: 22),
                  _formulario(),
                  const SizedBox(height: 22),
                  _pie(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _encabezado() {
    return Column(
      children: [
        const KallosLogo(alto: 150, completo: true),
        const SizedBox(height: 10),
        const Text('Panel de Administración y Gestión',
            style: TextStyle(fontSize: 13, color: AppColors.textoSecundario)),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.superficie,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.borde),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                    color: AppColors.primario, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              const Text('SISTEMA OPERATIVO V2.4',
                  style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 0.6,
                      fontWeight: FontWeight.w600,
                      color: AppColors.texto)),
            ],
          ),
        ),
        if (ApiConfig.modoDemo) ...[
          const SizedBox(height: 10),
          Text(
            'Modo demo · ${DemoData.emailDemo} / ${DemoData.claveDemo}',
            style: const TextStyle(fontSize: 11, color: AppColors.textoTenue),
          ),
        ],
      ],
    );
  }

  Widget _etiquetaCampo(String texto) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(texto,
            style: const TextStyle(fontSize: 13, color: AppColors.texto)),
      );

  Widget _formulario() {
    return TarjetaKallos(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      child: Form(
        key: _formKey,
        autovalidateMode: _intentoEnvio
            ? AutovalidateMode.onUserInteraction
            : AutovalidateMode.disabled,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _etiquetaCampo('Usuario'),
              TextFormField(
                controller: _usuarioCtrl,
                enabled: !_cargando,
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                autofillHints: const [AutofillHints.email, AutofillHints.username],
                inputFormatters: [LengthLimitingTextInputFormatter(100)],
                validator: Validadores.usuario,
                onFieldSubmitted: (_) => _claveFocus.requestFocus(),
                decoration: const InputDecoration(
                  hintText: 'Ingresa tu usuario',
                  prefixIcon: Icon(Icons.person_outline, size: 20),
                ),
              ),
              const SizedBox(height: 16),
              _etiquetaCampo('Contraseña'),
              TextFormField(
                controller: _claveCtrl,
                focusNode: _claveFocus,
                enabled: !_cargando,
                obscureText: !_verClave,
                textInputAction: TextInputAction.done,
                autocorrect: false,
                enableSuggestions: false,
                autofillHints: const [AutofillHints.password],
                inputFormatters: [LengthLimitingTextInputFormatter(64)],
                validator: Validadores.clave,
                onFieldSubmitted: (_) => _iniciarSesion(),
                decoration: InputDecoration(
                  hintText: '••••••••••••',
                  prefixIcon: const Icon(Icons.lock_outline, size: 20),
                  suffixIcon: IconButton(
                    tooltip: _verClave ? 'Ocultar contraseña' : 'Ver contraseña',
                    icon: Icon(
                      _verClave
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _verClave = !_verClave),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      value: _recordar,
                      onChanged: _cargando
                          ? null
                          : (v) => setState(() => _recordar = v ?? false),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: _cargando
                          ? null
                          : () => setState(() => _recordar = !_recordar),
                      child: const Text('Recordar sesión',
                          style: TextStyle(fontSize: 13)),
                    ),
                  ),
                  TextButton(
                    onPressed: _cargando ? null : _olvideClave,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 30),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('¿Olvidaste tu contraseña?',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.errorSuave,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 18, color: AppColors.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_error!,
                            style: const TextStyle(
                                fontSize: 13, color: AppColors.error)),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _cargando ? null : _iniciarSesion,
                child: _cargando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Iniciar Sesión'),
                          SizedBox(width: 6),
                          Icon(Icons.arrow_forward, size: 18),
                        ],
                      ),
              ),
              const SizedBox(height: 18),
              const DivisorTexto('ACCESO RÁPIDO'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pie() {
    return Column(
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.verified_user_outlined,
                size: 16, color: AppColors.texto),
            SizedBox(width: 6),
            Text('Acceso restringido',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Únicamente a administradores y personal autorizado.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: AppColors.textoSecundario),
        ),
        const SizedBox(height: 12),
        const Divider(),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: _copiarSoporte,
          child: const Text.rich(
            TextSpan(
              text: 'Soporte técnico: ',
              style: TextStyle(fontSize: 12, color: AppColors.textoSecundario),
              children: [
                TextSpan(
                  text: _correoSoporte,
                  style: TextStyle(
                    color: AppColors.primario,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
