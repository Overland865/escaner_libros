import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/libro_model.dart';

/// Almacena el progreso de lectura de un libro específico.
class ProgresoLectura {
  final String libroId;
  final int ultimaPagina; // 0-indexed
  final int totalPaginas;
  final DateTime fechaActualizacion;
  final Set<int> marcadores; // páginas marcadas (0-indexed)

  const ProgresoLectura({
    required this.libroId,
    required this.ultimaPagina,
    required this.totalPaginas,
    required this.fechaActualizacion,
    this.marcadores = const <int>{},
  });

  double get porcentaje => totalPaginas > 0
      ? ((ultimaPagina + 1) / totalPaginas).clamp(0.0, 1.0)
      : 0.0;

  int get porcentajeEntero => (porcentaje * 100).round();

  Map<String, dynamic> toJson() => {
        'libroId': libroId,
        'ultimaPagina': ultimaPagina,
        'totalPaginas': totalPaginas,
        'fechaActualizacion': fechaActualizacion.toIso8601String(),
        'marcadores': marcadores.toList(),
      };

  factory ProgresoLectura.fromJson(Map<String, dynamic> json) {
    return ProgresoLectura(
      libroId: json['libroId'] as String? ?? '',
      ultimaPagina: json['ultimaPagina'] as int? ?? 0,
      totalPaginas: json['totalPaginas'] as int? ?? 0,
      fechaActualizacion: DateTime.tryParse(
              json['fechaActualizacion'] as String? ?? '') ??
          DateTime.now(),
      marcadores: (json['marcadores'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toSet() ??
          <int>{},
    );
  }
}

/// Almacén local ligero para preferencias de usuario, puntos de lectura,
/// marcadores, favoritos y caché offline de libros remotos.
class LocalUserPreferencesStore {
  LocalUserPreferencesStore({Directory? baseDir}) : _baseDirOverride = baseDir;

  final Directory? _baseDirOverride;

  Future<Directory> _raiz() async {
    if (_baseDirOverride != null) {
      final dir = Directory(p.join(_baseDirOverride.path, 'preferencias_usuario'));
      if (!await dir.exists()) await dir.create(recursive: true);
      return dir;
    }
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'preferencias_usuario'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<Directory> _directorioCache() async {
    final raiz = await _raiz();
    final cacheDir = Directory(p.join(raiz.path, 'cache_libros'));
    if (!await cacheDir.exists()) await cacheDir.create(recursive: true);
    return cacheDir;
  }

  Future<File> _archivoProgreso() async {
    final raiz = await _raiz();
    return File(p.join(raiz.path, 'progreso_lectura.json'));
  }

  Future<File> _archivoFavoritos() async {
    final raiz = await _raiz();
    return File(p.join(raiz.path, 'favoritos.json'));
  }

  // --- PROGRESO DE LECTURA ---

  Future<Map<String, dynamic>> _leerJson(File file) async {
    try {
      if (!await file.exists()) return {};
      final raw = jsonDecode(await file.readAsString());
      if (raw is Map<String, dynamic>) return raw;
      return {};
    } catch (e) {
      debugPrint('LocalUserPreferencesStore: error leyendo ${file.path}: $e');
      return {};
    }
  }

  Future<ProgresoLectura?> obtenerProgreso(String libroId) async {
    final key = libroId.trim();
    if (key.isEmpty) return null;
    final f = await _archivoProgreso();
    final mapa = await _leerJson(f);
    final datos = mapa[key] ?? mapa[libroId];
    if (datos is Map<String, dynamic>) {
      return ProgresoLectura.fromJson(datos);
    }
    return null;
  }

  Future<void> _escribirJsonSeguro(File f, Map<String, dynamic> data) async {
    for (var i = 0; i < 3; i++) {
      try {
        await f.writeAsString(jsonEncode(data), flush: true);
        return;
      } catch (e) {
        if (i == 2) debugPrint('Error escribiendo JSON en ${f.path}: $e');
        await Future<void>.delayed(const Duration(milliseconds: 60));
      }
    }
  }

  Future<void> guardarProgreso({
    required String libroId,
    required int pagina,
    required int totalPaginas,
    Set<int>? marcadores,
  }) async {
    final key = libroId.trim();
    if (key.isEmpty) return;

    final f = await _archivoProgreso();
    final mapa = await _leerJson(f);
    final existente = mapa[key] is Map<String, dynamic>
        ? ProgresoLectura.fromJson(mapa[key] as Map<String, dynamic>)
        : null;

    final nuevo = ProgresoLectura(
      libroId: key,
      ultimaPagina: pagina,
      totalPaginas: totalPaginas,
      fechaActualizacion: DateTime.now(),
      marcadores: marcadores ?? existente?.marcadores ?? <int>{},
    );

    mapa[key] = nuevo.toJson();
    await _escribirJsonSeguro(f, mapa);
  }

  Future<bool> alternarMarcador(
    String libroId,
    int pagina, {
    int? totalPaginas,
  }) async {
    final key = libroId.trim();
    if (key.isEmpty) return false;

    final f = await _archivoProgreso();
    final mapa = await _leerJson(f);
    final existente = mapa[key] is Map<String, dynamic>
        ? ProgresoLectura.fromJson(mapa[key] as Map<String, dynamic>)
        : null;

    final marcadores = Set<int>.from(existente?.marcadores ?? <int>{});
    final agregado = !marcadores.contains(pagina);
    if (agregado) {
      marcadores.add(pagina);
    } else {
      marcadores.remove(pagina);
    }

    final actualizado = ProgresoLectura(
      libroId: key,
      ultimaPagina: pagina,
      totalPaginas: (totalPaginas != null && totalPaginas > 0)
          ? totalPaginas
          : (existente?.totalPaginas ?? 0),
      fechaActualizacion: DateTime.now(),
      marcadores: marcadores,
    );

    mapa[key] = actualizado.toJson();
    await _escribirJsonSeguro(f, mapa);
    return agregado;
  }

  Future<Set<int>> obtenerMarcadores(String libroId) async {
    final progreso = await obtenerProgreso(libroId);
    return progreso?.marcadores ?? <int>{};
  }

  /// Retorna los IDs de todos los libros que tienen progreso guardado o marcadores de página.
  Future<Set<String>> obtenerLibrosConMarcadores() async {
    try {
      final f = await _archivoProgreso();
      final mapa = await _leerJson(f);
      final resultado = <String>{};
      for (final entry in mapa.entries) {
        final val = entry.value;
        if (val is Map<String, dynamic>) {
          final marcadores = val['marcadores'] as List?;
          final ultimaPagina = (val['ultimaPagina'] as num?)?.toInt() ?? 0;
          if ((marcadores != null && marcadores.isNotEmpty) || ultimaPagina > 0) {
            resultado.add(entry.key);
          }
        }
      }
      return resultado;
    } catch (e) {
      debugPrint('LocalUserPreferencesStore: error leyendo libros con marcadores: $e');
      return <String>{};
    }
  }

  // --- FAVORITOS ---

  Future<Set<String>> obtenerFavoritos() async {
    try {
      final f = await _archivoFavoritos();
      if (!await f.exists()) return <String>{};
      final raw = jsonDecode(await f.readAsString());
      if (raw is List) {
        return raw.map((e) => e.toString()).toSet();
      }
      return <String>{};
    } catch (e) {
      debugPrint('LocalUserPreferencesStore: error leyendo favoritos: $e');
      return <String>{};
    }
  }

  Future<bool> esFavorito(String libroId) async {
    final favs = await obtenerFavoritos();
    return favs.contains(libroId);
  }

  Future<bool> alternarFavorito(String libroId) async {
    final f = await _archivoFavoritos();
    final favs = await obtenerFavoritos();
    final ahoraEsFavorito = !favs.contains(libroId);
    if (ahoraEsFavorito) {
      favs.add(libroId);
    } else {
      favs.remove(libroId);
    }
    await f.writeAsString(jsonEncode(favs.toList()));
    return ahoraEsFavorito;
  }

  // --- CACHÉ OFFLINE DE LIBROS REMOTOS ---

  String _sanitizarId(String id) {
    return id.replaceAll(RegExp(r'[^\w\-.]'), '_');
  }

  Future<void> guardarEnCache(LibroModel libro) async {
    try {
      final dir = await _directorioCache();
      final archivo = File(p.join(dir.path, '${_sanitizarId(libro.id)}.json'));
      await archivo.writeAsString(jsonEncode(libro.toJson()));
    } catch (e) {
      debugPrint('LocalUserPreferencesStore: no se pudo guardar en caché el libro ${libro.id}: $e');
    }
  }

  Future<LibroModel?> obtenerDeCache(String libroId) async {
    try {
      final dir = await _directorioCache();
      final archivo = File(p.join(dir.path, '${_sanitizarId(libroId)}.json'));
      if (!await archivo.exists()) return null;
      final raw = jsonDecode(await archivo.readAsString());
      if (raw is Map<String, dynamic>) {
        return LibroModel.fromJson(raw);
      }
      return null;
    } catch (e) {
      debugPrint('LocalUserPreferencesStore: error leyendo caché del libro $libroId: $e');
      return null;
    }
  }
}
