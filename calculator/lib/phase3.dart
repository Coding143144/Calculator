import 'package:flutter/material.dart';
import 'package:math_expressions/math_expressions.dart';

class LineData {
  final TextEditingController controller;
  String result;
  LineData(this.controller, {this.result = ''});
}

class CalcNotePage extends StatefulWidget {
  const CalcNotePage({Key? key}) : super(key: key);

  @override
  State<CalcNotePage> createState() => _CalcNotePageState();
}

class _CalcNotePageState extends State<CalcNotePage> {
  final List<LineData> _lines = [];

  @override
  void initState() {
    super.initState();
    _addLine(); // start with 1 line
  }

  void _addLine() {
    final c = TextEditingController();
    c.addListener(() => _onLineChanged());
    setState(() => _lines.add(LineData(c)));
  }

  void _onLineChanged() {
    // recompute all lines when any line changes
    final results = <int, double>{};
    for (int i = 0; i < _lines.length; i++) {
      final expr = _lines[i].controller.text.trim();
      try {
        final value = _evaluate(expr, results);
        results[i] = value;
        _lines[i].result = value.toString();
      } catch (e) {
        _lines[i].result = 'ERR';
      }
    }
    setState(() {});
  }

  double _evaluate(String expr, Map<int, double> results) {
    if (expr.isEmpty) return 0;

    // handle $n references
    final refRegex = RegExp(r"\$(\d+)");
    expr = expr.replaceAllMapped(refRegex, (m) {
      final lineNo = int.parse(m[1]!);
      final idx = lineNo - 1;
      if (results.containsKey(idx)) {
        return results[idx].toString();
      } else {
        throw Exception("Invalid ref");
      }
    });

    // parse expression with math_expressions
    final parser = Parser();
    final exp = parser.parse(expr);
    final cm = ContextModel();
    return exp.evaluate(EvaluationType.REAL, cm);
  }

  double get total {
    double sum = 0;
    for (var l in _lines) {
      final v = double.tryParse(l.result);
      if (v != null) sum += v;
    }
    return sum;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CalcNote Phase-3')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _lines.length,
              itemBuilder: (context, i) {
                return Row(
                  children: [
                    Text('${i + 1}'),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _lines[i].controller,
                        decoration: const InputDecoration(
                          hintText: 'Enter expression',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(_lines[i].result),
                  ],
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade200,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("TOTAL", style: TextStyle(fontWeight: FontWeight.bold)),
                Text(total.toString()),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addLine,
        child: const Icon(Icons.add),
      ),
    );
  }
}
