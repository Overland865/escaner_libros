import 'package:flutter/material.dart';

import '../../controllers/biblioteca_controller.dart';
import '../../services/gemini_config.dart';
import '../../services/gemini_vision_service.dart';
import '../scan_screen.dart';
import '../widgets/book_form_view.dart';

/// Pestaña 2 — Captura de los metadatos y arranque del escaneo con cámara.
class ScanTab extends StatelessWidget {
  final BibliotecaController biblioteca;
  final VoidCallback onGuardado;

  const ScanTab({super.key, required this.biblioteca, required this.onGuardado});

  Future<void> _empezarEscaneo(BuildContext context, DatosLibroForm datos) async {
    final exito = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ScanScreen(
          idLibro: datos.codigo,
          titulo: datos.titulo,
          iglesia: datos.iglesia,
          tipoLibro: datos.tipoLibro,
          anioInicio: datos.anioInicio,
          anioFin: datos.anioFin,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFE8EAF6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Color(0xFF283593)),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Paso 1 de 2 · Registra los datos del libro. Después podrás '
                    'fotografiar cada página para transcribirla.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF1A237E)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const _TarjetaEstadoGemini(),
          const SizedBox(height: 20),
          BookFormView(
            onEnviar: (datos) => _empezarEscaneo(context, datos),
          ),
        ],
      ),
    );
  }
}

class _TarjetaEstadoGemini extends StatefulWidget {
  const _TarjetaEstadoGemini();

  @override
  State<_TarjetaEstadoGemini> createState() => _TarjetaEstadoGeminiState();
}

class _TarjetaEstadoGeminiState extends State<_TarjetaEstadoGemini> {
  bool _verificando = false;
  String? _resultadoMensaje;
  bool? _resultadoOk;

  Future<void> _verificar() async {
    setState(() {
      _verificando = true;
      _resultadoMensaje = null;
      _resultadoOk = null;
    });

    final res = await GeminiVisionService.probarConexion();

    if (!mounted) return;
    setState(() {
      _verificando = false;
      _resultadoOk = res['ok'] as bool? ?? false;
      _resultadoMensaje = res['mensaje'] as String? ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final configurado = GeminiConfig.estaConfigurado;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: configurado ? const Color(0xFFF0F4FF) : Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: configurado ? const Color(0xFFC5CAE9) : Colors.amber.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                configurado ? Icons.auto_awesome : Icons.warning_amber,
                size: 20,
                color: configurado ? const Color(0xFF283593) : Colors.amber.shade900,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  configurado
                      ? 'Motor IA: Gemini Vision (${GeminiConfig.modelo})'
                      : 'Motor Local: ML Kit (Sin clave de Gemini)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: configurado
                        ? const Color(0xFF1A237E)
                        : Colors.amber.shade900,
                  ),
                ),
              ),
              if (configurado)
                TextButton(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  onPressed: _verificando ? null : _verificar,
                  child: _verificando
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Probar API',
                          style: TextStyle(fontSize: 12),
                        ),
                ),
            ],
          ),
          if (_resultadoMensaje != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  _resultadoOk == true ? Icons.check_circle : Icons.error_outline,
                  size: 15,
                  color: _resultadoOk == true ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _resultadoMensaje!,
                    style: TextStyle(
                      fontSize: 12,
                      color: _resultadoOk == true
                          ? Colors.green.shade900
                          : Colors.red.shade900,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

