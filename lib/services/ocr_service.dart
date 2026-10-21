import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'api_service.dart';

/// Transcribe una imagen de página.
///
/// Primero transcribe en el backend, que mantiene protegida la clave de Gemini.
/// Si el backend no está disponible, usa Google ML Kit localmente.
class OcrService {
  final _mlKitRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  Future<Map<String, dynamic>> procesarImagenDetallado(
    String pathImagen,
  ) async {
    // La imagen solo se envía al backend para esta petición; la app conserva el texto.
    try {
      final texto = await ApiService.transcribirImagen(pathImagen);
      return {'texto': texto, 'motor': 'Gemini (Backend)', 'exito': true};
    } catch (eBackend) {
      debugPrint(
        'Transcripción en backend no disponible ($eBackend). Usando ML Kit local.',
      );
      final motivoBackend = _acortar(eBackend.toString());

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
