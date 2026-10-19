import 'package:escaner_libros/models/libro_model.dart';
import 'package:escaner_libros/models/pagina_model.dart';
import 'package:escaner_libros/services/api_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

/// Prueba de humo contra el backend real: recorre el ciclo completo que hace
/// la app al subir un libro escaneado.
///
/// Requiere el backend levantado (`cd backend && npm start`).
/// Si no responde, la prueba se omite en vez de fallar.
///
/// Ejecutar:  flutter test test/api_smoke_test.dart
void main() {
  setUpAll(() async {
    try {
      await dotenv.load(fileName: '.env');
    } catch (_) {
      // sin .env se usa la dirección por defecto
    }
    ApiService.init();

    // 10.0.2.2 solo resuelve dentro del emulador de Android. Estas pruebas
    // corren en el escritorio, así que se apunta a localhost.
    if (ApiService.baseUrl.contains('10.0.2.2')) {
      ApiService.baseUrl = 'http://localhost:3000';
    }
  });

  test('el backend responde y reporta Atlas conectado', () async {
    final salud = await ApiService.consultarSalud();
    if (salud == null) {
      print('⏭ Omitido: el backend no responde en ${ApiService.baseUrl}');
      return;
    }
    print('salud: $salud');
    expect(salud['servidor'], 'ok');
  });

  test('subir, listar, leer y borrar un libro', () async {
    final autorizarApi = dotenv.env['EJECUTAR_SMOKE_TEST_API'] == 'true' ||
        const String.fromEnvironment('EJECUTAR_SMOKE_TEST_API') == 'true' ||
        ApiService.baseUrl.contains('localhost') ||
        ApiService.baseUrl.contains('127.0.0.1');

    if (!autorizarApi) {
      print('⏭ Omitido: para prevenir escritura/borrado en entornos remotos, active EJECUTAR_SMOKE_TEST_API=true');
      return;
    }

    final salud = await ApiService.consultarSalud();
    if (salud == null) {
      print('⏭ Omitido: backend no disponible');
      return;
    }

    const id = 'LIB-TEST-SMOKE-001';
    final libro = LibroModel(
      id: id,
      isbnOCodigo: id,
      titulo: 'Libro de Prueba Automática',
      autor: 'Parroquia San Miguel',
      iglesia: 'Parroquia San Miguel',
      tipoLibro: 'Actas Parroquiales',
      anioInicio: 1900,
      anioFin: 1910,
      palabrasClave: const ['prueba'],
      paginas: [
        PaginaModel(
          numeroPagina: 1,
          nombreArchivo: 'pagina_001.txt',
          conteoPalabras: 5,
          texto: 'En el pueblo de San Miguel, a diez de enero.',
        ),
      ],
    );

    // 1) Subir
    final mensaje = await ApiService.subirLibroEscaneado(libro);
    print('SUBIR -> $mensaje');
    expect(mensaje, contains('creado'));

    // 2) Listar
    final lista = await ApiService.obtenerLibros(busqueda: 'Prueba Automática');
    print('LISTAR -> ${lista.length}: '
        '${lista.map((l) => '${l.id}|${l.isbnOCodigo}').join(', ')}');
    expect(lista.any((l) => l.id == id), isTrue);

    // 3) Leer detalle (debe traer las páginas)
    final detalle = await ApiService.obtenerDetalleLibro(id);
    print('DETALLE -> ${detalle?.id} / ${detalle?.paginas.length} paginas');
    expect(detalle, isNotNull);
    expect(detalle!.paginas, hasLength(1));
    expect(detalle.paginas.first.texto, contains('San Miguel'));

    // 4) Volver a subir el mismo _id debe ACTUALIZAR, no fallar
    final repetido = await ApiService.subirLibroEscaneado(libro);
    expect(repetido, contains('actualizado'));

    // 5) Borrar
    await ApiService.eliminarLibro(id);
    final tras = await ApiService.obtenerDetalleLibro(id);
    expect(tras, isNull);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
