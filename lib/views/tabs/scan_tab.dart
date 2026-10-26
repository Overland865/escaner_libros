import 'package:flutter/material.dart';

import '../../controllers/biblioteca_controller.dart';
import '../scan_screen.dart';
import '../widgets/book_form_view.dart';

/// Pestaña o vista para captura de metadatos y arranque del escaneo con cámara.
class ScanTab extends StatelessWidget {
  final BibliotecaController biblioteca;
  final VoidCallback onGuardado;

  const ScanTab({
    super.key,
    required this.biblioteca,
    required this.onGuardado,
  });

  Future<void> _empezarEscaneo(
    BuildContext context,
    DatosLibroForm datos,
  ) async {
    final exito = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ScanScreen(
          idLibro: 'LIB-${DateTime.now().toUtc().microsecondsSinceEpoch}',
          titulo: datos.titulo,
          autor: datos.autor,
          editorial: datos.editorial,
          tipoLibro: datos.tipoLibro,
          anioPublicacion: datos.anioPublicacion,
          biblioteca: biblioteca,
        ),
      ),
    );

    if (exito == true) {
      // guardarLibro ya refresca la lista; solo navegamos a Libros.
      onGuardado();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      child: BookFormView(onEnviar: (datos) => _empezarEscaneo(context, datos)),
    );
  }
}

/// Pantalla dedicada a la digitalización con cámara, accesible desde el botón flotante.
class ScanBookScreen extends StatelessWidget {
  final BibliotecaController biblioteca;
  final VoidCallback onGuardado;

  const ScanBookScreen({
    super.key,
    required this.biblioteca,
    required this.onGuardado,
  });

  static Future<void> abrir(
    BuildContext context, {
    required BibliotecaController biblioteca,
    required VoidCallback onGuardado,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (ctx) => ScanBookScreen(
          biblioteca: biblioteca,
          onGuardado: () {
            Navigator.of(ctx).pop();
            onGuardado();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Escanear libro con cámara'),
      ),
      body: ScanTab(
        biblioteca: biblioteca,
        onGuardado: onGuardado,
      ),
    );
  }
}
