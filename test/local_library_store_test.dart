import 'dart:io';

import 'package:escaner_libros/models/libro_local.dart';
import 'package:escaner_libros/models/libro_model.dart';
import 'package:escaner_libros/models/pagina_model.dart';
import 'package:escaner_libros/services/local_library_store.dart';
import 'package:flutter_test/flutter_test.dart';

LibroModel _libro({String id = 'LIB-001'}) {
  return LibroModel(
    id: id,
    isbnOCodigo: id,
    titulo: 'Bautismos',
    autor: 'Parroquia',
    tipoLibro: 'Bautismos',
    anioInicio: 1800,
    anioFin: 1850,
    palabrasClave: const ['test'],
    paginas: [
      PaginaModel(
        numeroPagina: 1,
        nombreArchivo: 'pagina_001.txt',
        conteoPalabras: 3,
        texto: 'hola mundo test',
        motor: 'mlkit',
      ),
    ],
  );
}

void main() {
  late Directory temp;
  late LocalLibraryStore store;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('lib_local_');
    store = LocalLibraryStore(baseDir: temp);
  });

  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  test('guardarPendiente y listarPendientes', () async {
    await store.guardarPendiente(_libro());
    final list = await store.listarPendientes();
    expect(list.length, 1);
    expect(list.first.id, 'LIB-001');
    expect(list.first.estado, EstadoSync.pendiente);
  });

  test('marcarEstado error conserva mensaje; sincronizado elimina', () async {
    await store.guardarPendiente(_libro());
    await store.marcarEstado('LIB-001', EstadoSync.error, error: 'sin red');
    var entry = await store.obtener('LIB-001');
    expect(entry?.estado, EstadoSync.error);
    expect(entry?.ultimoError, 'sin red');

    await store.marcarEstado('LIB-001', EstadoSync.sincronizado);
    entry = await store.obtener('LIB-001');
    expect(entry, isNull);
    expect(await store.listarPendientes(), isEmpty);
  });

  test('sobrescribe el mismo id sin duplicar en cola', () async {
    await store.guardarPendiente(_libro());
    final otro = LibroModel(
      id: 'LIB-001',
      isbnOCodigo: 'LIB-001',
      titulo: 'Bautismos actualizado',
      autor: 'Parroquia',
      tipoLibro: 'Bautismos',
      anioInicio: 1800,
      anioFin: 1850,
      palabrasClave: const [],
      paginas: const [],
    );
    await store.guardarPendiente(otro);
    final list = await store.listarPendientes();
    expect(list.length, 1);
    expect(list.first.libro.titulo, 'Bautismos actualizado');
  });
}
