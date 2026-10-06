import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../app/theme.dart';

/// Native-looking confirm dialog. Returns true when confirmed.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = true,
}) async {
  final result = await showAdaptiveDialog<bool>(
    context: context,
    builder: (context) => AlertDialog.adaptive(
      title: Text(title),
      content: Text(message),
      actions: [
        _action(context, 'Cancel', () => Navigator.pop(context, false)),
        _action(context, confirmLabel, () => Navigator.pop(context, true), destructive: destructive),
      ],
    ),
  );
  return result ?? false;
}

Future<void> showInfoDialog(BuildContext context, {required String title, required String message}) =>
    showAdaptiveDialog<void>(
      context: context,
      builder: (context) => AlertDialog.adaptive(
        title: Text(title),
        content: Text(message),
        actions: [_action(context, 'OK', () => Navigator.pop(context))],
      ),
    );

Widget _action(BuildContext context, String label, VoidCallback onPressed, {bool destructive = false}) {
  if (isCupertino(context)) {
    return CupertinoDialogAction(
      onPressed: onPressed,
      isDestructiveAction: destructive,
      isDefaultAction: !destructive && label != 'Cancel',
      child: Text(label),
    );
  }
  return TextButton(
    onPressed: onPressed,
    child: Text(label, style: TextStyle(color: destructive ? NqColors.coral : NqColors.sage)),
  );
}

/// Picks a date and time, never in the future beyond [latest].
Future<DateTime?> pickDateTime(BuildContext context, DateTime initial, {DateTime? latest}) async {
  final max = latest ?? DateTime.now().add(const Duration(minutes: 1));
  final start = initial.isAfter(max) ? max : initial;
  if (isCupertino(context)) {
    var value = start;
    final ok = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (context) => Container(
        height: 320,
        color: NqColors.surface,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    child: const Text('Cancel'),
                    onPressed: () => Navigator.pop(context, false),
                  ),
                  CupertinoButton(
                    child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w600)),
                    onPressed: () => Navigator.pop(context, true),
                  ),
                ],
              ),
              Expanded(
                child: CupertinoTheme(
                  data: const CupertinoThemeData(brightness: Brightness.dark),
                  child: CupertinoDatePicker(
                    initialDateTime: start,
                    maximumDate: max,
                    minimumDate: DateTime(2020),
                    onDateTimeChanged: (v) => value = v,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return ok == true ? value : null;
  }

  final date = await showDatePicker(
    context: context,
    initialDate: start,
    firstDate: DateTime(2020),
    lastDate: max,
  );
  if (date == null || !context.mounted) return null;
  final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(start));
  if (time == null) return null;
  final picked = DateTime(date.year, date.month, date.day, time.hour, time.minute);
  return picked.isAfter(max) ? max : picked;
}

void showToast(BuildContext context, String message, {SnackBarAction? action}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), action: action, duration: const Duration(seconds: 3)));
}
