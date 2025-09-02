import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'package:calculator/constants_manager.dart';
import 'package:calculator/constants_screen.dart';
import 'package:calculator/export_manager.dart';
import 'package:calculator/fileManager.dart';
import 'package:calculator/graphing_screen.dart';
import 'package:calculator/statistics_screen.dart';
import 'package:calculator/templates_screen.dart';
import 'package:calculator/tutorial_screen.dart';
import 'package:calculator/unit_convertor.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:math' as math;
import 'package:collection/collection.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:math_expressions/math_expressions.dart' hide Stack;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:calculator/favourite.dart';
import 'package:calculator/hisotory.dart';
import 'package:calculator/setting.dart';

// Token constants for consistency
const String kBackspaceToken = '\b';
const String kClearAllToken = 'CLEAR_ALL';
const String kEnterToken = 'ENTER';

// Intent classes for keyboard shortcuts
class UndoIntent extends Intent {
  const UndoIntent();
}

class RedoIntent extends Intent {
  const RedoIntent();
}

class LineData {
  LineData(this.index)
      : controller = TextEditingController(),
        focusNode = FocusNode() {
    _lastSavedText = controller.text;
  }

  final int index;
  final TextEditingController controller;
  final FocusNode focusNode;
  bool get isFavorite => FavoritesManager().isFavorite(controller.text);
  String result = '';
  String? error;
  List<int> dependsOn = [];

  List<String> steps = [];

  // Undo/redo stacks
  final List<String> _undoStack = [];
  final List<String> _redoStack = [];
  String _lastSavedText = '';

  // Debounce to avoid per-keystroke snapshots
  Timer? _debounce;

  // external listener reference (assigned in initState)
  void Function()? _listener;

  bool get isComment => _isComment(controller.text);

  static bool _isComment(String s) {
    final hasMath = RegExp(r"[0-9$()^+\-*/.]").hasMatch(s);
    return s.trim().isNotEmpty && !hasMath;
  }

  // called by _onLineChanged (debounced snapshot)
  void onTextChanged(String text) {
    if (text == _lastSavedText) return;

    _debounce?.cancel();

    // Store the current state BEFORE it changes
    final previousState = _lastSavedText;

    _debounce = Timer(const Duration(milliseconds: 350), () {
      // Only add to undo stack if it's different from current state
      if (previousState != text) {
        _undoStack.add(previousState);
        _lastSavedText = text;
        _redoStack.clear();
      }
    });
  }

  void saveStateImmediate() {
    // Only save if different from current
    if (controller.text != _lastSavedText) {
      _undoStack.add(_lastSavedText);
      _redoStack.clear();
      _lastSavedText = controller.text;
    }
  }

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  void undo() {
    if (!canUndo) return;

    // Save current state to redo stack
    _redoStack.add(_lastSavedText);

    // Get previous state
    final prev = _undoStack.removeLast();
    _applyText(prev);
  }

  void redo() {
    if (!canRedo) return;

    // Save current state to undo stack
    _undoStack.add(_lastSavedText);

    // Get next state
    final next = _redoStack.removeLast();
    _applyText(next);
  }

