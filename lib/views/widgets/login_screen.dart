import 'package:flutter/material.dart';

import '../../services/api_service.dart';

class LoginScreen extends StatefulWidget {
  final String? mensajeInicial;
  final VoidCallback onCredencialesValidadas;

  const LoginScreen({
    super.key,
    required this.onCredencialesValidadas,
    this.mensajeInicial,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usuarioController = TextEditingController();
  final _contrasenaController = TextEditingController();
  bool _enviando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _error = widget.mensajeInicial;
  }

  @override
  void dispose() {
    _usuarioController.dispose();
    _contrasenaController.dispose();
    super.dispose();
  }

  Future<void> _iniciarSesion() async {
    if (_enviando || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _enviando = true;
      _error = null;
    });

    try {
      await ApiService.validarCredenciales(
        _usuarioController.text.trim(),
        _contrasenaController.text,
      );
      if (mounted) widget.onCredencialesValidadas();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.lock_outline, size: 52, color: colors.primary),
                  const SizedBox(height: 16),
                  Text(
                    'Acceso al backend',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ingresa las credenciales compartidas configuradas en el servidor. No se guardarán en este dispositivo.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 28),
                  TextFormField(
                    controller: _usuarioController,
                    autofocus: true,
                    autocorrect: false,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Usuario',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Escribe el usuario.'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _contrasenaController,
                    obscureText: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _iniciarSesion(),
                    decoration: const InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: Icon(Icons.password_outlined),
                    ),
                    validator: (value) => value == null || value.isEmpty
                        ? 'Escribe la contraseña.'
                        : null,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colors.error),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _enviando ? null : _iniciarSesion,
                    child: _enviando
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Conectar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
