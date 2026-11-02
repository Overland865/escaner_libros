import 'dart:math' as math;

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
  bool _ocultarContrasena = true;
  bool _mantenerSesion = true;
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 24,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Emblema Ex Libris circular (80x80)
                  SizedBox(
                    width: 84,
                    height: 88,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainer,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: theme.colorScheme.secondary
                                  .withValues(alpha: 0.4),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(
                                  alpha: isDark ? 0.35 : 0.08,
                                ),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Container(
                              width: 66,
                              height: 66,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: theme.colorScheme.secondary
                                      .withValues(alpha: 0.25),
                                  width: 1,
                                ),
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Icon(
                                    Icons.auto_stories_outlined,
                                    size: 32,
                                    color: theme.colorScheme.primary,
                                  ),
                                  Transform.translate(
                                    offset: const Offset(10, -8),
                                    child: Transform.rotate(
                                      angle: -math.pi / 15,
                                      child: Icon(
                                        Icons.history_edu_rounded,
                                        size: 20,
                                        color: theme.colorScheme.secondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.secondary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: theme.scaffoldBackgroundColor,
                                width: 2,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: const Text(
                              '✦',
                              style: TextStyle(
                                fontSize: 10,
                                color: Color(0xFFFCF9F4),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Título Clásico Literata
                  Text(
                    'Biblioteca Digital',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Literata',
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Ornamento tipográfico — ❦ —
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 48,
                        height: 1,
                        color: theme.colorScheme.outlineVariant,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          '❦',
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.colorScheme.secondary,
                          ),
                        ),
                      ),
                      Container(
                        width: 48,
                        height: 1,
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),

                  // Tarjeta de Pergamino con lomo de cuero vertical a la izquierda
                  Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: theme.cardTheme.color,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant,
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isDark ? 0.35 : 0.07,
                          ),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        // Franja de lomo de cuero a la izquierda
                        Positioned(
                          top: 0,
                          bottom: 0,
                          left: 0,
                          width: 4,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  theme.colorScheme.secondary,
                                  theme.colorScheme.primary,
                                  theme.colorScheme.secondary,
                                ],
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 26, 22, 26),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Etiqueta superior Usuario
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'IDENTIFICADOR DE ARCHIVERO',
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.2,
                                          color: theme
                                              .colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Requerido',
                                      style: TextStyle(
                                        fontFamily: 'Newsreader',
                                        fontStyle: FontStyle.italic,
                                        fontSize: 11,
                                        color: theme.colorScheme.secondary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _usuarioController,
                                  autofocus: true,
                                  autocorrect: false,
                                  textInputAction: TextInputAction.next,
                                  decoration: InputDecoration(
                                    labelText: 'Usuario',
                                    hintText: 'ej. a.mendoza@archivo.org',
                                    prefixIcon: Icon(
                                      Icons.edit_note_rounded,
                                      color: theme.colorScheme.secondary,
                                    ),
                                  ),
                                  validator: (value) =>
                                      value == null || value.trim().isEmpty
                                          ? 'Escribe el usuario.'
                                          : null,
                                ),
                                const SizedBox(height: 16),

                                // Etiqueta superior Contraseña
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'CLAVE DE CUSTODIA',
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.2,
                                          color: theme
                                              .colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Credencial compartida',
                                      style: TextStyle(
                                        fontFamily: 'Newsreader',
                                        fontStyle: FontStyle.italic,
                                        fontSize: 11,
                                        color: theme.colorScheme.secondary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _contrasenaController,
                                  obscureText: _ocultarContrasena,
                                  autocorrect: false,
                                  enableSuggestions: false,
                                  textInputAction: TextInputAction.done,
                                  onFieldSubmitted: (_) => _iniciarSesion(),
                                  decoration: InputDecoration(
                                    labelText: 'Contraseña',
                                    prefixIcon: Icon(
                                      Icons.key_rounded,
                                      color: theme.colorScheme.secondary,
                                    ),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _ocultarContrasena
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                        size: 19,
                                        color: theme
                                            .colorScheme.onSurfaceVariant,
                                      ),
                                      onPressed: () => setState(
                                        () => _ocultarContrasena =
                                            !_ocultarContrasena,
                                      ),
                                    ),
                                  ),
                                  validator: (value) =>
                                      value == null || value.isEmpty
                                          ? 'Escribe la contraseña.'
                                          : null,
                                ),
                                const SizedBox(height: 10),

                                // Casilla de sesión activa
                                InkWell(
                                  borderRadius: BorderRadius.circular(6),
                                  onTap: () => setState(
                                    () => _mantenerSesion = !_mantenerSesion,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: Checkbox(
                                            value: _mantenerSesion,
                                            activeColor:
                                                theme.colorScheme.secondary,
                                            onChanged: (v) => setState(
                                              () => _mantenerSesion =
                                                  v ?? true,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Mantener sesión activa durante esta jornada',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: theme.colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                if (_error != null) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.error
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: theme.colorScheme.error
                                            .withValues(alpha: 0.4),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.error_outline,
                                          size: 18,
                                          color: theme.colorScheme.error,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _error!,
                                            style: TextStyle(
                                              color: theme.colorScheme.error,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 20),

                                // Botón Primario: Conectar
                                SizedBox(
                                  height: 50,
                                  child: FilledButton(
                                    onPressed: _enviando ? null : _iniciarSesion,
                                    style: FilledButton.styleFrom(
                                      backgroundColor:
                                          theme.colorScheme.primary,
                                      foregroundColor:
                                          theme.colorScheme.onPrimary,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: _enviando
                                        ? SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.2,
                                              color:
                                                  theme.colorScheme.onPrimary,
                                            ),
                                          )
                                        : const Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                'Conectar',
                                                style: TextStyle(
                                                  fontFamily: 'Literata',
                                                  fontSize: 15.5,
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: 0.3,
                                                ),
                                              ),
                                              SizedBox(width: 8),
                                              Icon(
                                                Icons.arrow_forward_rounded,
                                                size: 18,
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
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
}
