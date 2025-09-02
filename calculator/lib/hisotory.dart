import 'package:calculator/home.dart';
import 'package:flutter/material.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late List<HistoryItem> history;
  final HistoryManager _historyManager = HistoryManager();

  @override
  void initState() {
    super.initState();
    history = _historyManager.getHistory();
  }

  void _clearHistory() {
    setState(() {
      _historyManager.clearHistory();
      history = _historyManager.getHistory();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('History cleared')),
    );
  }

  void _deleteItem(int index) {
  setState(() {
    HistoryManager().removeAt(index);
    history = HistoryManager().getHistory();
  });

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('History item deleted')),
  );
}


  String _formatTime(DateTime timestamp) {
    return "${timestamp.hour.toString().padLeft(2, '0')}:"
           "${timestamp.minute.toString().padLeft(2, '0')}:"
           "${timestamp.second.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calculation History'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _clearHistory,
            tooltip: 'Clear History',
          ),
        ],
      ),
      body: history.isEmpty
          ? const Center(child: Text('No history yet'))
          : ListView.separated(
              itemCount: history.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = history[index];
                return ListTile(
                  title: Text(item.expression),
                  subtitle: Text(item.result),
                  trailing: Text(
                    _formatTime(item.timestamp),
                    style: const TextStyle(color: Colors.grey),
                  ),
                  onTap: () => Navigator.pop(context, item.expression),
                  onLongPress: () => _deleteItem(index), // delete single entry
                );
              },
            ),
    );
  }
}
