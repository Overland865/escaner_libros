import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'gemini_config.dart';

/// El modelo configurado ya no existe en la API (fue retirado). Permite probar
/// con los modelos alternativos en lugar de caer directo a ML Kit.
class ModeloNoDisponible implements Exception {
  final String modelo;
  final String detalle;
  const ModeloNoDisponible(this.modelo, this.detalle);

  @override
  String toString() => 'El modelo "$modelo" ya no está disponible. $detalle';
}

class GeminiVisionService {
  /// La primera llamada tras un rato de inactividad puede tardar más de un
  /// minuto (arranque en frío del modelo). Con un timeout corto la app caía
  /// a ML Kit en cada foto aunque Gemini respondiera bien un instante después.
  static const Duration _timeoutGemini = Duration(seconds: 120);
  /// Transcribe una imagen con la API Multimodal de Gemini.
  ///
  /// Prueba primero con el modelo configurado. Si ese modelo fue retirado
  /// (HTTP 404), recorre automáticamente los alternativos antes de fallar:
  /// los nombres de modelo de Gemini caducan y así la app no se rompe.
  static Future<String> transcribirImagen(String pathImagen) async {
    if (!GeminiConfig.estaConfigurado) {
      throw Exception(
        'Falta GEMINI_API_KEY en el archivo .env de escaner_libros.',
      );
    }

    final file = File(pathImagen);
    if (!await file.exists()) {
      throw Exception('La imagen no existe en la ruta: $pathImagen');
    }

    final base64Image = base64Encode(await file.readAsBytes());
    final contenido = {
      'parts': [
        {'text': GeminiConfig.promptPaleografico},
        {
          'inline_data': {
            'mime_type': _mimeType(pathImagen),
            'data': base64Image,
          },
        },
      ],
    };

    final modelos = {
      GeminiConfig.modelo,
      ...GeminiConfig.modelosAlternativos,
    }.toList();

    dynamic ultimoError;
    for (final modelo in modelos) {
      try {
        return await _intentar(modelo, contenido);
      } catch (e) {
        debugPrint('⚠️ Modelo $modelo falló ($e). Probando alternativa...');
        ultimoError = e;
      }
    }
    throw Exception(
      'Ningún modelo de Gemini pudo completar la transcripción. Último detalle: $ultimoError',
    );
  }

  /// Verifica la clave y conectividad con la API de Gemini enviando un ping liviano.
  /// Retorna un mapa con { 'ok': bool, 'mensaje': String, 'modelo': String }.
  static Future<Map<String, dynamic>> probarConexion() async {
    if (!GeminiConfig.estaConfigurado) {
      return {
        'ok': false,
        'mensaje': 'Falta GEMINI_API_KEY en el archivo .env',
        'modelo': 'sin_clave',
      };
    }

    final modelos = {
      GeminiConfig.modelo,
      ...GeminiConfig.modelosAlternativos,
    }.toList();

    for (final modelo in modelos) {
      try {
        final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/'
          '$modelo:generateContent?key=${GeminiConfig.apiKey.trim()}',
        );
        final response = await http
            .post(
              url,
              headers: const {'Content-Type': 'application/json'},
              body: jsonEncode({
                'contents': [
                  {
                    'parts': [{'text': 'OK'}],
                  },
                ],
              }),
            )
            .timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          return {
            'ok': true,
            'mensaje': 'Gemini Vision conectado y listo',
            'modelo': modelo,
          };
        }
      } catch (e) {
        debugPrint('Probar $modelo dio error: $e');
      }
    }

    return {
      'ok': false,
      'mensaje': 'La clave es rechazada o los servidores de Gemini no responden.',
      'modelo': GeminiConfig.modelo,
    };
  }

  static Future<String> _intentar(
    String modelo,
    Map<String, dynamic> contenido,
  ) async {
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/'
      '$modelo:generateContent?key=${GeminiConfig.apiKey.trim()}',
    );

    debugPrint('Transcribiendo con Gemini Vision ($modelo)...');

    final response = await http
        .post(
          url,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'contents': [contenido],
            'generationConfig': {'temperature': 0.1, 'topP': 0.95},
          }),
        )
        .timeout(_timeoutGemini);

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final candidates = data['candidates'] as List?;
      if (candidates != null && candidates.isNotEmpty) {
        final parts = candidates[0]['content']?['parts'] as List?;
        if (parts != null && parts.isNotEmpty) {
          final text = parts[0]['text'] as String?;
          if (text != null && text.trim().isNotEmpty) return text.trim();
        }
      }
      throw Exception('Gemini respondió sin texto transcrito.');
    }

    final detalle = _extraerError(response);
    if (response.statusCode == 404) {
      throw ModeloNoDisponible(modelo, detalle);
    }
    throw Exception('Gemini respondió HTTP ${response.statusCode}: $detalle');
  }

  /// Extrae el mensaje real de la API de Google, que suele ser largo pero
  /// explica el motivo exacto (clave, cuota, modelo, contenido).
  static String _extraerError(http.Response res) {
    try {
      final json = jsonDecode(utf8.decode(res.bodyBytes));
      final msg = json['error']?['message'];
      if (msg is String && msg.isNotEmpty) {
        // La primera oración suele bastar y es lo accionable.
        final corte = msg.indexOf(RegExp(r'[.\n]'));
        return corte > 0 ? msg.substring(0, corte).trim() : msg.trim();
      }
    } catch (_) {
      /* respuesta no JSON */
    }
    final cuerpo = utf8.decode(res.bodyBytes).trim();
    return cuerpo.isEmpty ? 'sin detalle' : cuerpo;
  }

  /// La cámara de Android entrega JPEG y la de iOS HEIC/PNG, según el
  /// dispositivo. Declarar el mime correcto evita rechazos de la API.
  static String _mimeType(String pathImagen) {
    final ext = pathImagen.toLowerCase().split('.').last;
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'heic':
      case 'heif':
        return 'image/heic';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }
}
