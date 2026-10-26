import 'package:flutter/material.dart';

import '../services/api_service.dart';
import 'widgets/login_screen.dart';
import 'tabs/home_tab.dart';
import 'tabs/library_tab.dart';
import 'tabs/scan_tab.dart';
import 'tabs/upload_pdf_tab.dart';
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

  static const _titulos = ['Inicio', 'Subir PDF', 'Libros'];

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

  void _abrirEscaneo() {
    ScanBookScreen.abrir(
      context,
      biblioteca: _biblioteca,
      onGuardado: _irALibros,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF818CF8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.35),
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
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                      color: Color(0xFFF1F0FB),
                      letterSpacing: -0.2,
                    ),
                  ),
                  const Text(
                    'Biblioteca Digital',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF9499B3),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
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
          UploadPdfTab(biblioteca: _biblioteca, onGuardado: _irALibros),
          LibraryTab(biblioteca: _biblioteca),
        ],
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6366F1).withValues(alpha: 0.45),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          elevation: 0,
          highlightElevation: 0,
          focusElevation: 0,
          hoverElevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          onPressed: _abrirEscaneo,
          icon: const Icon(Icons.camera_alt),
          label: const Text(
            'Escanear',
            style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.3),
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: Color(0xFF1E2235), width: 1),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _indice,
          onDestinationSelected: _irA,
          backgroundColor: const Color(0xFF10121C),
          indicatorColor: const Color(0xFF282C44),
          elevation: 0,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded, color: Color(0xFF818CF8)),
              label: 'Inicio',
            ),
            NavigationDestination(
              icon: Icon(Icons.picture_as_pdf_outlined),
              selectedIcon: Icon(Icons.picture_as_pdf, color: Color(0xFF818CF8)),
              label: 'Subir PDF',
            ),
            NavigationDestination(
              icon: Icon(Icons.library_books_outlined),
              selectedIcon: Icon(Icons.library_books, color: Color(0xFF818CF8)),
              label: 'Libros',
            ),
          ],
        ),
      ),
    );
  }
}
