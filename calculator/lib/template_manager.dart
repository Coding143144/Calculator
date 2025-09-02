import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class TemplateManager {
  static final TemplateManager _instance = TemplateManager._internal();
  factory TemplateManager() => _instance;
  TemplateManager._internal();

  /// Built-in templates (always present)
  final Map<String, Map<String, String>> _templates = {
    'Algebra': {
      'Quadratic Formula': 'x = (-b ± √(b² - 4ac)) / (2a)',
      'Distance Formula': 'd = √((x₂ - x₁)² + (y₂ - y₁)²)',
      'Slope Formula': 'm = (y₂ - y₁) / (x₂ - x₁)',
      'Midpoint Formula': 'M = ((x₁ + x₂)/2 , (y₁ + y₂)/2)',
      'Simple Interest': 'SI = (P × R × T) / 100',
      'Compound Interest': 'A = P(1 + R/100)ⁿ',
    },
    'Geometry': {
      'Area of Circle': 'A = πr²',
      'Circumference': 'C = 2πr',
      'Area of Triangle': 'A = (1/2)bh',
      'Pythagorean Theorem': 'a² + b² = c²',
      'Surface Area of Sphere': 'A = 4πr²',
      'Volume of Sphere': 'V = (4/3)πr³',
      'Volume of Cylinder': 'V = πr²h',
      'Surface Area of Cylinder': 'A = 2πr(h + r)',
      'Area of Rectangle': 'A = l × w',
      'Perimeter of Rectangle': 'P = 2(l + w)',
    },
    'Trigonometry': {
      'Sine': 'sin(θ) = opposite/hypotenuse',
      'Cosine': 'cos(θ) = adjacent/hypotenuse',
      'Tangent': 'tan(θ) = opposite/adjacent',
      'Pythagorean Identity': 'sin²θ + cos²θ = 1',
      'tanθ': 'tanθ = sinθ / cosθ',
      'cotθ': 'cotθ = cosθ / sinθ',
      'secθ': 'secθ = 1 / cosθ',
      'cscθ': 'cscθ = 1 / sinθ',
    },
    'Calculus': {
      'Derivative Power Rule': 'd/dx(xⁿ) = nxⁿ⁻¹',
      'Derivative of e^x': 'd/dx(e^x) = e^x',
      'Derivative of ln(x)': 'd/dx(ln(x)) = 1/x',
      'Integral Power Rule': '∫xⁿ dx = xⁿ⁺¹ / (n+1) + C',
      'Integral of e^x': '∫e^x dx = e^x + C',
      'Integral of 1/x': '∫1/x dx = ln|x| + C',
    },
    'Probability & Statistics': {
      'Mean': 'x̄ = (Σx) / n',
      'Median (odd n)': 'Middle value of sorted data',
      'Median (even n)': 'Average of two middle values',
      'Mode': 'Most frequent value in data',
      'Probability': 'P(E) = (Number of favorable outcomes) / (Total outcomes)',
      'Combination': 'nCr = n! / [r!(n-r)!]',
      'Permutation': 'nPr = n! / (n-r)!',
    },
    'Physics Basics': {
      'Speed': 'Speed = Distance / Time',
      'Velocity': 'Velocity = Displacement / Time',
      'Acceleration': 'a = (v - u) / t',
      'Force': 'F = m × a',
      'Work': 'W = F × d × cosθ',
      'Power': 'P = Work / Time',
      'Kinetic Energy': 'KE = (1/2)mv²',
      'Potential Energy': 'PE = mgh',
      'Ohm’s Law': 'V = IR',
    },
    // user templates stored here
    'User Templates': {},
  };

  Map<String, Map<String, String>> get templates => _templates;

  static const String _prefsKeyUserTemplates = 'userTemplates_v1';

  /// Load saved user templates from SharedPreferences
  Future<void> loadTemplates() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKeyUserTemplates);
    if (saved != null && saved.isNotEmpty) {
      try {
        final Map decoded = jsonDecode(saved) as Map;
        final Map<String, String> userMap = decoded.map(
          (k, v) => MapEntry(k.toString(), v.toString()),
        );
        _templates['User Templates'] = userMap;
      } catch (_) {
        _templates['User Templates'] = {};
      }
    } else {
      _templates['User Templates'] = {};
    }
  }

  /// Add a template. If category is not present, it will be created.
  /// User templates are persisted; built-ins are not overwritten by loadTemplates.
  Future<void> addTemplate(String category, String name, String expression) async {
    if (!_templates.containsKey(category)) {
      _templates[category] = {};
    }
    _templates[category]![name] = expression;
    if (category == 'User Templates') {
      await _saveUserTemplates();
    }
  }

  /// Edit a user template (rename or change expression)
  Future<void> editUserTemplate(String oldName, String newName, String newExpression) async {
    final userMap = _templates['User Templates'] ?? {};
    if (!userMap.containsKey(oldName)) return;
    // If renaming, remove old key
    if (oldName != newName) {
      userMap.remove(oldName);
    }
    userMap[newName] = newExpression;
    _templates['User Templates'] = userMap;
    await _saveUserTemplates();
  }

  /// Delete a user template by name
  Future<void> deleteUserTemplate(String name) async {
    final userMap = _templates['User Templates'] ?? {};
    if (userMap.containsKey(name)) {
      userMap.remove(name);
      _templates['User Templates'] = userMap;
      await _saveUserTemplates();
    }
  }

  Future<void> _saveUserTemplates() async {
    final prefs = await SharedPreferences.getInstance();
    final userTemplates = _templates['User Templates'] ?? {};
    await prefs.setString(_prefsKeyUserTemplates, jsonEncode(userTemplates));
  }
}
