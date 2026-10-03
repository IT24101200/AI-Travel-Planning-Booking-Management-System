import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Manages app theme mode (light/dark/system) and persists the choice.
class ThemeNotifier extends ValueNotifier<ThemeMode> {
  static const _key = 'theme_mode';
  final _storage = const FlutterSecureStorage();

  ThemeNotifier() : super(ThemeMode.system);

  /// Load saved preference on app start.
  Future<void> loadSavedTheme() async {
    final saved = await _storage.read(key: _key);
    if (saved == 'light') {
      value = ThemeMode.light;
    } else if (saved == 'dark') {
      value = ThemeMode.dark;
    } else {
      value = ThemeMode.system;
    }
  }

  /// Update theme and save to storage.
  Future<void> setThemeMode(ThemeMode mode) async {
    value = mode;
    await _storage.write(key: _key, value: mode.name);
  }
}
