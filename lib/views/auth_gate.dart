import 'package:flutter/material.dart';

import '../services/api_service.dart';
import 'widgets/login_screen.dart';
import 'widgets/backend_connection_sheet.dart';
import 'tabs/home_tab.dart';
import 'tabs/library_tab.dart';
import 'tabs/scan_tab.dart';
import '../controllers/biblioteca_controller.dart';

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

  static const _titulos = ['Inicio', 'Digitalizar', 'Libros'];

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

  void _irALibros() => _irA(2);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.history_edu, color: Color(0xFF283593), size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _titulos[_indice],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    'Biblioteca Eclesiástica',
                    style: TextStyle(fontSize: 11, color: Color(0xFFB9B4C7)),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (_indice != 1)
            IconButton(
              icon: const Icon(Icons.camera_alt_outlined),
              tooltip: 'Digitalizar libro',
              onPressed: () => _irA(1),
            ),
        ],
      ),
      body: IndexedStack(
        index: _indice,
        children: [
          HomeTab(
            biblioteca: _biblioteca,
            onEscanear: () => _irA(1),
            onVerLibros: _irALibros,
          ),
          ScanTab(biblioteca: _biblioteca, onGuardado: _irALibros),
          LibraryTab(biblioteca: _biblioteca),
        ],
      ),
      floatingActionButton: _indice == 1
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _irA(1),
              backgroundColor: const Color(0xFF283593),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.document_scanner),
              label: const Text('Digitalizar'),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indice == 2 ? 2 : 0,
        onDestinationSelected: (indice) {
          switch (indice) {
            case 0:
              _irA(0);
            case 1:
              showBackendConnectionSheet(
                context,
                onRetry: _biblioteca.refrescar,
                onLogout: widget.onCerrarSesion,
              );
            case 2:
              _irA(2);
          }
        },
        backgroundColor: const Color(0xFF171820),
        indicatorColor: const Color(0xFF39345C),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.cloud_outlined),
            selectedIcon: Icon(Icons.cloud),
            label: 'Conexión',
          ),
          NavigationDestination(
            icon: Icon(Icons.library_books_outlined),
            selectedIcon: Icon(Icons.library_books),
            label: 'Libros',
          ),
        ],
      ),
    );
  }
}
