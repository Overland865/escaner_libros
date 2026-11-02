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
      onGuardado();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Encabezado Editorial Stitch (Fase I: Catalogación)
          Row(
            children: [
              Icon(
                Icons.auto_stories_outlined,
                size: 16,
                color: theme.colorScheme.secondary,
              ),
              const SizedBox(width: 6),
              Text(
                'ARCHIVO HISTÓRICO DIGITAL',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.8,
                  color: theme.colorScheme.secondary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: theme.colorScheme.secondary.withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  'Fase I: Catalogación',
                  style: TextStyle(
                    fontFamily: 'Newsreader',
                    fontStyle: FontStyle.italic,
                    fontSize: 11.5,
                    color: theme.colorScheme.secondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Ficha Bibliográfica del Tomo',
            style: TextStyle(
              fontFamily: 'Literata',
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Registre los datos de edición antes de iniciar la captura óptica pliego a pliego con alineación asistida.',
            style: TextStyle(
              fontFamily: 'Newsreader',
              fontStyle: FontStyle.italic,
              fontSize: 13.5,
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 18),

          BookFormView(onEnviar: (datos) => _empezarEscaneo(context, datos)),
          const SizedBox(height: 16),

          // Nota técnica de archivo al pie
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.center_focus_strong_outlined,
                  size: 20,
                  color: theme.colorScheme.secondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Calibración Óptica y Transcripción Gemini',
                        style: TextStyle(
                          fontFamily: 'Literata',
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'El escáner incluye guías de lomo central, filtro de pergamino cálido y reconocimiento automático de tipografías clásicas.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Pantalla dedicada a la digitalización con cámara, accesible desde el botón flotante o accesos rápidos.
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
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(
              Icons.document_scanner_outlined,
              size: 20,
              color: theme.colorScheme.secondary,
            ),
            const SizedBox(width: 8),
            const Text(
              'Escanear libro con cámara',
              style: TextStyle(
                fontFamily: 'Literata',
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      body: ScanTab(biblioteca: biblioteca, onGuardado: onGuardado),
    );
  }
}
