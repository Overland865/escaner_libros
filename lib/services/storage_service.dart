import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Servicio para manejar el almacenamiento temporal de imágenes escaneadas.
class StorageService {
  /// Ruta base de almacenamiento temporal.
  static Future<String> get _storagePath async {
    final directory = await getApplicationDocumentsDirectory();
    final storageDir = Directory(p.join(directory.path, 'scan_temp'));
    
    if (!await storageDir.exists()) {
      await storageDir.create(recursive: true);
    }
    
    return storageDir.path;
  }

  /// Guarda una imagen en el almacenamiento temporal.
  Future<String> saveImage(Uint8List imageData, String filename) async {
    final storagePath = await _storagePath;
    final file = File(p.join(storagePath, filename));
    await file.writeAsBytes(imageData);
    return file.path;
  }

  /// Lee una imagen desde el almacenamiento temporal.
  Future<Uint8List?> loadImage(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        return await file.readAsBytes();
      }
      return null;
    } catch (e) {
      debugPrint('Error al cargar imagen: $e');
      return null;
    }
  }

  /// Elimina una imagen del almacenamiento temporal.
  Future<void> deleteImage(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Error al eliminar imagen: $e');
    }
  }

  /// Limpia todas las imágenes temporales.
  Future<void> cleanup() async {
    try {
      final storagePath = await _storagePath;
      final directory = Directory(storagePath);
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    } catch (e) {
      debugPrint('Error al limpiar almacenamiento temporal: $e');
    }
  }

  /// Verifica si existe un archivo de imagen con el nombre especificado.
  Future<bool> fileExists(String filePath) async {
    try {
      final file = File(filePath);
      return await file.exists();
    } catch (_) {
      return false;
    }
  }
}