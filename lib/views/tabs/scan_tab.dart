import 'package:flutter/material.dart';

import '../../controllers/biblioteca_controller.dart';
import '../scan_screen.dart';
import '../widgets/book_form_view.dart';

/// Pestaña 2 — Captura de los metadatos y arranque del escaneo con cámara.
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
