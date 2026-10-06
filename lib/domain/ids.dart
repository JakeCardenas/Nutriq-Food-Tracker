import 'dart:math';

final _random = Random();
var _counter = 0;

/// Short, unique-enough local id (no network, no uuid dependency).
String newId() {
  _counter = (_counter + 1) % 0xFFFF;
  final time = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final rand = _random.nextInt(1 << 32).toRadixString(36);
  return '$time-${_counter.toRadixString(36)}-$rand';
}
