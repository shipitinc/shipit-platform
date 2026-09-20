import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Owns the operator's theme preference.
///
/// Default is [ThemeMode.system] — the design ships both a light and a dark
/// board, so the platform decides unless the operator explicitly overrides it.
/// The override is durable (the design's rail states "Decisions are recorded";
/// a preference that silently resets on reload would contradict that promise).
class ThemeController extends ChangeNotifier {
  ThemeController({SharedPreferences? preferences})
    // Dart forbids `this._preferences` as a named parameter, so the lint's
    // suggested form is not expressible for this private field.
    // ignore: prefer_initializing_formals
    : _preferences = preferences;

  static const String preferenceKey = 'control_plane.theme_mode';

  SharedPreferences? _preferences;
  ThemeMode _mode = ThemeMode.system;

  /// Currently active mode. [ThemeMode.system] defers to the platform.
  ThemeMode get mode => _mode;

  /// True when no explicit override is in force.
  bool get followsPlatform => _mode == ThemeMode.system;

  /// Loads any persisted override. Safe to call when storage is unavailable
  /// (e.g. a widget test) — the controller simply stays on
  /// [ThemeMode.system].
  Future<void> load() async {
    try {
      _preferences ??= await SharedPreferences.getInstance();
      final stored = _preferences?.getString(preferenceKey);
      final resolved = _decode(stored);
      if (resolved != _mode) {
        _mode = resolved;
        notifyListeners();
      }
    } on Object {
      // Storage is a convenience, never a correctness requirement.
      _mode = ThemeMode.system;
    }
  }

  /// Applies and persists an override. Passing [ThemeMode.system] clears it.
  Future<void> setMode(ThemeMode mode) async {
    if (mode == _mode) return;
    _mode = mode;
    notifyListeners();
    try {
      _preferences ??= await SharedPreferences.getInstance();
      if (mode == ThemeMode.system) {
        await _preferences?.remove(preferenceKey);
      } else {
        await _preferences?.setString(preferenceKey, _encode(mode));
      }
    } on Object {
      // Preference could not be stored; the in-memory override still holds.
    }
  }

  /// Cycles system → light → dark → system, which is what the rail control
  /// exposes.
  Future<void> cycle() => setMode(switch (_mode) {
    ThemeMode.system => ThemeMode.light,
    ThemeMode.light => ThemeMode.dark,
    ThemeMode.dark => ThemeMode.system,
  });

  static String _encode(ThemeMode mode) => switch (mode) {
    ThemeMode.system => 'system',
    ThemeMode.light => 'light',
    ThemeMode.dark => 'dark',
  };

  static ThemeMode _decode(String? stored) => switch (stored) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
}
