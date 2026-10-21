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
          idLibro: datos.codigo,
          titulo: datos.titulo,
          iglesia: datos.iglesia,
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
    final colors = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: colors.primary),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Paso 1 de 2 · Registra los datos del libro. Después podrás '
                    'fotografiar cada página para transcribirla.',
                    style: TextStyle(
                      fontSize: 13,
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'El backend transcribe cada página con Gemini. Las imágenes '
              'se procesan para obtener el texto y no se guardan como parte '
              'del libro. Mantén la conexión a Internet para usar este servicio.',
              style: TextStyle(color: colors.onPrimaryContainer, fontSize: 13),
            ),
          ),
          const SizedBox(height: 20),
          BookFormView(onEnviar: (datos) => _empezarEscaneo(context, datos)),
        ],
      ),
    );
  }
}
