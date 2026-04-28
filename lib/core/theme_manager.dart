import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeManager extends ValueNotifier<ThemeMode> {
  ThemeManager() : super(ThemeMode.system);

  Future<void> cargarPreferencia() async {
    final prefs = await SharedPreferences.getInstance();
    final esOscuro = prefs.getBool('modo_oscuro');
    if (esOscuro != null) {
      value = esOscuro ? ThemeMode.dark : ThemeMode.light;
    }
  }

  void alternarTema() async {
    final prefs = await SharedPreferences.getInstance();
    if (value == ThemeMode.dark) {
      value = ThemeMode.light;
      await prefs.setBool('modo_oscuro', false);
    } else {
      value = ThemeMode.dark;
      await prefs.setBool('modo_oscuro', true);
    }
  }
}

final themeManager = ThemeManager();
