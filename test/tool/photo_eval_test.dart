import 'package:flutter_test/flutter_test.dart';

import '../../tool/photo_eval.dart';

const _csv = '''
meal,category,run,food,matches,grams,kcal,protein
m1,filipino,truth,White rice,,200,260,5.4
m1,filipino,truth,Fried egg,,50,98,6.8
m1,filipino,flash-lite,Kanin,White rice,250,325,6.75
m1,filipino,flash-lite,Hotdog,,40,116,4
m2,simple,truth,Banana,,100,89,1.1
m2,simple,flash-lite,Banana,Banana,120,107,1.3
m2,simple,flash-lite,Peanut butter,,,,
m3,mixed,truth,Chicken curry,,300,,
m3,mixed,flash-lite,Chicken curry,Chicken curry,250,400,30
''';

void main() {
  final report = scorePhotoEval(_csv);
  RunScore score(String run, [String category = 'all']) =>
      report.scores.singleWhere((s) => s.run == run && s.category == category);

  test('food-item precision and recall, with the missed foods and false suggestions listed', () {
    final all = score('flash-lite');
    expect(all.meals, 3);
    expect(all.predicted, 5);
    expect(all.precision, closeTo(3 / 5, 1e-9));
    expect(all.recall, closeTo(3 / 4, 1e-9));
    expect(all.missed, ['m1: Fried egg']);
    expect(all.falseSuggestions, ['m1: Hotdog', 'm2: Peanut butter']);
    expect(all.uncounted, 1, reason: 'Peanut butter had no nutrition in the app');
  });

  test('portion error in grams for matched foods: absolute, signed and relative', () {
    final grams = score('flash-lite').grams!;
    // rice +50 g (25 %), banana +20 g (20 %), curry −50 g (16.7 %)
    expect(grams.count, 3);
    expect(grams.meanAbsolute, closeTo(40, 1e-9));
    expect(grams.meanSigned, closeTo(20 / 3, 1e-9));
    expect(grams.meanAbsolutePercent, closeTo((25 + 20 + 50 / 3) / 3, 1e-9));
  });

  test('meal calories and protein: absolute error, bias and % of the mean, skipping meals without a reference', () {
    final kcal = score('flash-lite').kcal!;
    // m1: 441 vs 358 (+83), m2: 107 vs 89 (+18); m3 has no reference calories
    expect(kcal.meals, 2);
    expect(kcal.meanAbsolute, closeTo(50.5, 1e-9));
    expect(kcal.meanSigned, closeTo(50.5, 1e-9));
    expect(kcal.percentOfMean, closeTo(50.5 / 223.5 * 100, 1e-9));
    final protein = score('flash-lite').protein!;
    // m1: 10.75 vs 12.2 (−1.45), m2: 1.3 vs 1.1 (+0.2)
    expect(protein.meanAbsolute, closeTo(0.825, 1e-9));
    expect(protein.meanSigned, closeTo(-0.625, 1e-9));
  });

  test('results are also split by category', () {
    expect(score('flash-lite', 'filipino').recall, closeTo(1 / 2, 1e-9));
    expect(score('flash-lite', 'simple').recall, 1);
    expect(score('flash-lite', 'simple').precision, closeTo(1 / 2, 1e-9));
    expect(score('flash-lite', 'mixed').kcal, isNull, reason: 'no reference calories in that category');
  });

  test('two models on the same photos are scored side by side', () {
    final both = scorePhotoEval('''
$_csv
m1,filipino,3.8-flash,White rice,White rice,210,273,5.67
m1,filipino,3.8-flash,Egg,Fried egg,45,88,6.1
''');
    expect(both.scores.where((s) => s.category == 'all').map((s) => s.run), ['3.8-flash', 'flash-lite']);
    final candidate = both.scores.singleWhere((s) => s.run == '3.8-flash' && s.category == 'all');
    expect(candidate.meals, 1, reason: 'only meals the run actually scanned');
    expect(candidate.recall, 1);
    expect(both.format(), contains('3.8-flash'));
  });

  test('a suggestion matched to a food that isn’t on the plate is a labelling error', () {
    expect(
      () => scorePhotoEval(
        'meal,category,run,food,matches,grams,kcal,protein\nm1,simple,truth,Rice,,100,130,2.7\n'
        'm1,simple,a,Kanin,Brown rice,100,130,2.7\n',
      ),
      throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('m1'))),
    );
    expect(() => scorePhotoEval('meal,food\nm1,Rice\n'), throwsFormatException);
  });
}
