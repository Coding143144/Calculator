import 'package:flutter/material.dart';
import 'package:calculator/statistics_manager.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  final TextEditingController _dataController = TextEditingController();
  Map<String, dynamic> _stats = {};
  String _errorMessage = '';

  void _calculateStats() {
    try {
      final raw = _dataController.text.trim();

      final data = raw
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .map((s) => double.tryParse(s))
          .toList();

      if (data.any((d) => d == null)) {
        throw Exception('Please enter valid numbers only (comma-separated).');
      }

      final numericData = data.map((d) => d!).toList();

      if (numericData.isEmpty) {
        throw Exception('Please enter some data.');
      }

      setState(() {
        _stats = StatisticsManager.calculateStats(numericData);
        _errorMessage = '';
      });
    } catch (e) {
      setState(() {
        _stats = {};
        _errorMessage = e.toString();
      });
    }
  }

  Widget _buildStatRow(String key, dynamic value) {
    String displayValue;

    if (value is double) {
      displayValue = value.toStringAsFixed(4);
    } else if (value is List) {
      displayValue = value.join(', ');
    } else {
      displayValue = value.toString();
    }

    return ListTile(
      title: Text(key),
      trailing: Text(displayValue),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Statistics Calculator')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _dataController,
              decoration: const InputDecoration(
                labelText: 'Enter numbers (comma separated)',
                hintText: 'Example: 1, 2, 3, 4, 5',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              minLines: 1,
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            if (_errorMessage.isNotEmpty)
              Text(
                _errorMessage,
                style: const TextStyle(color: Colors.red),
              ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _calculateStats,
              child: const Text('Calculate Statistics'),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _stats.isEmpty
                  ? const Center(child: Text('Enter data to calculate statistics'))
                  : ListView(
                      children: _stats.entries
                          .map((entry) => _buildStatRow(entry.key, entry.value))
                          .toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
