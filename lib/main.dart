import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'controllers/biblioteca_controller.dart';
import 'services/api_service.dart';
import 'views/tabs/home_tab.dart';
import 'views/tabs/library_tab.dart';
import 'views/tabs/scan_tab.dart';
import 'views/widgets/backend_connection_sheet.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('Aviso al cargar el archivo .env: $e');
  }
  await ApiService.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Biblioteca Eclesiástica',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF283593), // Indigo eclesiástico
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF101116),
        cardTheme: const CardThemeData(
          color: Color(0xFF1B1C24),
          surfaceTintColor: Colors.transparent,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          backgroundColor: Color(0xFF171820),
          foregroundColor: Color(0xFFE6E1F5),
          surfaceTintColor: Colors.transparent,
        ),
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: Color(0xFF171820),
          indicatorColor: Color(0xFF39345C),
          labelTextStyle: WidgetStatePropertyAll(
            TextStyle(color: Color(0xFFE6E1F5)),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Color(0xFF23242D),
          hintStyle: TextStyle(color: Color(0xFFB9B4C7)),
          labelStyle: TextStyle(color: Color(0xFFCAC4D8)),
          prefixIconColor: Color(0xFFC6BFFF),
          suffixIconColor: Color(0xFFC6BFFF),
          border: OutlineInputBorder(
            borderSide: BorderSide(color: Color(0xFF494653)),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Color(0xFF494653)),
          ),
        ),
      ),
      home: const AppShell(),
    );
  }
}

/// Contenedor raíz de la interfaz por pestañas.
///
/// Usa `IndexedStack` para que cada pestaña conserve su estado (scroll,
/// texto del buscador, etc.) al cambiar de una a otra.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
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
