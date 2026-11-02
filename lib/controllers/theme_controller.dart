import 'package:flutter/material.dart';

import '../services/local_user_preferences_store.dart';

/// Controlador reactivo del modo de tema (Claro clásico / Oscuro cálido).
class ThemeController extends ChangeNotifier {
  static final ThemeController instance = ThemeController._();

  ThemeController._();

  final LocalUserPreferencesStore _prefs = LocalUserPreferencesStore();
  ThemeMode _modo = ThemeMode.light;

  ThemeMode get modo => _modo;
  bool get esOscuro => _modo == ThemeMode.dark;

  Future<void> inicializar() async {
    final guardado = await _prefs.obtenerTema();
    if (guardado == 'dark') {
      _modo = ThemeMode.dark;
    } else if (guardado == 'light') {
      _modo = ThemeMode.light;
    } else {
      // Por defecto iniciamos en el nuevo modo editorial claro y amigable
      _modo = ThemeMode.light;
    }
    notifyListeners();
  }

  Future<void> alternarTema() async {
    if (_modo == ThemeMode.dark) {
      _modo = ThemeMode.light;
      await _prefs.guardarTema('light');
    } else {
      _modo = ThemeMode.dark;
      await _prefs.guardarTema('dark');
    }
    notifyListeners();
  }

  Future<void> establecerModo(ThemeMode nuevoModo) async {
    if (_modo == nuevoModo) return;
    _modo = nuevoModo;
    await _prefs.guardarTema(nuevoModo == ThemeMode.dark ? 'dark' : 'light');
    notifyListeners();
  }
}

