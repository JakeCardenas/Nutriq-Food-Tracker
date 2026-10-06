import 'package:flutter/material.dart';

import '../app/theme.dart';
import 'buttons.dart';
import 'spring_sheet.dart';

export 'spring_sheet.dart' show NqSheetRoute, NqSheetScope, NqMotion;

/// Nutriq bottom sheet: rounded white sheet with a grab handle and title. It
/// follows the finger and settles with springs (see [NqSheetRoute]).
Future<T?> showNqSheet<T>(
  BuildContext context, {
  required String title,
  required Widget child,
  Widget? trailing,
  bool dismissible = true,
}) => showNqSheetWith<T>(
  context,
  dismissible: dismissible,
  builder: (context) => SheetBody(title: title, trailing: trailing, child: child),
);

/// Shows any sheet body in an [NqSheetRoute]. [dismissible] false means it
/// must be answered: no swipe or tap outside closes it.
Future<T?> showNqSheetWith<T>(BuildContext context, {required WidgetBuilder builder, bool dismissible = true}) =>
    Navigator.of(context).push(
      NqSheetRoute<T>(
        builder: builder,
        dismissible: dismissible,
        reduceMotion: MediaQuery.maybeDisableAnimationsOf(context) ?? false,
        barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      ),
    );

class SheetBody extends StatelessWidget {
  const SheetBody({super.key, required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        physics: NqSheetScope.physicsOf(context),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(NqSpace.page, 0, NqSpace.page, NqSpace.xxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: NqText.title)),
                ?trailing,
              ],
            ),
            const SizedBox(height: NqSpace.lg),
            child,
          ],
        ),
      ),
    );
  }
}

/// A sheet with one text field. Pops with the trimmed text, or null when dismissed.
/// The field's controller lives as long as the sheet (it may still be drawn
/// while the sheet animates closed).
Future<String?> showTextEntrySheet(
  BuildContext context, {
  required String title,
  String initial = '',
  String? hint,
  int maxLength = 60,
  int maxLines = 1,
  String buttonLabel = 'Save',
}) => showNqSheet<String>(
  context,
  title: title,
  child: _TextEntry(initial: initial, hint: hint, maxLength: maxLength, maxLines: maxLines, buttonLabel: buttonLabel),
);

class _TextEntry extends StatefulWidget {
  const _TextEntry({
    required this.initial,
    required this.hint,
    required this.maxLength,
    required this.maxLines,
    required this.buttonLabel,
  });

  final String initial;
  final String? hint;
  final int maxLength;
  final int maxLines;
  final String buttonLabel;

  @override
  State<_TextEntry> createState() => _TextEntryState();
}

class _TextEntryState extends State<_TextEntry> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _done() => Navigator.pop(context, _controller.text.trim());

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextField(
        controller: _controller,
        autofocus: true,
        maxLength: widget.maxLength,
        maxLines: widget.maxLines,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(hintText: widget.hint),
        onSubmitted: widget.maxLines == 1 ? (_) => _done() : null,
      ),
      const SizedBox(height: NqSpace.md),
      PrimaryButton(label: widget.buttonLabel, onPressed: _done),
    ],
  );
}
