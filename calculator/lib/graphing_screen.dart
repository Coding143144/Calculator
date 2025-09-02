import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:math_expressions/math_expressions.dart';

class GraphingScreen extends StatefulWidget {
  const GraphingScreen({super.key});

  @override
  State<GraphingScreen> createState() => _GraphingScreenState();
}

class _GraphingScreenState extends State<GraphingScreen> {
  final TextEditingController _functionController = TextEditingController(text: 'x^2');
  final TextEditingController _minXController = TextEditingController(text: '-10');
  final TextEditingController _maxXController = TextEditingController(text: '10');
  final TextEditingController _minYController = TextEditingController(text: '-10');
  final TextEditingController _maxYController = TextEditingController(text: '10');

  List<FlSpot> _points = [];
  bool _isValidFunction = true;
  String _errorMessage = '';
  bool _isLoading = false;

  void _plotFunction() {
    setState(() {
      _isLoading = true;
      _isValidFunction = true;
      _errorMessage = '';
    });

    try {
      final function = _functionController.text.trim();
      final minX = double.tryParse(_minXController.text) ?? -10;
      final maxX = double.tryParse(_maxXController.text) ?? 10;

      if (minX >= maxX) {
        throw Exception('Min X must be less than Max X');
      }

      _points = _generatePoints(function, minX, maxX);
    } catch (e) {
      _isValidFunction = false;
      _errorMessage = e.toString();
      _points = [];
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<FlSpot> _generatePoints(String function, double minX, double maxX) {
    final points = <FlSpot>[];
    final step = (maxX - minX) / 300; // smoother curve

    final parser = Parser();
    final cm = ContextModel();

    try {
      final expression = parser.parse(function);

      for (double x = minX; x <= maxX; x += step) {
        cm.bindVariable(Variable('x'), Number(x));
        final y = expression.evaluate(EvaluationType.REAL, cm);

        if (y.isFinite) {
          points.add(FlSpot(x, y));
        }
      }
    } catch (e) {
      throw Exception('Invalid function: ${e.toString()}');
    }

    return points;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _plotFunction());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Graphing Calculator'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Supported Functions'),
                  content: const Text(
                    'You can use:\n'
                    '- sin(x), cos(x), tan(x)\n'
                    '- log(x) (natural log)\n'
                    '- sqrt(x), abs(x)\n'
                    '- Constants: e, pi\n'
                    'Example: sin(x) + log(x)',
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _functionController,
              decoration: InputDecoration(
                labelText: 'f(x)',
                errorText: _isValidFunction ? null : _errorMessage,
              ),
              onSubmitted: (_) => _plotFunction(), // auto-plot on enter
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _minXController,
                    decoration: const InputDecoration(labelText: 'Min X'),
                    keyboardType: TextInputType.number,
                    onSubmitted: (_) => _plotFunction(),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _maxXController,
                    decoration: const InputDecoration(labelText: 'Max X'),
                    keyboardType: TextInputType.number,
                    onSubmitted: (_) => _plotFunction(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _minYController,
                    decoration: const InputDecoration(labelText: 'Min Y'),
                    keyboardType: TextInputType.number,
                    onSubmitted: (_) => _plotFunction(),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _maxYController,
                    decoration: const InputDecoration(labelText: 'Max Y'),
                    keyboardType: TextInputType.number,
                    onSubmitted: (_) => _plotFunction(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _plotFunction,
              child: const Text('Plot Function'),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _points.isEmpty
                      ? Center(
                          child: Text(
                            _errorMessage.isEmpty
                                ? 'No data to display'
                                : _errorMessage,
                          ),
                        )
                      : LineChart(
                          LineChartData(
                            gridData: FlGridData(show: true),
                            titlesData: FlTitlesData(
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: true),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: true),
                              ),
                            ),
                            borderData: FlBorderData(show: true),
                            minX: double.tryParse(_minXController.text) ?? -10,
                            maxX: double.tryParse(_maxXController.text) ?? 10,
                            minY: double.tryParse(_minYController.text) ?? -10,
                            maxY: double.tryParse(_maxYController.text) ?? 10,
                            lineBarsData: [
                              LineChartBarData(
                                spots: _points,
                                isCurved: true,
                                color: Colors.blue,
                                dotData: FlDotData(show: false),
                                belowBarData: BarAreaData(show: false),
                              ),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
