import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Configuración de Gemini Vision para la app móvil Flutter.
///
/// La clave API se lee automáticamente desde el archivo local `.env`
/// (protegido en .gitignore) sin requerir comandos adicionales al compilar.
class GeminiConfig {
  static String _limpiar(String s) {
    var v = s.trim();
    if ((v.startsWith('"') && v.endsWith('"')) ||
        (v.startsWith("'") && v.endsWith("'"))) {
      if (v.length >= 2) v = v.substring(1, v.length - 1).trim();
    }
    return v;
  }

  /// Obtiene la clave API desde `.env` de forma automática, sin comillas residuales.
  static String get apiKey {
    final fromDotenv = dotenv.env['GEMINI_API_KEY'];
    if (fromDotenv != null && fromDotenv.trim().isNotEmpty) {
      return _limpiar(fromDotenv);
    }
    return _limpiar(
      const String.fromEnvironment('GEMINI_API_KEY', defaultValue: ''),
    );
  }

  /// Modelo multimodal recomendado para visión y transcripción rápida y exacta.
  /// Se usa `gemini-flash-latest` como principal por su alta disponibilidad y velocidad.
  static String get modelo {
    final fromDotenv = dotenv.env['GEMINI_MODEL'];
    if (fromDotenv != null && fromDotenv.trim().isNotEmpty) {
      return _limpiar(fromDotenv);
    }
    return _limpiar(
      const String.fromEnvironment(
        'GEMINI_MODEL',
        defaultValue: 'gemini-flash-latest',
      ),
    );
  }

  /// Modelos de respaldo en caso de saturación (503), retirada (404) o límites.
  static const List<String> modelosAlternativos = [
    'gemini-flash-latest',
    'gemini-3.8-flash',
    'gemini-flash-lite-latest',
  ];

  /// Prompt especializado en paleografía y documentos históricos eclesiásticos.
  static const String promptPaleografico = '''
Actúa como un paleógrafo y archivista experto en transcripción de documentos y libros eclesiásticos históricos (siglos XVI al XX).
Tu tarea es transcribir con la mayor fidelidad y exactitud posible todo el texto visible en esta imagen.

Reglas obligatorias:
1. Transcribe nombres propios, apellidos, fechas, lugares, parentescos y fórmulas religiosas exactamente como aparecen.
2. Respeta las abreviaturas y ortografía histórica de la época.
3. Conserva la división natural de párrafos y líneas.
4. Si hay partes ilegibles o manchadas, indícalas como [ilegible].
5. Devuelve ÚNICAMENTE el texto limpio transcrito. NO agregues introducciones, explicaciones, saludos ni bloques de código.
''';

  /// Retorna true si la clave API fue detectada y está lista para usarse.
  static bool get estaConfigurado => apiKey.isNotEmpty;
}
