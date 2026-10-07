// Scores photo-estimate results against weighed, labelled meals.
//
//   dart run tool/photo_eval.dart path/to/meals.csv
//
// The CSV (see docs/PHOTO_ESTIMATE_EVALUATION.md) has one row per food:
//
//   meal,category,run,food,matches,grams,kcal,protein
//   m01,filipino,truth,White rice,,200,260,5.4
//   m01,filipino,flash-lite,Kanin,White rice,250,325,6.75
//
// `run` is `truth` for what was really on the plate (weighed), or a label for
// one model/configuration. For a suggestion, `matches` names the truth food it
// corresponds to (blank = a false suggestion); blank kcal/protein = the app
// didn't count it. Nothing here calls a model — it only scores what you record.
import 'dart:io';
import 'dart:math' as math;

/// Mean error of matched portions, in grams.
class PortionError {
  const PortionError(this.count, this.meanAbsolute, this.meanSigned, this.meanAbsolutePercent);
  final int count;
  final double meanAbsolute;

  /// Positive = the photo estimate was larger than the weighed amount.
  final double meanSigned;
  final double meanAbsolutePercent;
}

/// Error of a meal's total calories or protein.
class TotalError {
  const TotalError(this.meals, this.meanAbsolute, this.meanSigned, this.percentOfMean);
  final int meals;
  final double meanAbsolute;

  /// Positive = overestimated on average (bias).
  final double meanSigned;

  /// Mean absolute error as a percentage of the mean weighed total (as in Nutrition5k).
  final double percentOfMean;
}

class RunScore {
  RunScore(this.run, this.category);
  final String run;

  /// `all`, or one category such as `filipino`.
  final String category;
  int meals = 0;
  int truthFoods = 0;
  int predicted = 0;
  int matchedPredictions = 0;
  int foundTruth = 0;
  int uncounted = 0;
  final missed = <String>[];
  final falseSuggestions = <String>[];
  PortionError? grams;
  TotalError? kcal;
  TotalError? protein;

  /// Share of suggested foods that were really on the plate.
  double? get precision => predicted == 0 ? null : matchedPredictions / predicted;

  /// Share of the foods on the plate that were suggested.
  double? get recall => truthFoods == 0 ? null : foundTruth / truthFoods;
}

class EvalReport {
  const EvalReport(this.scores);
  final List<RunScore> scores;

  String format() {
    String pct(double? v) => v == null ? '—' : '${(v * 100).toStringAsFixed(0)} %';
    String n(double v) => v.toStringAsFixed(1);
    final out = StringBuffer();
    for (final s in scores) {
      out
        ..writeln('${s.run} · ${s.category} · ${s.meals} meals')
        ..writeln(
          '  foods: precision ${pct(s.precision)}, recall ${pct(s.recall)} '
          '(${s.predicted} suggested, ${s.truthFoods} on plates, ${s.uncounted} not counted by the app)',
        );
      if (s.missed.isNotEmpty) out.writeln('  missed: ${s.missed.join('; ')}');
      if (s.falseSuggestions.isNotEmpty) out.writeln('  false suggestions: ${s.falseSuggestions.join('; ')}');
      if (s.grams case final g?) {
        out.writeln(
          '  portions (${g.count}): MAE ${n(g.meanAbsolute)} g, bias ${n(g.meanSigned)} g, '
          '${n(g.meanAbsolutePercent)} % off on average',
        );
      }
      for (final (label, t) in [('kcal', s.kcal), ('protein g', s.protein)]) {
        if (t == null) continue;
        out.writeln(
          '  $label per meal (${t.meals}): MAE ${n(t.meanAbsolute)}, bias ${n(t.meanSigned)}, '
          '${n(t.percentOfMean)} % of the mean',
        );
      }
    }
    return out.toString();
  }
}

typedef _Row = ({
  String meal,
  String category,
  String run,
  String food,
  String matches,
  double? grams,
  double? kcal,
  double? protein,
});

EvalReport scorePhotoEval(String csv) {
  final rows = _parse(csv);
  final truth = <String, List<_Row>>{};
  for (final r in rows.where((r) => r.run == 'truth')) {
    (truth[r.meal] ??= []).add(r);
  }
  for (final r in rows.where((r) => r.run != 'truth' && r.matches.isNotEmpty)) {
    if (!(truth[r.meal] ?? const []).any((t) => t.food == r.matches)) {
      throw FormatException('${r.meal}: "${r.food}" matches "${r.matches}", which isn’t a truth food in that meal');
    }
  }
  final runs = {for (final r in rows) r.run}.where((r) => r != 'truth').toList()..sort();
  final categories = {for (final r in rows) r.category}.toList()..sort();
  return EvalReport([
    for (final run in runs)
      for (final category in ['all', ...categories])
        ?_score(run, category, rows.where((r) => r.run == run).toList(), truth),
  ]);
}

