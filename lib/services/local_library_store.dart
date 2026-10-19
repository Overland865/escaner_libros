import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/libro_local.dart';
import '../models/libro_model.dart';

/// Persistencia local de libros pendientes de sincronizar.
///
/// Un archivo JSON por libro en `{documents}/biblioteca_local/{id}.json`
/// y un índice `cola.json` con los ids pendientes.
class LocalLibraryStore {
  LocalLibraryStore({Directory? baseDir}) : _baseDirOverride = baseDir;

  final Directory? _baseDirOverride;

  Future<Directory> _raiz() async {
    final override = _baseDirOverride;
    if (override != null) {
      final dir = Directory(p.join(override.path, 'biblioteca_local'));
      if (!await dir.exists()) await dir.create(recursive: true);
      return dir;
    }
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'biblioteca_local'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> _archivoLibro(String id) async {
    final raiz = await _raiz();
    final seguro = _sanitizarId(id);
    return File(p.join(raiz.path, '$seguro.json'));
  }

  Future<File> _archivoCola() async {
    final raiz = await _raiz();
    return File(p.join(raiz.path, 'cola.json'));
  }

  static String _sanitizarId(String id) {
    return id.replaceAll(RegExp(r'[^\w\-.]'), '_');
  }

  Future<List<String>> _leerIdsCola() async {
    try {
      final f = await _archivoCola();
      if (!await f.exists()) return <String>[];
      final raw = jsonDecode(await f.readAsString());
      if (raw is! List) return <String>[];
      return raw.map((e) => e.toString()).toList();
    } catch (e) {
      debugPrint('LocalLibraryStore: error leyendo cola: $e');
      return <String>[];
    }
  }

  Future<void> _escribirIdsCola(List<String> ids) async {
    final f = await _archivoCola();
    await f.writeAsString(jsonEncode(ids));
  }

  /// Guarda (o sobrescribe) un libro como pendiente de sync.
  Future<LibroLocal> guardarPendiente(LibroModel libro) async {
    final entry = LibroLocal(
      libro: libro,
      estado: EstadoSync.pendiente,
      actualizadoEn: DateTime.now(),
    );
    await _escribirEntry(entry);

    final ids = await _leerIdsCola();
    if (!ids.contains(libro.id)) {
      ids.add(libro.id);
      await _escribirIdsCola(ids);
    }
    return entry;
  }

  Future<void> _escribirEntry(LibroLocal entry) async {
    final f = await _archivoLibro(entry.id);
    await f.writeAsString(
      const JsonEncoder.withIndent('  ').convert(entry.toJson()),
    );
  }

  Future<LibroLocal?> obtener(String id) async {
    try {
      final f = await _archivoLibro(id);
      if (!await f.exists()) return null;
      final map = jsonDecode(await f.readAsString());
      if (map is! Map) return null;
      return LibroLocal.fromJson(Map<String, dynamic>.from(map));
    } catch (e) {
      debugPrint('LocalLibraryStore: error leyendo $id: $e');
      return null;
    }
  }

  /// Libros que aún necesitan subirse (`pendiente` o `error`).
  Future<List<LibroLocal>> listarPendientes() async {
    final ids = await _leerIdsCola();
    final out = <LibroLocal>[];
    for (final id in ids) {
      final entry = await obtener(id);
      if (entry == null) continue;
      if (entry.necesitaSync || entry.estado == EstadoSync.sincronizando) {
        out.add(entry);
      }
    }
    return out;
  }

  /// Todos los borradores locales (incluye sincronizados aún no borrados).
  Future<List<LibroLocal>> listarTodos() async {
    final ids = await _leerIdsCola();
    final out = <LibroLocal>[];
    for (final id in ids) {
      final entry = await obtener(id);
      if (entry != null) out.add(entry);
    }
    return out;
  }

  Future<void> marcarEstado(
    String id,
    EstadoSync estado, {
    String? error,
  }) async {
    final actual = await obtener(id);
    if (actual == null) return;

    final next = actual.copyWith(
      estado: estado,
      ultimoError: error,
      clearError: error == null && estado != EstadoSync.error,
      actualizadoEn: DateTime.now(),
    );
    await _escribirEntry(next);

    if (estado == EstadoSync.sincronizado) {
      await eliminar(id);
    }
  }

  Future<void> eliminar(String id) async {
    try {
      final f = await _archivoLibro(id);
      if (await f.exists()) await f.delete();
    } catch (e) {
      debugPrint('LocalLibraryStore: error borrando archivo $id: $e');
    }

    final ids = await _leerIdsCola();
    ids.removeWhere((e) => e == id);
    await _escribirIdsCola(ids);
  }

  Future<int> contarPendientes() async {
    final list = await listarPendientes();
    return list.length;
  }
}
