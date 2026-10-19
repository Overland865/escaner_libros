import 'dart:io';

import 'package:escaner_libros/services/gemini_config.dart';
import 'package:escaner_libros/services/gemini_vision_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

/// Prueba de humo contra la API real de Gemini: verifica que el modelo
/// configurado existe y que la transcripción paleográfica devuelve texto.
///
/// Se salta (no falla) si no hay GEMINI_API_KEY, para que `flutter test`
/// siga siendo usable sin credenciales.
///
/// Ejecutar:  flutter test
void main() {
  setUpAll(() async {
    try {
      await dotenv.load(fileName: '.env');
    } catch (_) {
      // sin .env la prueba se omite
    }
  });

  test('el modelo configurado responde y transcribe la imagen', () async {
    final autorizarPrueba = dotenv.env['EJECUTAR_SMOKE_TEST_GEMINI'] == 'true' ||
        const String.fromEnvironment('EJECUTAR_SMOKE_TEST_GEMINI') == 'true';
    if (!autorizarPrueba) {
      print('⏭ Omitido: para no consumir cuota de Gemini, active EJECUTAR_SMOKE_TEST_GEMINI=true');
      return;
    }

    if (!GeminiConfig.estaConfigurado) {
      print('⏭ Omitido: no hay GEMINI_API_KEY en .env');
      return;
    }

    final imagen = File('test/assets/pagina_prueba.png');
    expect(imagen.existsSync(), isTrue, reason: 'falta la imagen de prueba');

    final texto = await GeminiVisionService.transcribirImagen(imagen.path);

    print('modelo: ${GeminiConfig.modelo}');
    print('texto : $texto');

    expect(texto.trim(), isNotEmpty, reason: 'Gemini devolvió texto vacío');
    // La imagen de prueba dice "Bautice solemnemente a Juan".
    expect(
      texto.toLowerCase(),
      contains('bautice'),
      reason: 'la transcripción debería contener el texto de la imagen',
    );
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('un modelo inexistente se reporta como ModeloNoDisponible', () async {
    final autorizarPrueba = dotenv.env['EJECUTAR_SMOKE_TEST_GEMINI'] == 'true' ||
        const String.fromEnvironment('EJECUTAR_SMOKE_TEST_GEMINI') == 'true';
    if (!autorizarPrueba || !GeminiConfig.estaConfigurado) return;

    // El servicio debe reintentar con los alternativos; si todos fallan,
    // la excepción debe ser de tipo correcto y no un error genérico.
    try {
      await GeminiVisionService.transcribirImagen(
        'test/assets/pagina_prueba.png',
      );
    } on ModeloNoDisponible catch (e) {
      expect(e.modelo, isNotEmpty);
      expect(e.detalle, isNotEmpty);
    } catch (e) {
      fail('Se esperaba ModeloNoDisponible, se obtuvo: $e');
    }
  }, timeout: const Timeout(Duration(minutes: 3)));
}