RunScore? _score(String run, String category, List<_Row> predictions, Map<String, List<_Row>> truth) {
  final meals = {
    for (final p in predictions)
      if (category == 'all' || p.category == category) p.meal,
  }.toList()..sort();
  if (meals.isEmpty) return null;
  final s = RunScore(run, category)..meals = meals.length;
  final gramErrors = <(double, double)>[];
  final kcal = <(double, double)>[];
  final protein = <(double, double)>[];
  for (final meal in meals) {
    final plate = truth[meal] ?? const <_Row>[];
    final guesses = predictions.where((p) => p.meal == meal).toList();
    s
      ..truthFoods += plate.length
      ..predicted += guesses.length
      ..uncounted += guesses.where((g) => g.kcal == null).length;
    for (final g in guesses) {
      if (g.matches.isEmpty) {
        s.falseSuggestions.add('$meal: ${g.food}');
      } else {
        s.matchedPredictions++;
      }
    }
    for (final t in plate) {
      final hits = guesses.where((g) => g.matches == t.food).toList();
      if (hits.isEmpty) {
        s.missed.add('$meal: ${t.food}');
        continue;
      }
      s.foundTruth++;
      final estimated = hits.map((h) => h.grams).whereType<double>();
      if (t.grams != null && estimated.isNotEmpty) gramErrors.add((estimated.reduce((a, b) => a + b), t.grams!));
    }
    double sum(Iterable<double?> v) => v.fold(0, (a, b) => a + (b ?? 0));
    if (plate.isNotEmpty && plate.every((t) => t.kcal != null)) {
      kcal.add((sum(guesses.map((g) => g.kcal)), sum(plate.map((t) => t.kcal))));
    }
    if (plate.isNotEmpty && plate.every((t) => t.protein != null)) {
      protein.add((sum(guesses.map((g) => g.protein)), sum(plate.map((t) => t.protein))));
    }
  }
  if (gramErrors.isNotEmpty) {
    double mean(Iterable<double> v) => v.reduce((a, b) => a + b) / v.length;
    s.grams = PortionError(
      gramErrors.length,
      mean(gramErrors.map((e) => (e.$1 - e.$2).abs())),
      mean(gramErrors.map((e) => e.$1 - e.$2)),
      mean(gramErrors.map((e) => (e.$1 - e.$2).abs() / math.max(e.$2, 1) * 100)),
    );
  }
  s
    ..kcal = _totals(kcal)
    ..protein = _totals(protein);
  return s;
}

TotalError? _totals(List<(double estimated, double weighed)> meals) {
  if (meals.isEmpty) return null;
  double mean(Iterable<double> v) => v.reduce((a, b) => a + b) / v.length;
  final mae = mean(meals.map((m) => (m.$1 - m.$2).abs()));
  final truthMean = mean(meals.map((m) => m.$2));
  return TotalError(meals.length, mae, mean(meals.map((m) => m.$1 - m.$2)), truthMean == 0 ? 0 : mae / truthMean * 100);
}

const _columns = ['meal', 'category', 'run', 'food', 'matches', 'grams', 'kcal', 'protein'];

List<_Row> _parse(String csv) {
  final lines = csv.split(RegExp(r'\r?\n')).map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
  if (lines.isEmpty) throw const FormatException('empty file');
  final header = lines.first.split(',').map((h) => h.trim().toLowerCase()).toList();
  final missing = _columns.where((c) => !header.contains(c)).toList();
  if (missing.isNotEmpty) throw FormatException('missing columns: ${missing.join(', ')}');
  double? number(String v, int line) {
    if (v.isEmpty) return null;
    final n = double.tryParse(v);
    if (n == null || n < 0 || !n.isFinite) throw FormatException('line $line: "$v" isn’t a number');
    return n;
  }

  return [
    for (final (i, line) in lines.skip(1).indexed)
      () {
        final cells = line.split(',').map((c) => c.trim()).toList();
        String cell(String name) {
          final index = header.indexOf(name);
          return index < cells.length ? cells[index] : '';
        }

        final at = i + 2;
        if (cell('meal').isEmpty || cell('run').isEmpty || cell('food').isEmpty) {
          throw FormatException('line $at: meal, run and food are required');
        }
        return (
          meal: cell('meal'),
          category: cell('category').isEmpty ? 'uncategorised' : cell('category').toLowerCase(),
          run: cell('run'),
          food: cell('food'),
          matches: cell('matches'),
          grams: number(cell('grams'), at),
          kcal: number(cell('kcal'), at),
          protein: number(cell('protein'), at),
        );
      }(),
  ];
}

void main(List<String> args) {
  if (args.length != 1) {
    stderr.writeln('usage: dart run tool/photo_eval.dart meals.csv');
    exitCode = 64;
    return;
  }
  stdout.write(scorePhotoEval(File(args.single).readAsStringSync()).format());
}
