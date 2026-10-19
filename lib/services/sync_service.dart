import 'package:flutter/foundation.dart';

import '../models/libro_local.dart';
import '../models/libro_model.dart';
import 'api_service.dart';
import 'local_library_store.dart';

/// Resultado de un ciclo de sincronización de la cola local.
class ResultadoSync {
  final int intentados;
  final int exitosos;
  final int fallidos;
  final bool sinConexion;

  const ResultadoSync({
    required this.intentados,
    required this.exitosos,
    required this.fallidos,
    required this.sinConexion,
  });

  bool get huboTrabajo => intentados > 0;
}

/// Sube los libros pendientes al backend usando el upsert idempotente.
class SyncService {
  SyncService({LocalLibraryStore? store}) : _store = store ?? LocalLibraryStore();

  final LocalLibraryStore _store;

  LocalLibraryStore get store => _store;

  /// Recorre la cola y sube cada pendiente. Si el backend no responde,
  /// no vacía la cola: solo reporta `sinConexion`.
  Future<ResultadoSync> sincronizarPendientes() async {
    final pendientes = await _store.listarPendientes();
    if (pendientes.isEmpty) {
      return const ResultadoSync(
        intentados: 0,
        exitosos: 0,
        fallidos: 0,
        sinConexion: false,
      );
    }

    final salud = await ApiService.consultarSalud();
    if (salud == null || salud['servidor'] != 'ok') {
      return ResultadoSync(
        intentados: pendientes.length,
        exitosos: 0,
        fallidos: 0,
        sinConexion: true,
      );
    }

    var exitosos = 0;
    var fallidos = 0;

    for (final entry in pendientes) {
      await _store.marcarEstado(entry.id, EstadoSync.sincronizando);
      try {
        await ApiService.subirLibroEscaneado(entry.libro);
        await _store.marcarEstado(entry.id, EstadoSync.sincronizado);
        exitosos++;
      } catch (e) {
        debugPrint('SyncService: fallo al subir ${entry.id}: $e');
        await _store.marcarEstado(
          entry.id,
          EstadoSync.error,
          error: e.toString(),
        );
        fallidos++;
      }
    }

    return ResultadoSync(
      intentados: pendientes.length,
      exitosos: exitosos,
      fallidos: fallidos,
      sinConexion: false,
    );
  }

  /// Persiste el libro como pendiente e intenta una sync inmediata.
  Future<ResultadoGuardado> guardarYSincronizar(LibroModel libro) async {
    await _store.guardarPendiente(libro);
    final sync = await sincronizarPendientes();

    if (sync.sinConexion) {
      return const ResultadoGuardado(
        guardadoLocal: true,
        sincronizado: false,
        mensaje:
            'Libro guardado en el dispositivo. Se subirá cuando haya conexión '
            'con el servidor.',
      );
    }

    // Tras sync, este libro puede haberse eliminado si subió bien.
    final sigueLocal = await _store.obtener(libro.id);

    if (sigueLocal == null) {
      return const ResultadoGuardado(
        guardadoLocal: true,
        sincronizado: true,
        mensaje: 'Libro guardado y sincronizado con el servidor.',
      );
    }

    if (sigueLocal.estado == EstadoSync.error) {
      return ResultadoGuardado(
        guardadoLocal: true,
        sincronizado: false,
        mensaje: sigueLocal.ultimoError ??
            'Guardado en el dispositivo, pero falló la subida. Quedó en cola.',
      );
    }

    return ResultadoGuardado(
      guardadoLocal: true,
      sincronizado: false,
      mensaje:
          'Libro guardado en el dispositivo. Se subirá cuando haya conexión '
          'con el servidor.',
    );
  }
}
