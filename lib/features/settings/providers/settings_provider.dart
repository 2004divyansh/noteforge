import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

// Theme mode provider
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>(
  (ref) => ThemeModeNotifier(),
);

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system) {
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    try {
      final settings = await _readSettings();
      final mode = settings['themeMode'] as String? ?? 'system';
      state = _parseThemeMode(mode);
    } catch (_) {
      // Use default
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    await _saveSettings({'themeMode': mode.name});
  }

  ThemeMode _parseThemeMode(String mode) {
    switch (mode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<Map<String, dynamic>> _readSettings() async {
    try {
      final file = await _settingsFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        return json.decode(content) as Map<String, dynamic>;
      }
    } catch (_) {}
    return {};
  }

  Future<void> _saveSettings(Map<String, dynamic> updates) async {
    try {
      final file = await _settingsFile();
      final settings = await _readSettings();
      settings.addAll(updates);
      
      if (!await file.parent.exists()) {
        await file.parent.create(recursive: true);
      }
      await file.writeAsString(json.encode(settings));
    } catch (_) {}
  }

  Future<File> _settingsFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, 'NoteForge', 'settings.json'));
  }
}

// App lock provider
final appLockEnabledProvider = StateNotifierProvider<AppLockNotifier, bool>(
  (ref) => AppLockNotifier(),
);

class AppLockNotifier extends StateNotifier<bool> {
  AppLockNotifier() : super(false) {
    _loadLockSetting();
  }

  Future<void> _loadLockSetting() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, 'NoteForge', 'settings.json'));
      if (await file.exists()) {
        final content = await file.readAsString();
        final settings = json.decode(content) as Map<String, dynamic>;
        state = settings['appLockEnabled'] as bool? ?? false;
      }
    } catch (_) {}
  }

  Future<void> toggleLock(bool enabled) async {
    state = enabled;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, 'NoteForge', 'settings.json'));
      Map<String, dynamic> settings = {};
      if (await file.exists()) {
        settings = json.decode(await file.readAsString()) as Map<String, dynamic>;
      }
      settings['appLockEnabled'] = enabled;
      if (!await file.parent.exists()) {
        await file.parent.create(recursive: true);
      }
      await file.writeAsString(json.encode(settings));
    } catch (_) {}
  }
}

// View mode provider (list or grid)
final viewModeProvider = StateProvider<ViewMode>((ref) => ViewMode.grid);

enum ViewMode { list, grid }

// Selected folder provider
final selectedFolderProvider = StateProvider<String?>((ref) => null);
