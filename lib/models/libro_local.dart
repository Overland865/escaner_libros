import 'libro_model.dart';

/// Estado de sincronización de un libro guardado en el dispositivo.
enum EstadoSync {
  /// En disco; aún no confirmado en el servidor.
  pendiente,

  /// Subida en curso.
  sincronizando,

  /// Confirmado en el backend (el borrador local se puede borrar).
  sincronizado,

  /// Falló la última subida; reintentable.
  error,
}

/// Libro persistido localmente junto con su estado de sync.
class LibroLocal {
  final LibroModel libro;
  final EstadoSync estado;
  final String? ultimoError;
  final DateTime actualizadoEn;

  const LibroLocal({
    required this.libro,
    required this.estado,
    this.ultimoError,
    required this.actualizadoEn,
  });

  String get id => libro.id;

  bool get necesitaSync =>
      estado == EstadoSync.pendiente || estado == EstadoSync.error;

  LibroLocal copyWith({
    LibroModel? libro,
    EstadoSync? estado,
    String? ultimoError,
    bool clearError = false,
    DateTime? actualizadoEn,
  }) {
    return LibroLocal(
      libro: libro ?? this.libro,
      estado: estado ?? this.estado,
      ultimoError: clearError ? null : (ultimoError ?? this.ultimoError),
      actualizadoEn: actualizadoEn ?? this.actualizadoEn,
    );
  }

  Map<String, dynamic> toJson() => {
        'estado': estado.name,
        'ultimo_error': ultimoError,
        'actualizado_en': actualizadoEn.toUtc().toIso8601String(),
        'libro': libro.toJson(),
      };

  factory LibroLocal.fromJson(Map<String, dynamic> json) {
    final estadoRaw = json['estado'] as String? ?? EstadoSync.pendiente.name;
    final estado = EstadoSync.values.firstWhere(
      (e) => e.name == estadoRaw,
      orElse: () => EstadoSync.pendiente,
    );

    final libroJson = json['libro'];
    final libro = libroJson is Map
        ? LibroModel.fromJson(Map<String, dynamic>.from(libroJson))
        : LibroModel.fromJson(Map<String, dynamic>.from(json));

    final actualizadoRaw = json['actualizado_en'] as String?;
    return LibroLocal(
      libro: libro,
      estado: estado,
      ultimoError: json['ultimo_error'] as String?,
      actualizadoEn: actualizadoRaw != null
          ? DateTime.tryParse(actualizadoRaw)?.toLocal() ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

/// Resultado de guardar un libro (local y, si hubo red, remoto).
class ResultadoGuardado {
  final bool guardadoLocal;
  final bool sincronizado;
  final String mensaje;

  const ResultadoGuardado({
    required this.guardadoLocal,
    required this.sincronizado,
    required this.mensaje,
  });
}
