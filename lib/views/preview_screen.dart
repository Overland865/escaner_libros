import 'package:flutter/material.dart';

import '../controllers/biblioteca_controller.dart';
import '../models/libro_local.dart';
import '../models/libro_model.dart';
import 'widgets/backend_connection_sheet.dart';

/// Revisión del texto transcrito antes de guardarlo (local + sync si hay red).
/// Devuelve `true` al navigation si el libro quedó guardado en el dispositivo.
class PreviewScreen extends StatefulWidget {
  final LibroModel libro;
  final BibliotecaController biblioteca;

  const PreviewScreen({
    super.key,
    required this.libro,
    required this.biblioteca,
  });

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  bool _enviando = false;
  String? _error;

  Future<void> _guardar() async {
    if (_enviando) return;
    setState(() {
      _enviando = true;
      _error = null;
    });

    try {
      final ResultadoGuardado resultado = await widget.biblioteca.guardarLibro(
        widget.libro,
      );
      if (!mounted) return;

      final icono = resultado.sincronizado
          ? Icons.cloud_done
          : Icons.phone_android;
      final titulo = resultado.sincronizado
          ? 'Guardado y sincronizado'
          : 'Guardado en el dispositivo';

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          icon: Icon(icono, color: const Color(0xFF283593), size: 40),
          title: Text(titulo),
          content: Text(
            '${resultado.mensaje}\n\n"${widget.libro.titulo}" con '
            '${pags(widget.libro.paginas.length)}.',
            textAlign: TextAlign.center,
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Aceptar'),
            ),
          ],
        ),
      );

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _enviando = false;
        _error = e.toString();
      });
    }
  }

  Widget _badgeMotor(String? motor) {
    final motorTexto = motor ?? 'Desconocido';
    final esGemini = motorTexto.toLowerCase().contains('gemini');
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: esGemini ? colors.primaryContainer : colors.tertiaryContainer,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: esGemini ? colors.primary : colors.tertiary,
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            esGemini ? Icons.auto_awesome : Icons.document_scanner,
            size: 13,
            color: esGemini ? colors.primary : colors.onTertiaryContainer,
          ),
          const SizedBox(width: 4),
          Text(
            esGemini ? 'Gemini AI' : 'ML Kit Local',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: esGemini ? colors.primary : colors.onTertiaryContainer,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final paginas = widget.libro.paginas;
    final caracteres = paginas.fold<int>(0, (sum, p) => sum + p.texto.length);
    final palabras = paginas.fold<int>(0, (sum, p) => sum + p.conteoPalabras);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Revisión de Texto Extraído'),
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud_outlined),
            tooltip: 'Conexión del backend',
            onPressed: () => showBackendConnectionSheet(
              context,
              onRetry: () async => setState(() {}),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.libro.titulo,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${pags(paginas.length)} · $palabras palabras · '
                  '$caracteres caracteres',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (_error != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Theme.of(context).colorScheme.error),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 20,
                        color: Colors.red.shade700,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: _enviando ? null : _guardar,
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text(
                          'Reintentar',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: paginas.length,
              itemBuilder: (context, index) {
                final pag = paginas[index];
                return ExpansionTile(
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Página ${pag.numeroPagina} (${pag.conteoPalabras} palabras)',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      _badgeMotor(pag.motor),
                    ],
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: SelectableText(
                        pag.texto.trim().isEmpty
                            ? '[Sin texto detectado]'
                            : pag.texto,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _enviando ? null : _guardar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF283593),
                    foregroundColor: Colors.white,
                  ),
                  icon: _enviando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save),
                  label: Text(_enviando ? 'Guardando...' : 'Guardar libro'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String pags(int n) => n == 1 ? '1 página' : '$n páginas';
}
