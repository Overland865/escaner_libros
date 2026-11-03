import 'package:flutter/foundation.dart';

import 'api_service.dart';

/// Transcribe una imagen de página usando Gemini mediante el backend.
class OcrService {
  Future<Map<String, dynamic>> procesarImagenDetallado(
    String pathImagen,
  ) async {
    // La imagen se envía optimizada al backend para transcribir con Gemini.
    try {
      final texto = await ApiService.transcribirImagen(pathImagen);
      return {'texto': texto, 'motor': 'Gemini (Backend)', 'exito': true};
    } catch (eBackend) {
      debugPrint('Error en transcripción con Gemini: $eBackend');
      rethrow;
    }
  }

  /// Método simple compatible.
  Future<String> procesarImagen(String pathImagen) async {
    final resultado = await procesarImagenDetallado(pathImagen);
    return resultado['texto'] as String;
  }

  void dispose() {}
}
