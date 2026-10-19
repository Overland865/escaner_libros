import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'api_service.dart';
import 'gemini_config.dart';
import 'gemini_vision_service.dart';

/// Transcribe una imagen de página.
///
/// Arquitectura de seguridad:
/// 1. Intenta primero transcribir mediante el backend (donde GEMINI_API_KEY está protegida).
/// 2. Si el backend no está disponible o da error, intenta con Gemini directo si hay clave local.
/// 3. Como fallback final y offline, utiliza Google ML Kit localmente en el dispositivo.
class OcrService {
  final _mlKitRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  Future<Map<String, dynamic>> procesarImagenDetallado(String pathImagen) async {
    // 1) Intento primario y seguro: Backend Express (claves protegidas en el servidor)
    try {
      final texto = await ApiService.transcribirImagen(pathImagen);
      return {
        'texto': texto,
        'motor': 'Gemini (Backend)',
        'exito': true,
      };
    } catch (eBackend) {
      debugPrint('Transcripción en backend no disponible ($eBackend). Evaluando alternativas...');
      final motivoBackend = _acortar(eBackend.toString());

      // 2) Intento secundario: Gemini directo desde la app si hay clave configurada en entorno de desarrollo
      if (GeminiConfig.estaConfigurado) {
        try {
          final texto = await GeminiVisionService.transcribirImagen(pathImagen);
          return {
            'texto': texto,
            'motor': 'Gemini Directo · ${GeminiConfig.modelo}',
            'exito': true,
          };
        } catch (eGeminiDirecto) {
          final motivoGemini = _acortar(eGeminiDirecto.toString());
          debugPrint('Gemini directo falló ($motivoGemini). Recurriendo a ML Kit local...');
        }
      }

      // 3) Fallback local: ML Kit en el dispositivo
      final texto = await _procesarConMlKit(pathImagen);
      return {
        'texto': texto,
        'motor': 'ML Kit local',
        'falloGemini': motivoBackend,
        'exito': true,
      };
    }
  }

  /// Método simple compatible.
  Future<String> procesarImagen(String pathImagen) async {
    final resultado = await procesarImagenDetallado(pathImagen);
    return resultado['texto'] as String;
  }

  Future<String> _procesarConMlKit(String pathImagen) async {
    final inputImage = InputImage.fromFilePath(pathImagen);
    final RecognizedText recognizedText = await _mlKitRecognizer.processImage(
      inputImage,
    );
    return recognizedText.text;
  }

  /// Recorta el motivo para que quepa en un Snackbar sin perder lo importante.
  static String _acortar(String texto) {
    final limpio = texto.replaceAll('Exception: ', '').trim();
    if (limpio.length <= 140) return limpio;
    return '${limpio.substring(0, 137)}...';
  }

  void dispose() {
    _mlKitRecognizer.close();
  }
}
