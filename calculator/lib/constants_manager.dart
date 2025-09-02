import 'dart:collection';
import 'package:shared_preferences/shared_preferences.dart';

/// Singleton manager for user-defined mathematical constants.
/// Persists constants using [SharedPreferences].
class ConstantsManager {
  // --- Singleton boilerplate ---
  static final ConstantsManager _instance = ConstantsManager._internal();
  static ConstantsManager get instance => _instance;
  ConstantsManager._internal();

  // --- Private fields ---
  static const String _prefix = 'constant_';
  final Map<String, double> _constants = {};

  bool _initialized = false;

  /// Initialize and load constants from [SharedPreferences].
  Future<void> init() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((key) => key.startsWith(_prefix));

      for (final key in keys) {
        final name = key.replaceFirst(_prefix, '');
        final value = prefs.getDouble(key);
        if (value != null) {
          _constants[name] = value;
        }
      }
      _initialized = true;
    } catch (e) {
      // Fail gracefully
      print('Failed to load constants: $e');
    }
  }

  /// Add or update a constant and persist it.
  Future<void> addConstant(String name, double value) async {
    _constants[name] = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('$_prefix$name', value);
    } catch (e) {
      print('Failed to save constant $name: $e');
    }
  }

  /// Remove a constant by [name].
  Future<void> removeConstant(String name) async {
    _constants.remove(name);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_prefix$name');
    } catch (e) {
      print('Failed to remove constant $name: $e');
    }
  }

  /// Replace constant names in [expression] with their values.
  String replaceConstants(String expression) {
    String result = expression;

    // Sort by key length (desc) to avoid partial replacements
    final sortedKeys = _constants.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));

    for (final name in sortedKeys) {
      final pattern = RegExp('\\b$name\\b', caseSensitive: false);
      result = result.replaceAll(pattern, _constants[name].toString());
    }

    return result;
  }

  /// Read-only map of all constants.
  UnmodifiableMapView<String, double> get constants =>
      UnmodifiableMapView(_constants);
}
