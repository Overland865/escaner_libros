import 'package:flutter/material.dart';

import '../controllers/biblioteca_controller.dart';
import '../controllers/theme_controller.dart';
import '../services/api_service.dart';
import 'tabs/home_tab.dart';
import 'tabs/library_tab.dart';
import 'tabs/scan_tab.dart';
import 'widgets/login_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _autenticado = false;
  String? _mensaje;

  @override
  void initState() {
    super.initState();
    ApiService.onAuthenticationRequired = _credencialesRechazadas;
    _autenticado = false;
  }

  @override
  void dispose() {
    ApiService.onAuthenticationRequired = null;
    super.dispose();
  }

  void _credencialesRechazadas() {
    if (!mounted) return;
    setState(() {
      _autenticado = false;
      _mensaje = 'Las credenciales ya no son válidas. Vuelve a ingresarlas.';
    });
  }

  void _credencialesValidadas() {
    setState(() {
      _autenticado = true;
      _mensaje = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_autenticado) {
      return LoginScreen(
        mensajeInicial: _mensaje,
        onCredencialesValidadas: _credencialesValidadas,
      );
    }
    return _AppShell(onCerrarSesion: _cerrarAcceso);
  }

  void _cerrarAcceso() {
    setState(() {
      _autenticado = false;
      _mensaje = null;
    });
  }
}

class _AppShell extends StatefulWidget {
  final VoidCallback onCerrarSesion;

  const _AppShell({required this.onCerrarSesion});

  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> {
  late final BibliotecaController _biblioteca;
  int _indice = 0;

  static const _titulos = ['Inicio', 'Mi Biblioteca'];

  @override
  void initState() {
    super.initState();
    _biblioteca = BibliotecaController()..cargar();
  }

  @override
  void dispose() {
    _biblioteca.dispose();
    super.dispose();
  }

  void _irA(int indice) => setState(() => _indice = indice);

  void _irALibros() => _irA(1);

  void _abrirEscaneo() {
    ScanBookScreen.abrir(
      context,
      biblioteca: _biblioteca,
      onGuardado: _irALibros,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.secondary,
                    theme.colorScheme.tertiary,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.secondary.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.auto_stories_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _titulos[_indice],
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                      color: theme.colorScheme.onSurface,
                      letterSpacing: -0.2,
                    ),
                  ),
                  Text(
                    'Biblioteca Digital',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_outlined,
            ),
            tooltip: isDark ? 'Cambiar a modo claro' : 'Cambiar a modo oscuro',
            onPressed: () => ThemeController.instance.alternarTema(),
          ),
          IconButton(
            icon: const Icon(Icons.camera_alt_outlined),
            tooltip: 'Escanear libro con cámara',
            onPressed: _abrirEscaneo,
          ),
        ],
      ),
      body: IndexedStack(
        index: _indice,
        children: [
          HomeTab(
            biblioteca: _biblioteca,
            onEscanear: _abrirEscaneo,
            onVerLibros: _irALibros,
          ),
          LibraryTab(biblioteca: _biblioteca),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: theme.colorScheme.secondary,
        foregroundColor: theme.colorScheme.onSecondary,
        elevation: 3,
        onPressed: _abrirEscaneo,
        icon: const Icon(Icons.add_a_photo_outlined),
        label: const Text(
          '+ Añadir libro',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.3),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: theme.colorScheme.outlineVariant, width: 1),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _indice,
          onDestinationSelected: _irA,
          elevation: 0,
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.local_library_outlined),
              selectedIcon: Icon(Icons.local_library_rounded, color: theme.colorScheme.secondary),
              label: 'Inicio',
            ),
            NavigationDestination(
              icon: const Icon(Icons.auto_stories_outlined),
              selectedIcon: Icon(Icons.auto_stories_rounded, color: theme.colorScheme.secondary),
              label: 'Biblioteca',
            ),
          ],
        ),
      ),
    );
  }
}
