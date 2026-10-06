import 'package:flutter_test/flutter_test.dart';
import 'package:nutriq/widgets/spring_sheet.dart';

void main() {
  test('the spring curve starts at 0, lands exactly on 1 and never overshoots', () {
    const curve = NqSpringCurve();
    expect(curve.transform(0), 0);
    expect(curve.transform(1), 1);
    var previous = 0.0;
    for (var i = 1; i <= 100; i++) {
      final v = curve.transform(i / 100);
      expect(v, greaterThanOrEqualTo(previous));
      expect(v, lessThanOrEqualTo(1.0));
      previous = v;
    }
  });

  test('it moves fast first and eases in to rest, like a released spring', () {
    const curve = NqSpringCurve();
    expect(curve.transform(0.25), greaterThan(0.5));
  });

  test('momentum projection and rubber-banding follow the iOS formulas', () {
    expect(NqMotion.project(1000), closeTo(499, 0.5));
    expect(NqMotion.rubberBand(0, 600), 0);
    expect(NqMotion.rubberBand(200, 600), lessThan(200));
    expect(NqMotion.rubberBand(-200, 600), greaterThan(-200));
  });
}
