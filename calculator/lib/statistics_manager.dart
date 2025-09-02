import 'dart:math' as math;

class StatisticsManager {
  /// Returns common statistical measures for a dataset.
  /// 
  /// [asSample] controls whether variance/std dev are population (false) 
  /// or sample (true).
  static Map<String, dynamic> calculateStats(List<double> data, {bool asSample = false}) {
    if (data.isEmpty) {
      return {};
    }

    // Work on a copy so original list isn't mutated
    final sorted = [...data]..sort();

    final count = sorted.length;
    final sum = sorted.reduce((a, b) => a + b);
    final mean = sum / count;

    // Variance (population or sample)
    final squaredDiffs = sorted.map((x) => math.pow(x - mean, 2) as double).toList();
    final variance = squaredDiffs.reduce((a, b) => a + b) / (asSample && count > 1 ? count - 1 : count);

    // Median
    late double median;
    if (count % 2 == 0) {
      median = (sorted[count ~/ 2 - 1] + sorted[count ~/ 2]) / 2;
    } else {
      median = sorted[count ~/ 2];
    }

    // Mode (can be multiple)
    final frequencyMap = <double, int>{};
    for (final value in sorted) {
      frequencyMap[value] = (frequencyMap[value] ?? 0) + 1;
    }

    final maxFrequency = frequencyMap.values.reduce(math.max);
    final modes = frequencyMap.entries
        .where((e) => e.value == maxFrequency)
        .map((e) => e.key)
        .toList();

    return {
      'Count': count,
      'Sum': sum,
      'Mean': mean,
      'Median': median,
      'Mode': modes.length == 1 ? modes.first : modes,
      'Min': sorted.first,
      'Max': sorted.last,
      'Range': sorted.last - sorted.first,
      'Variance': variance,
      'Std Dev': math.sqrt(variance),
    };
  }
}
