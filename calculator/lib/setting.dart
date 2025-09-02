import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

class SettingsManager {
  static final SettingsManager _instance = SettingsManager._internal();
  factory SettingsManager() => _instance;
  SettingsManager._internal();

  // Keys
  static const _useRadiansKey = 'useRadians';
  static const _darkModeKey = 'darkMode';
  static const _decimalPlacesKey = 'decimalPlaces';

  // Default values
  bool useRadians = true;
  bool darkMode = false;
  int decimalPlaces = 6;

  /// Load saved settings from SharedPreferences
  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    useRadians = prefs.getBool(_useRadiansKey) ?? true;
    darkMode = prefs.getBool(_darkModeKey) ?? false;
    decimalPlaces = prefs.getInt(_decimalPlacesKey) ?? 6;
  }

  /// Save a single setting
  Future<void> saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is int) {
      await prefs.setInt(key, value);
    }
  }

  /// Reset all settings to default
  Future<void> resetSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_useRadiansKey);
    await prefs.remove(_darkModeKey);
    await prefs.remove(_decimalPlacesKey);

    useRadians = true;
    darkMode = false;
    decimalPlaces = 6;
  }
}




class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsManager _settingsManager = SettingsManager();

  bool _useRadians = true;
  bool _darkMode = false;
  int _decimalPlaces = 6;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await _settingsManager.loadSettings();
    setState(() {
      _useRadians = _settingsManager.useRadians;
      _darkMode = _settingsManager.darkMode;
      _decimalPlaces = _settingsManager.decimalPlaces;
      _isLoading = false;
    });
  }

  void _updateSetting(String key, dynamic value) {
    setState(() {
      if (key == SettingsManager._useRadiansKey) {
        _useRadians = value;
        _settingsManager.useRadians = value;
      } else if (key == SettingsManager._darkModeKey) {
        _darkMode = value;
        _settingsManager.darkMode = value;
      } else if (key == SettingsManager._decimalPlacesKey) {
        _decimalPlaces = value;
        _settingsManager.decimalPlaces = value;
      }
    });
    _settingsManager.saveSetting(key, value);
  }

  Future<void> _resetSettings() async {
    await _settingsManager.resetSettings();
    setState(() {
      _useRadians = true;
      _darkMode = false;
      _decimalPlaces = 6;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings reset to defaults')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Use Radians'),
            value: _useRadians,
            onChanged: (value) =>
                _updateSetting(SettingsManager._useRadiansKey, value),
          ),
          SwitchListTile(
            title: const Text('Dark Mode'),
            value: _darkMode,
            onChanged: (value) =>
                _updateSetting(SettingsManager._darkModeKey, value),
          ),
          ListTile(
            title: const Text('Decimal Places'),
            subtitle: Slider(
              value: _decimalPlaces.toDouble(),
              min: 2,
              max: 10,
              divisions: 8,
              label: _decimalPlaces.toString(),
              onChanged: (value) =>
                  _updateSetting(SettingsManager._decimalPlacesKey, value.round()),
            ),
            trailing: Text(_decimalPlaces.toString()),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('Reset to Defaults'),
            onTap: _resetSettings,
          ),
        ],
      ),
    );
  }
}

