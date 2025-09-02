// unit_converter.dart
import 'package:flutter/material.dart';

class UnitConverterScreen extends StatefulWidget {
  const UnitConverterScreen({super.key});

  @override
  State<UnitConverterScreen> createState() => _UnitConverterScreenState();
}

class _UnitConverterScreenState extends State<UnitConverterScreen> {
  final Map<String, Map<String, double>> _conversionFactors = {
    'Length': {
      'Meters': 1.0,
      'Kilometers': 0.001,
      'Centimeters': 100.0,
      'Millimeters': 1000.0,
      'Inches': 39.3701,
      'Feet': 3.28084,
      'Yards': 1.09361,
      'Miles': 0.000621371,
    },
    'Weight': {
      'Kilograms': 1.0,
      'Grams': 1000.0,
      'Milligrams': 1000000.0,
      'Pounds': 2.20462,
      'Ounces': 35.274,
      'Tons': 0.00110231,
    },
    'Temperature': {
      'Celsius': 1.0,
      'Fahrenheit': 1.0, // handled separately
      'Kelvin': 1.0, // handled separately
    },
    'Volume': {
      'Liters': 1.0,
      'Milliliters': 1000.0,
      'Gallons': 0.264172,
      'Quarts': 1.05669,
      'Pints': 2.11338,
      'Cups': 4.22675,
      'Fluid Ounces': 33.814,
    },
    'Area': {
      'Square Meters': 1.0,
      'Square Kilometers': 0.000001,
      'Square Feet': 10.7639,
      'Square Inches': 1550.0,
      'Hectares': 0.0001,
      'Acres': 0.000247105,
    },
  };

  String _selectedCategory = 'Length';
  String _fromUnit = 'Meters';
  String _toUnit = 'Kilometers';
  double _inputValue = 0.0;
  double _outputValue = 0.0;

  final TextEditingController _inputController = TextEditingController();

  void _convert() {
    setState(() {
      if (_selectedCategory == 'Temperature') {
        if (_fromUnit == 'Celsius' && _toUnit == 'Fahrenheit') {
          _outputValue = (_inputValue * 9 / 5) + 32;
        } else if (_fromUnit == 'Fahrenheit' && _toUnit == 'Celsius') {
          _outputValue = (_inputValue - 32) * 5 / 9;
        } else if (_fromUnit == 'Celsius' && _toUnit == 'Kelvin') {
          _outputValue = _inputValue + 273.15;
        } else if (_fromUnit == 'Kelvin' && _toUnit == 'Celsius') {
          _outputValue = _inputValue - 273.15;
        } else if (_fromUnit == 'Fahrenheit' && _toUnit == 'Kelvin') {
          _outputValue = (_inputValue - 32) * 5 / 9 + 273.15;
        } else if (_fromUnit == 'Kelvin' && _toUnit == 'Fahrenheit') {
          _outputValue = (_inputValue - 273.15) * 9 / 5 + 32;
        } else {
          _outputValue = _inputValue;
        }
      } else {
        final fromFactor = _conversionFactors[_selectedCategory]![_fromUnit]!;
        final toFactor = _conversionFactors[_selectedCategory]![_toUnit]!;
        _outputValue = _inputValue * (toFactor / fromFactor);
      }
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Unit Converter')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButton<String>(
              value: _selectedCategory,
              isExpanded: true,
              items: _conversionFactors.keys.map((String category) {
                return DropdownMenuItem<String>(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedCategory = newValue!;
                  _fromUnit = _conversionFactors[_selectedCategory]!.keys.first;
                  _toUnit = _conversionFactors[_selectedCategory]!.keys.elementAt(1);
                  _convert();
                });
              },
            ),
            const SizedBox(height: 16),

            // Input field with "from" unit dropdown
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _inputController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Input'),
                    onChanged: (value) {
                      _inputValue = double.tryParse(value) ?? 0.0;
                      _convert();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: DropdownButton<String>(
                    value: _fromUnit,
                    isExpanded: true,
                    items: _conversionFactors[_selectedCategory]!.keys.map((String unit) {
                      return DropdownMenuItem<String>(
                        value: unit,
                        child: Text(unit),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _fromUnit = newValue!;
                        _convert();
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Output with "to" unit dropdown
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _outputValue.toStringAsFixed(6),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: DropdownButton<String>(
                    value: _toUnit,
                    isExpanded: true,
                    items: _conversionFactors[_selectedCategory]!.keys.map((String unit) {
                      return DropdownMenuItem<String>(
                        value: unit,
                        child: Text(unit),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _toUnit = newValue!;
                        _convert();
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _convert,
              child: const Text('Convert'),
            ),
          ],
        ),
      ),
    );
  }
}