  // apply text without firing our listener (prevents corrupting stacks)
  void _applyText(String newText) {
    _lastSavedText = newText;

    // Remove listener to prevent infinite loop
    final hadListener = _listener != null;
    if (hadListener) {
      controller.removeListener(_listener!);
    }

    // Apply the text
    controller.text = newText;
    controller.selection = TextSelection.collapsed(offset: newText.length);

    // Restore listener
    if (hadListener) {
      controller.addListener(_listener!);
    }
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final List<LineData> _lines = List.generate(4, (i) => LineData(i + 1));
  final _scrollController = ScrollController();

  // Keypad state
  bool _showKeypad = true;
  bool isKeyboardEnabled = false;
  int _keypadPage = 0;

  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _lastWords = '';

  // New state variables for features
  bool _darkMode = false;
  bool _firstTimeUser = true;

  void _checkFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    _firstTimeUser = prefs.getBool('firstTime') ?? true;
    if (_firstTimeUser) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showTutorial();
        prefs.setBool('firstTime', false);
      });
    }
  }

  void _showTutorial() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Dialog(
        insetPadding: EdgeInsets.all(16),
        child: TutorialScreen(),
      ),
    );
  }

  // Error explanations map
  final Map<String, String> _errorExplanations = {
    'Bad ref':
        'You referenced a line that does not exist. Use \$1, \$2, etc. to reference previous lines.',
    'Circular ref':
        'You have a circular reference. Check if you are referencing a line that eventually references back to this line.',
    'ERR:':
        'An error occurred during evaluation. Check your expression for syntax errors.',
    'Division by zero':
        'You cannot divide by zero. Please check your denominator.',
    'Invalid function':
        'The function you used is not recognized. Check for typos.',
    'Missing parenthesis': 'You have missing parentheses in your expression.',
  };

  void _loadStateFromFile(Map<String, dynamic> data) {
    setState(() {
      final linesData = data['lines'] as List;
      for (int i = 0; i < linesData.length && i < _lines.length; i++) {
        _lines[i].controller.text = linesData[i]['expression'] ?? '';
        _lines[i].result = linesData[i]['result'] ?? '';
        _lines[i].error = linesData[i]['error'];
      }
    });
  }

  void _exportToFile() async {
    final content = StringBuffer();
    for (final line in _lines) {
      if (line.controller.text.isNotEmpty) {
        content.writeln('${line.index}. ${line.controller.text}');
        if (line.result.isNotEmpty) {
          content.writeln('   = ${line.result}');
        }
        if (line.error != null) {
          content.writeln('   Error: ${line.error}');
        }
        content.writeln();
      }
    }

    final fileName = await FilePicker.platform.saveFile(
      dialogTitle: 'Export Calculation',
      fileName: 'calculation_${DateTime.now().millisecondsSinceEpoch}.txt',
    );

    if (fileName != null) {
      final file = File(fileName);
      await file.writeAsString(content.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Exported successfully')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    for (final l in _lines) {
      l._listener = () => _onLineChanged(l.index - 1);
      l.controller.addListener(l._listener!);
      l._lastSavedText = l.controller.text; // Initialize saved text
    }

    _speech = stt.SpeechToText();
    _initSpeech();
    _loadThemePreference();
    ConstantsManager.instance.init();
    _requestStoragePermission();
    _checkFirstLaunch();
  }

  @override
  void dispose() {
    for (final l in _lines) {
      l.controller.dispose();
      l.focusNode.dispose();
    }
    _scrollController.dispose();
    super.dispose();
  }

  void _requestStoragePermission() async {
    final status = await Permission.storage.status;
    if (!status.isGranted) {
      await Permission.storage.request();
    }
  }

  void _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _darkMode = prefs.getBool('darkMode') ?? false;
    });
  }

  void _saveThemePreference(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('darkMode', value);
  }

  void _initSpeech() async {
    // Request microphone permission first
    final micStatus = await Permission.microphone.status;
    if (!micStatus.isGranted) {
      await Permission.microphone.request();
    }

    bool available = await _speech.initialize(
      onStatus: (status) {
        setState(() {
          _isListening = status == stt.SpeechToText.listeningStatus;
        });
      },
      onError: (errorNotification) {
        debugPrint('Speech Error: $errorNotification');
        setState(() {
          _isListening = false;
        });
      },
    );

    if (!available && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Speech recognition not available')),
      );
    }
  }

  void _startListening() async {
    // Check microphone permission
    final status = await Permission.microphone.status;
    if (!status.isGranted) {
      final result = await Permission.microphone.request();
      if (result != PermissionStatus.granted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission required')),
        );
        return;
      }
    }

    setState(() {
      _isListening = true;
      _lastWords = ''; // Reset previous words
    });

    try {
      await _speech.listen(
        onResult: (result) {
          setState(() {
            _lastWords = result.recognizedWords;
          });

          // Auto-process when user stops speaking (after 1 second pause)
          if (result.finalResult) {
            _stopListening();
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 1),
      );
    } catch (e) {
      setState(() {
        _isListening = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Speech error: ${e.toString()}')),
      );
    }
  }

  void _stopListening() async {
    await _speech.stop();
    final spoken = _lastWords.trim();

    setState(() {
      _isListening = false;
    });

    if (spoken.isNotEmpty) {
      _processVoiceInput(spoken);
    }

    _lastWords = ''; // Clear after processing
  }

  String _convertNumberWords(String s) {
    final numberWords = {
      'zero': '0', 'one': '1', 'two': '2', 'three': '3', 'four': '4',
      'five': '5', 'six': '6', 'seven': '7', 'eight': '8', 'nine': '9',
      'ten': '10', 'eleven': '11', 'twelve': '12', 'thirteen': '13',
      'fourteen': '14', 'fifteen': '15', 'sixteen': '16', 'seventeen': '17',
      'eighteen': '18', 'nineteen': '19', 'twenty': '20', 'thirty': '30',
      'forty': '40', 'fifty': '50', 'sixty': '60', 'seventy': '70',
      'eighty': '80', 'ninety': '90'
    };

    var result = s;
    numberWords.forEach((word, number) {
      result = result.replaceAll(RegExp('\\b$word\\b'), number);
    });

    return result;
  }

  // Convert spoken words to a math expression string
  String _spokenToExpression(String words) {
    var s = words.toLowerCase().trim();
    
    // Convert number words first
    s = _convertNumberWords(s);

    // multi-word phrases first (longer before shorter)
    final pairs = <String, String>{
      'multiplied by': '*',
      'divided by': '/',
      'to the power of': '^',
      'raised to the power of': '^',
      'square root of': 'sqrt(',
      'open bracket': '(',
      'close bracket': ')',
      'open parentheses': '(',
      'close parentheses': ')',
      'times': '*',
      'over': '/',
      'plus': '+',
      'minus': '-',
      'point': '.',
      'pi': 'pi',
      'e': 'e',
    };
    pairs.forEach((k, v) {
      s = s.replaceAll(RegExp('\\b${RegExp.escape(k)}\\b'), v);
    });

    // Handle functions
    s = s.replaceAllMapped(
      RegExp(r'\b(sqrt|sin|cos|tan|ln|log|exp|abs|ceil|floor|round)\s*([\-]?\d+(\.\d+)?)'),
      (m) => '${m.group(1)}(${m.group(2)})',
    );

    // Auto-close parentheses for sqrt
    if (s.contains('sqrt(') && !s.contains(')')) {
      s += ')';
    }

    // Remove extra spaces around operators
    s = s.replaceAll(RegExp(r'\s*([\+\-\*\/\^\(\)])\s*'), r'$1');
    
    return s.trim();
  }

  void _processVoiceInput(String words) {
    final expression = _spokenToExpression(words);
    final line = _focusedLine ?? _lines.last;

    setState(() {
      // Save current state for undo
      line.saveStateImmediate();

      // Remove listener temporarily to avoid stack corruption
      final hadListener = line._listener != null;
      if (hadListener) {
        line.controller.removeListener(line._listener!);
      }

      // Update text
      line.controller.text = expression;
      line.controller.selection = TextSelection.collapsed(offset: expression.length);

      // Restore listener
      if (hadListener) {
        line.controller.addListener(line._listener!);
      }

      // Manually trigger evaluation
      _onLineChanged(line.index - 1);
    });
  }

  // Add formatting method
  String _formatExpression(String expression) {
    // Add spaces around operators for better readability
    String formatted = expression
        .replaceAllMapped(
          RegExp(r'(\+|\-|\*|\/|\^|%|==|!=|<=|>=|<|>|&&|\|\|)'),
          (match) => ' ${match.group(0)} ',
        )
        .replaceAll(RegExp(r'\s+'), ' ') // Collapse multiple spaces
        .trim();

    // Format functions with proper spacing
    formatted = formatted.replaceAllMapped(RegExp(r'(\w+)\s*\('), (match) {
      return '${match.group(1)}(';
    });

    return formatted;
  }

  void _handleFormat() {
    final line = _focusedLine ?? _lines.last;
    final currentText = line.controller.text;
    final formatted = _formatExpression(currentText);

    setState(() {
      line.saveStateImmediate();
      
      // Remove listener temporarily
      final hadListener = line._listener != null;
      if (hadListener) {
        line.controller.removeListener(line._listener!);
      }

      line.controller.text = formatted;
      
      // Restore listener
      if (hadListener) {
        line.controller.addListener(line._listener!);
      }
      
      _onLineChanged(line.index - 1);
    });
  }

  void _showCalculationSteps(LineData line) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Calculation Steps'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: line.steps.map((step) => Text(step)).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _onLineChanged(int idx) {
    _lines[idx].onTextChanged(_lines[idx].controller.text);
    _expressionCache.clear(); // Clear cache when lines change
    _recomputeFromChanged(idx);
    setState(() {});
  }

  void _recomputeFromChanged(int changedIdx) {
    for (final l in _lines) {
      l.dependsOn = _extractRefs(l.controller.text);
    }

    final cycle = _detectCycle();
    if (cycle.isNotEmpty) {
      for (final i in cycle) {
        _lines[i - 1].error = 'Circular ref';
        _lines[i - 1].result = '';
      }
    }

    final rev = <int, Set<int>>{};
    for (int i = 0; i < _lines.length; i++) {
      for (final d in _lines[i].dependsOn) {
        rev.putIfAbsent(d, () => {}).add(i + 1);
      }
    }

    final affected = <int>{};
    final q = Queue<int>();
    q.add(changedIdx + 1);
    while (q.isNotEmpty) {
      final cur = q.removeFirst();
      if (!affected.add(cur)) continue;
      final dependents = rev[cur];
      if (dependents != null) {
        for (final dep in dependents) q.add(dep);
      }
    }

    final topo = _topologicalOrder();
    if (topo.isEmpty) {
      for (int i = 0; i < _lines.length; i++) {
        if (!cycle.contains(i + 1)) _evaluateLine(i);
      }
      return;
    }

    for (final idx in topo) {
      if (!affected.contains(idx)) continue;
      _evaluateLine(idx - 1);
    }
  }

  List<int> _extractRefs(String s) {
    final refs = <int>{};
    for (final m in RegExp(r"\$(\d+)").allMatches(s)) {
      final n = int.tryParse(m.group(1)!);
      if (n != null) refs.add(n);
    }

    if (RegExp(r"\bAns\b", caseSensitive: false).hasMatch(s)) {
      // Handled during evaluation
    }
    return refs.toList()..sort();
  }

  List<int> _detectCycle() {
    final n = _lines.length;
    final visited = List<int>.filled(n + 1, 0);
    final inCycle = <int>{};

    void dfs(int u) {
      if (visited[u] == 1) {
        inCycle.add(u);
        return;
      }
      if (visited[u] == 2) return;
      visited[u] = 1;
      for (final v in _lines[u - 1].dependsOn) {
        if (v < 1 || v > n) continue;
        dfs(v);
        if (visited[v] == 1) inCycle.add(u);
      }
      visited[u] = 2;
    }

    for (int i = 1; i <= n; i++) {
      if (visited[i] == 0) dfs(i);
    }
    return inCycle.toList()..sort();
  }

  List<int> _topologicalOrder() {
    final n = _lines.length;
    final indeg2 = List<int>.filled(n + 1, 0);
    for (int i = 1; i <= n; i++) {
      indeg2[i] = _lines[i - 1].dependsOn.where((d) => d >= 1 && d <= n).length;
    }

    final adj = <int, List<int>>{};
    for (int i = 0; i < n; i++) {
      for (final d in _lines[i].dependsOn) {
        if (d >= 1 && d <= n) {
          adj.putIfAbsent(d, () => []).add(i + 1);
        }
      }
    }

    final q = Queue<int>();
    for (int i = 1; i <= n; i++) {
      if (indeg2[i] == 0) q.add(i);
    }

    final order = <int>[];
    while (q.isNotEmpty) {
      final u = q.removeFirst();
      order.add(u);
      for (final v in adj[u] ?? []) {
        indeg2[v]--;
        if (indeg2[v] == 0) q.add(v);
      }
    }

    if (order.length != n) {
      return [];
    }
    return order;
  }

  final _expressionCache = <String, String>{};

  void _evaluateLine(int idx) {
    final line = _lines[idx];
    final raw = line.controller.text.trim();

    line.error = null;
    line.result = '';
    line.steps.clear(); // Clear previous steps

    if (raw.isEmpty) return;
    if (line.isComment) return;

    try {
      final expr = _replaceRefs(raw, idx);
      line.steps.add('Expression: $expr');

      String processedExpr = expr.replaceAllMapped(
        RegExp(r'(\d+)!'),
        (match) {
          final n = int.parse(match.group(1)!);
          int result = 1;
          for (int i = 2; i <= n; i++) {
            result *= i;
          }
          return result.toString();
        },
      );

      final parser = Parser();
      parser.parse(processedExpr);
      final cm = ContextModel();

      double val;

      if (expr.startsWith('round(') && expr.endsWith(')')) {
        final innerExpr = expr.substring(6, expr.length - 1);
        line.steps.add('Rounding expression: $innerExpr');
        final innerExp = parser.parse(innerExpr);
        final innerVal = innerExp.evaluate(EvaluationType.REAL, cm);
        line.steps.add('Value before rounding: $innerVal');
        val = innerVal.roundToDouble();
        line.steps.add('Rounded value: $val');
      } else {
        final exp = parser.parse(expr);
        val = exp.evaluate(EvaluationType.REAL, cm);
        line.steps.add('Evaluated result: $val');
      }

      line.result = _formatResult(val);
      line.steps.add('Formatted result: ${line.result}');

      // Add to history
      if (line.error == null) {
        HistoryManager().addHistory(raw, line.result);
      }
    } catch (e) {
      String errorMsg = 'ERR: ${e.toString()}';

      // Provide more specific error messages
      if (e.toString().contains('Division by zero')) {
        errorMsg = 'Division by zero';
      } else if (e.toString().contains('Expected')) {
        errorMsg = 'Syntax error';
      } else if (e.toString().contains('Function not found')) {
        errorMsg = 'Invalid function';
      } else if (e.toString().contains('Parenthesis')) {
        errorMsg = 'Missing parenthesis';
      } else if (e.toString().contains('Bad ref')) {
        errorMsg = 'Bad ref';
      }

      line.error = errorMsg;
      line.result = '';
    }
  }

  String _formatResult(double val) {
    // Handle very small numbers
    if (val.abs() < 1e-12) return '0';

    // Handle very large numbers with scientific notation
    if (val.abs() > 1e9) return val.toStringAsExponential(6);

    // Handle numbers with many decimal places
    final stringVal = val.toString();
    if (stringVal.contains('.')) {
      final parts = stringVal.split('.');
      if (parts[1].length > 6) {
        // Trim to 6 decimal places and remove trailing zeros
        return val
            .toStringAsFixed(6)
            .replaceAll(RegExp(r'0*$'), '')
            .replaceAll(RegExp(r'\.$'), '');
      }
    }

    return stringVal;
  }

  String _replaceRefs(String expr, int thisIdx) {
    final cacheKey = '$expr-$thisIdx';
    if (_expressionCache.containsKey(cacheKey)) {
      return _expressionCache[cacheKey]!;
    }

    // Replace $n references
    expr = expr.replaceAllMapped(RegExp(r"\$(\d+)"), (m) {
      final n = int.parse(m[1]!);
      if (n < 1 || n > _lines.length) throw Exception("Bad ref");
      return _lines[n - 1].result.isNotEmpty ? _lines[n - 1].result : "0";
    });

    // Replace Ans references
    expr = expr.replaceAllMapped(RegExp(r"\bAns\b", caseSensitive: false), (m) {
      if (thisIdx == 0) throw Exception("Ans not available");
      final prev = _lines[thisIdx - 1];
      return prev.result.isNotEmpty ? prev.result : "0";
    });

    // Replace constants
    expr = expr.replaceAllMapped(
      RegExp(r"\bpi\b", caseSensitive: false),
      (m) => math.pi.toString(),
    );

    expr = expr.replaceAllMapped(
      RegExp(r"\be\b", caseSensitive: false),
      (m) => math.e.toString(),
    );

    expr = ConstantsManager.instance.replaceConstants(expr);
    _expressionCache[cacheKey] = expr;
    return expr;
  }

  double get _total {
    Decimal sum = Decimal.zero;
    for (final l in _lines) {
      if (l.result.isEmpty) continue;
      final d = Decimal.tryParse(l.result);
      if (d != null) sum += d;
    }
    return double.parse(sum.toString());
  }

  LineData? get _focusedLine =>
      _lines.firstWhereOrNull((l) => l.focusNode.hasFocus);

  void _addNewLineAndFocus() {
    setState(() {
      final newLine = LineData(_lines.length + 1);
      newLine._listener = () => _onLineChanged(newLine.index - 1);
      newLine.controller.addListener(newLine._listener!);
      _lines.add(newLine);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        FocusScope.of(context).requestFocus(newLine.focusNode);
      });
    });
  }

  void _insertText(String text) {
    setState(() {
      // Get the focused line or the last line if none is focused
      final line = _focusedLine ?? _lines.last;
      final controller = line.controller;
      final selection = controller.selection;
      int start = selection.start < 0 ? controller.text.length : selection.start;
      int end = selection.end < 0 ? controller.text.length : selection.end;
      final full = controller.text;

      // Save current state for undo
      line.saveStateImmediate();

      // Handle special tokens first
      if (text == kBackspaceToken) {
        // Handle backspace / selection
        if (start != end) {
          final newText = full.replaceRange(start, end, '');
          controller.text = newText;
          controller.selection = TextSelection.collapsed(offset: start);
        } else if (start > 0) {
          final newText = full.substring(0, start - 1) + full.substring(end);
          controller.text = newText;
          controller.selection = TextSelection.collapsed(offset: start - 1);
        }
        _evaluateLine(line.index - 1);
        return;
      }

      if (text == kClearAllToken) {
        _clearAllLines();
        return;
      }

      if (text == kEnterToken) {
        _addNewLineAndFocus();
        return;
      }

      // Map certain keypad representations to parser-friendly text
      String toInsert;
      if (text == 'log') {
        toInsert = 'log(,10)';
      } else if (text == 'exp') {
        toInsert = 'exp()';
      } else if (text == 'round') {
        toInsert = 'round()';
      } else if ([
        'sin',
        'cos',
        'tan',
        'ln',
        'sqrt',
        'abs',
        'ceil',
        'floor',
      ].contains(text)) {
        toInsert = '$text()';
      } else if (text == 'π') {
        toInsert = 'pi';
      } else if (text == 'e') {
        toInsert = 'e';
      } else if (text == 'x²') {
        toInsert = '^2';
      } else if (text == 'x³') {
        toInsert = '^3';
      } else if (text == '√') {
        toInsert = 'sqrt()';
      } else if (text == '()') {
        toInsert = '()';
      } else if (text == 'Ans') {
        toInsert = 'Ans';
      } else if (text == '←') {
        // Move cursor left
        final pos = start > 0 ? start - 1 : 0;
        controller.selection = TextSelection.collapsed(offset: pos);
        return;
      } else if (text == '→') {
        final pos = start < full.length ? start + 1 : full.length;
        controller.selection = TextSelection.collapsed(offset: pos);
        return;
      } else {
        // default insert raw
        toInsert = text;
      }

      // If function-style inserted, place cursor inside parentheses for convenience
      int newCursorPosition;
      if (toInsert.endsWith('()')) {
        // insert and place cursor between parens
        final insertText = toInsert;
        final newText = full.replaceRange(start, end, insertText);
        newCursorPosition = start + insertText.indexOf(')'); // position between ()
        controller.text = newText;
        controller.selection = TextSelection.collapsed(offset: newCursorPosition);
      } else if (toInsert.contains('()') && toInsert.startsWith('log(')) {
        // special-case log(,10)
        final newText = full.replaceRange(start, end, toInsert);
        controller.text = newText;
        controller.selection = TextSelection.collapsed(offset: start + 4); // after 'log('
      } else if (toInsert.contains('sqrt(') && !toInsert.contains(')')) {
        // ensure sqrt() has parentheses
        final insertText = toInsert;
        final newText = full.replaceRange(start, end, insertText);
        controller.text = newText;
        controller.selection = TextSelection.collapsed(offset: start + insertText.length - 1); // inside paren
      } else {
        final newText = full.replaceRange(start, end, toInsert);
        newCursorPosition = start + toInsert.length;
        controller.text = newText;
        controller.selection = TextSelection.collapsed(offset: newCursorPosition);
      }

      _evaluateLine(line.index - 1);
    });
  }

  void _clearAllLines() {
    setState(() {
      for (final line in _lines) {
        line.controller.clear();
        line.result = '';
        line.error = null;
        line.dependsOn.clear();
      }
    });
  }


  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: _darkMode ? ThemeData.dark() : ThemeData.light(),
      home: Scaffold(
        drawer: Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Theme.of(context).primaryColor, Colors.blueAccent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Align(
                  alignment: Alignment.bottomLeft,
                  child: Text(
                    'CalcNote',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              ListTile(
                leading: const Icon(Icons.folder),
                title: const Text('File Manager'),
                onTap: () async {
                  // Navigator.pop(context);
                  final loadedData = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FileManagerScreen(lines: _lines),
                    ),
                  );

                  if (loadedData != null) {
                    _loadStateFromFile(loadedData);
                  }
                },
              ),

              ListTile(
                leading: const Icon(Icons.show_chart),
                title: const Text('Graphing'),
                onTap: () {
                  // Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const GraphingScreen(),
                    ),
                  );
                },
              ),

              ListTile(
                leading: const Icon(Icons.bar_chart),
                title: const Text('Statistics'),
                onTap: () {
                  // Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const StatisticsScreen(),
                    ),
                  );
                },
              ),

              ListTile(
                leading: const Icon(Icons.swap_horiz),
                title: const Text('Unit Converter'),
                onTap: () {
                  // Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const UnitConverterScreen(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.library_books),
                title: const Text('Expression Templates'),
                onTap: () async {
                  // Navigator.pop(context);
                  final selectedTemplate = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TemplatesScreen(),
                    ),
                  );

                  if (selectedTemplate != null) {
                    final line = _focusedLine ?? _lines.last;
                    setState(() {
                      line.controller.text = selectedTemplate;
                      _onLineChanged(line.index - 1);
                    });
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.trip_origin),
                title: const Text('Custom Constants'),
                onTap: () {
                  // Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ConstantsScreen(),
                    ),
                  );
                },
              ),

              ListTile(
                leading: const Icon(Icons.history),
                title: const Text('History'),
                onTap: () async {
                  // Navigator.pop(context);
                  final selectedExpression = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => HistoryScreen()),
                  );

                  if (selectedExpression != null) {
                    final line = _focusedLine ?? _lines.last;
                    setState(() {
                      line.controller.text = selectedExpression;
                      _onLineChanged(line.index - 1);
                    });
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.star),
                title: const Text('Favorites'),
                onTap: () async {
                  // Navigator.pop(context);
                  final selectedExpression = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => FavouriteScreen()),
                  );

                  if (selectedExpression != null) {
                    final line = _focusedLine ?? _lines.last;
                    setState(() {
                      line.controller.text = selectedExpression;
                      _onLineChanged(line.index - 1);
                    });
                  }
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('Settings'),
                onTap: () {
                  // Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => SettingsScreen()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.help_outline),
                title: const Text('Tutorial & Help'),
                onTap: () {
                  // Navigator.pop(context);
                  _showTutorial();
                },
              ),
            ],
          ),
        ),

        appBar: AppBar(
          title: const Text(
            'CalcNote',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
          ),
          centerTitle: true,
          elevation: 1,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
          ),
          surfaceTintColor: Colors.transparent,
          actions: [
            IconButton(icon: const Icon(Icons.help), onPressed: _showTutorial),
            IconButton(
              icon: Icon(_isListening ? Icons.mic_off : Icons.mic),
              onPressed: () {
                if (_isListening) {
                  _stopListening();
                } else {
                  _startListening();
                }
              },
            ),
            PopupMenuButton<String>(
              itemBuilder:
                  (context) => [
                    PopupMenuItem(
                      value: 'format',
                      child: Row(
                        children: const [
                          Icon(Icons.format_align_left, size: 20),
                          SizedBox(width: 8),
                          Text('Format Expression'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'undo',
                      enabled: _focusedLine?.canUndo ?? false,
                      child: Row(
                        children: const [
                          Icon(Icons.undo, size: 20),
                          SizedBox(width: 8),
                          Text('Undo'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'redo',
                      enabled: _focusedLine?.canRedo ?? false,
                      child: Row(
                        children: const [
                          Icon(Icons.redo, size: 20),
                          SizedBox(width: 8),
                          Text('Redo'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'toggle_theme',
                      child: Row(
                        children: [
                          Icon(
                            _darkMode ? Icons.light_mode : Icons.dark_mode,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(_darkMode ? 'Light Mode' : 'Dark Mode'),
                        ],
                      ),
                    ),

                    PopupMenuItem(
                      value: 'save_file',
                      child: Row(
                        children: const [
                          Icon(Icons.file_open_sharp, size: 20),
                          SizedBox(width: 8),
                          Text('Export Calculation'),
                        ],
                      ),
                    ),

                    PopupMenuItem(
                      value: 'export_pdf',
                      child: Row(
                        children: const [
                          Icon(Icons.picture_as_pdf, size: 20),
                          SizedBox(width: 8),
                          Text('Export to PDF'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'share_image',
                      child: Row(
                        children: const [
                          Icon(Icons.image, size: 20),
                          SizedBox(width: 8),
                          Text('Share as Image'),
                        ],
                      ),
                    ),
                  ],
              onSelected: (value) {
              
  if (value == 'undo') {
    final focusedLine = _focusedLine ?? _lines.last;
    setState(() {
      focusedLine.undo();
      // Manually trigger evaluation since we bypassed the listener
      _onLineChanged(focusedLine.index - 1);
    });
  } else if (value == 'redo') {
    final focusedLine = _focusedLine ?? _lines.last;
    setState(() {
      focusedLine.redo();
      // Manually trigger evaluation
      _onLineChanged(focusedLine.index - 1);
    });
  } else if (value == 'toggle_theme') {
                  setState(() {
                    _darkMode = !_darkMode;
                    _saveThemePreference(_darkMode);
                  });
                } else if (value == 'save_file') {
                  _exportToFile();
                } else if (value == 'format') {
                  _handleFormat();
                } else if (value == 'export_pdf') {
                  ExportManager.exportToPdf(_lines, 'calculation_export');
                } else if (value == 'share_image') {
                  ExportManager.shareAsImage(_lines);
                }
              },
              icon: const Icon(Icons.more_vert),
            ),
           ],
        ),

        body: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: _lines.length,
                    itemBuilder:
                        (context, i) => _LineRow(
                          line: _lines[i],
                          onTapNumber:
                              () => _insertText('\$${_lines[i].index}'),
                          onRequestFocusIfNone: () {
                            if (_focusedLine == null) {
                              FocusScope.of(
                                context,
                              ).requestFocus(_lines[i].focusNode);
                            }
                          },
                          onShowSteps: () => _showCalculationSteps(_lines[i]),
                          readOnly: !isKeyboardEnabled,
                          darkMode: _darkMode,
                          errorExplanations: _errorExplanations,
                        ),
                  ),
                ),

                _BottomBar(
                  totalText: _formatNumberForDisplay(_total),
                  showKeypad: _showKeypad,
                  keypadPage: _keypadPage,
                  onTab123:
                      () => setState(() {
                        _showKeypad = true;
                        isKeyboardEnabled = false;
                        _keypadPage = 0;
                      }),
                  onTabABC:
                      () => setState(() {
                        _showKeypad = false;
                        isKeyboardEnabled = true;
                      }),
                  onTabKeypad:
                      () => setState(() {
                        _showKeypad = true;
                        isKeyboardEnabled = false;
                      }),
                  keypad:
                      _showKeypad
                          ? _Keypad(
                            page: _keypadPage,
                            onPageChanged:
                                (p) => setState(() => _keypadPage = p),
                            onKey: _insertText,
                            onFormat: _handleFormat,
                            darkMode: _darkMode,
                          )
                          : null,
                  darkMode: _darkMode,
                ),
              ],
            ),
           if (_isListening)
  Positioned.fill(
    child: Container(
      color: Colors.black54,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.mic, size: 64, color: Colors.white),
            const SizedBox(height: 16),
            const Text(
              'Listening... Speak now',
              style: TextStyle(color: Colors.white, fontSize: 24),
            ),
            const SizedBox(height: 8),
            Text(
              _lastWords,
              style: const TextStyle(color: Colors.white, fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (_lastWords.isNotEmpty)
              const Text(
                'Processing automatically...',
                style: TextStyle(color: Colors.yellow, fontSize: 14),
              ),
          ],
        ),
      ),
    ),
  ),
          ],
        ),

        floatingActionButton: FloatingActionButton(
          onPressed: _addNewLineAndFocus,
          child: const Icon(Icons.add),
          mini: true,
          heroTag: 'addLine',
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  String _formatNumberForDisplay(double v) {
    if (v.isInfinite) return "∞";
    if (v.isNaN) return "NaN";

    if (v == v.roundToDouble()) return v.toStringAsFixed(0);

    // Format with appropriate precision
    final absV = v.abs();
    if (absV < 0.0001) {
      return v.toStringAsExponential(4);
    } else if (absV > 1000000) {
      return v.toStringAsExponential(4);
    } else {
      return v
          .toStringAsFixed(4)
          .replaceAll(RegExp(r'0+$'), '')
          .replaceAll(RegExp(r'\.$'), '');
    }
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow({
    required this.line,
    required this.onTapNumber,
    required this.onRequestFocusIfNone,
    required this.readOnly,
    required this.darkMode,
    required this.errorExplanations,
    required this.onShowSteps,
  });

  final LineData line;
  final VoidCallback onTapNumber;
  final VoidCallback onRequestFocusIfNone;
  final bool readOnly;
  final bool darkMode;
  final Map<String, String> errorExplanations;
  final VoidCallback onShowSteps;

  @override
  Widget build(BuildContext context) {
    final resultStyle = TextStyle(
      color:
          line.error != null
              ? Colors.red
              : darkMode
              ? Colors.lightGreenAccent
              : Colors.green[700],
      fontFeatures: const [FontFeature.tabularFigures()],
      fontSize: 14,
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color:
            line.focusNode.hasFocus
                ? (darkMode ? Colors.blueGrey[900] : Colors.blue[50])
                : (darkMode ? Colors.grey[850] : Colors.white),
        borderRadius: BorderRadius.circular(12),
        boxShadow:
            line.focusNode.hasFocus
                ? [
                  BoxShadow(color: Colors.blue.withOpacity(0.2), blurRadius: 8),
                ]
                : [],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: onTapNumber,
            child: Container(
              width: 10,
              alignment: Alignment.centerRight,
              child: Text(
                '${line.index}',
                style: TextStyle(
                  fontFamily: 'RobotoMono', // monospaced
                  fontSize: 15,
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Focus(
              child: TextField(
                focusNode: line.focusNode,
                showCursor: true,
                enableInteractiveSelection: true,
                readOnly: readOnly,
                controller: line.controller,
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText:
                      line.index == 1 ? 'Enter expression or comment' : '',
                  hintStyle: TextStyle(
                    color: darkMode ? Colors.grey[500] : Colors.grey[600],
                  ),
                ),
                style: TextStyle(
                  color:
                      line.isComment
                          ? (darkMode ? Colors.cyanAccent : Colors.blue[700])
                          : (darkMode ? Colors.white : Colors.black),
                ),
                maxLines: 1,
                textInputAction: TextInputAction.done,
                onTap: onRequestFocusIfNone,
                inputFormatters: [
                  FilteringTextInputFormatter.deny(RegExp(r'[\t]')),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Align(
              alignment: Alignment.centerRight,
              child: InkWell(
                onTap: onShowSteps,
                child: Text(
                  line.error != null ? line.error! : line.result,
                  style: resultStyle,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            itemBuilder:
                (context) => [
                  PopupMenuItem(
                    value: 'copy_expression',
                    child: Row(
                      children: const [
                        Icon(Icons.content_copy, size: 20),
                        SizedBox(width: 8),
                        Text('Copy Expression'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'copy_result',
                    enabled: line.result.isNotEmpty && line.error == null,
                    child: Row(
                      children: const [
                        Icon(Icons.content_copy, size: 20),
                        SizedBox(width: 8),
                        Text('Copy Result'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: line.isFavorite ? 'remove_favorite' : 'add_favorite',
                    enabled: line.result.isNotEmpty && line.error == null,
                    child: Row(
                      children: [
                        Icon(
                          line.isFavorite ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          line.isFavorite ? 'Remove Favorite' : 'Add Favorite',
                        ),
                      ],
                    ),
                  ),
                ],
            onSelected: (value) {
              if (value == 'copy_expression') {
                Clipboard.setData(ClipboardData(text: line.controller.text));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Expression copied to clipboard'),
                  ),
                );
              } else if (value == 'copy_result' && line.result.isNotEmpty) {
                Clipboard.setData(ClipboardData(text: line.result));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Result copied to clipboard')),
                );
              } else if (value == 'add_favorite' &&
                  line.result.isNotEmpty &&
                  line.error == null) {
                FavoritesManager().addFavorite(
                  line.controller.text,
                  line.result,
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Added to favorites')),
                );
              } else if (value == 'remove_favorite') {
                FavoritesManager().removeFavorite(line.controller.text);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Removed from favorites')),
                );
              }
            },
            icon: const Icon(Icons.more_vert, size: 20),
          ),
          if (line.error != null)
            Tooltip(
              message:
                  errorExplanations[line.error!] ?? 'Unknown error occurred',
              child: const Icon(
                Icons.info_outline,
                size: 16,
                color: Colors.red,
              ),
            ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.totalText,
    required this.showKeypad,
    required this.keypadPage,
    required this.onTab123,
    required this.onTabABC,
    required this.onTabKeypad,
    required this.darkMode,
    this.keypad,
  });

  final String totalText;
  final bool showKeypad;
  final int keypadPage;
  final VoidCallback onTab123;
  final VoidCallback onTabABC;
  final VoidCallback onTabKeypad;
  final Widget? keypad;
  final bool darkMode;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          margin: const EdgeInsets.all(8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: darkMode ? Colors.grey[900] : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 6,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              ChoiceChip(
                label: const Text('123'),
                selected: showKeypad,
                onSelected: (_) => onTab123(),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('ABC'),
                selected: !showKeypad,
                onSelected: (_) => onTabABC(),
              ),
              const Spacer(),
              Text('Total:', style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(width: 6),
              Text(
                totalText,
                overflow: TextOverflow.ellipsis,
                maxLines: 1, 
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: darkMode ? Colors.greenAccent : Colors.green[700],
                ),
              ),
            ],
          ),
        ),
        if (keypad != null) keypad!,
      ],
    );
  }
}

class _Keypad extends StatefulWidget {
  const _Keypad({
    required this.onKey,
    required this.page,
    required this.onPageChanged,
    required this.onFormat,
    required this.darkMode,
  });

  final void Function(String text) onKey;
  final int page;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onFormat;
  final bool darkMode;

  @override
  State<_Keypad> createState() => _KeypadState();
}

class _KeypadState extends State<_Keypad> {
  late final PageController _pc = PageController(initialPage: widget.page);

  @override
  void didUpdateWidget(covariant _Keypad oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.page != oldWidget.page) {
      _pc.jumpToPage(widget.page);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      color: widget.darkMode ? Colors.black : Colors.grey[50],
      height: 300,
      child: PageView(
        controller: _pc,
        physics: const BouncingScrollPhysics(),
        onPageChanged: widget.onPageChanged,
        children: [
          _KeypadGrid(
            keys: [
              '7',
              '8',
              '9',
              '+',
              kBackspaceToken,
              '4',
              '5',
              '6',
              '-',
              kClearAllToken,
              '1',
              '2',
              '3',
              '*',
              '()',
              '0',
              '00',
              '.',
              '/',
              kEnterToken,
            ],
            onKey: _handleBasic,
            darkMode: widget.darkMode,
          ),
          _KeypadGrid(
            keys: [
              'Ans',
              '(',
              ')',
              '^',
              '%',
              'sin',
              'cos',
              'tan',
              'log',
              '√',
              'π',
              'exp',
              'abs',
              'round',
              'ceil',
              'floor',
              'x²',
              'x³',
              'ln',
              kClearAllToken,
            ],
            onKey: widget.onKey,
            darkMode: widget.darkMode,
          ),
          _KeypadGrid(
            keys: [
              '←',
              '→',
              '=',
              '%',
              kClearAllToken,
              ',',
              ':',
              ';',
              '#',
              'Format',
            ],
            onKey: _handleBasic,
            darkMode: widget.darkMode,
          ),
        ],
      ),
    );
  }

  void _handleBasic(String k) {
    switch (k) {
      case 'Format':
        widget.onFormat();
        break;
      case '()':
        widget.onKey('()');
        break;
      case kBackspaceToken:
        widget.onKey(kBackspaceToken);
        break;
      case kClearAllToken:
        widget.onKey(kClearAllToken);
        break;
      case kEnterToken:
        widget.onKey(kEnterToken);
        break;
      default:
        widget.onKey(k);
    }
  }
}

class _KeypadGrid extends StatefulWidget {
  const _KeypadGrid({
    required this.keys,
    required this.onKey,
    required this.darkMode,
  });

  final List<String> keys;
  final void Function(String) onKey;
  final bool darkMode;

  @override
  State<_KeypadGrid> createState() => _KeypadGridState();
}

class _KeypadGridState extends State<_KeypadGrid> {
  String? _pressedKey;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.2,
      ),
      itemCount: widget.keys.length,
      itemBuilder: (context, i) {
        final k = widget.keys[i];
        return _buildButton(k);
      },
    );
  }

  Widget _buildButton(String k) {
    // Display
    Widget child;
    switch (k) {
      case kBackspaceToken:
        child = const Icon(Icons.backspace, size: 22);
        break;
      case kClearAllToken:
        child = const Text(
          'Clear',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        );
        break;
      case kEnterToken:
        child = const Icon(Icons.keyboard_return, size: 22);
        break;
      case 'Format':
        child = const Icon(Icons.format_align_left, size: 22);
        break;
      default:
        child = Text(k, style: const TextStyle(fontSize: 16));
    }

    // Color coding
    final isOperator = ['+', '-', '*', '/', '^', '%'].contains(k);
    final bgColor =
        k == kClearAllToken
            ? Colors.red.shade300
            : k == kEnterToken
            ? Colors.green.shade400
            : isOperator
            ? Colors.blue.shade300
            : widget.darkMode
            ? Colors.grey[850]
            : Colors.grey[200];

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressedKey = k),
      onTapUp: (_) {
        setState(() => _pressedKey = null);
        widget.onKey(k);
      },
      onTapCancel: () => setState(() => _pressedKey = null),
      child: AnimatedScale(
        scale: _pressedKey == k ? 0.9 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: ElevatedButton(
          onPressed: null, // handled by GestureDetector
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.zero,
            backgroundColor: bgColor,
            foregroundColor: Colors.white,
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class HistoryManager {
  static final HistoryManager _instance = HistoryManager._internal();
  factory HistoryManager() => _instance;
  HistoryManager._internal();

  final List<HistoryItem> _history = [];
  static const int maxHistoryItems = 100;

  void addHistory(String expression, String result) {
    _history.insert(0, HistoryItem(expression, result, DateTime.now()));
    if (_history.length > maxHistoryItems) {
      _history.removeLast();
    }
  }

  List<HistoryItem> getHistory() => List.unmodifiable(_history);

  void clearHistory() {
    _history.clear();
  }

  /// 👇 new method
  void removeAt(int index) {
    if (index >= 0 && index < _history.length) {
      _history.removeAt(index);
    }
  }
}

class HistoryItem {
  final String expression;
  final String result;
  final DateTime timestamp;

  HistoryItem(this.expression, this.result, this.timestamp);
}
