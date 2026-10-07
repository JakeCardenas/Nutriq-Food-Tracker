import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../domain/meal_description.dart';
import '../../widgets/buttons.dart';

/// "What did you eat?" — type the meal like you'd say it, and Nutriq's food
/// list turns it into foods with typical values the person can adjust.
class DescribeMealCard extends StatefulWidget {
  const DescribeMealCard({super.key, required this.title, required this.onParsed, this.autofocus = false});

  final String title;
  final ValueChanged<MealParse> onParsed;
  final bool autofocus;

  @override
  State<DescribeMealCard> createState() => _DescribeMealCardState();
}

class _DescribeMealCardState extends State<DescribeMealCard> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _submit() {
    if (_text.text.trim().isEmpty) return;
    final result = MealDescription.parse(_text.text);
    if (result.items.isNotEmpty) _text.clear();
    widget.onParsed(result);
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: NqColors.card,
      borderRadius: BorderRadius.circular(NqRadius.tile),
      border: Border.all(color: NqColors.hairline),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.title, style: NqText.headline),
        const SizedBox(height: 4),
        Text(
          'Type it like you’d say it. Nutriq fills in typical values from its food list — estimates you can adjust.',
          style: NqText.footnote,
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('describe-field'),
          controller: _text,
          autofocus: widget.autofocus,
          minLines: 2,
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          decoration: const InputDecoration(hintText: 'e.g. Century Tuna and 2 cups of rice'),
        ),
        const SizedBox(height: 12),
        ListenableBuilder(
          listenable: _text,
          builder: (context, _) => PrimaryButton(
            label: 'Add foods',
            icon: Icons.auto_fix_high_rounded,
            height: 48,
            onPressed: _text.text.trim().isEmpty ? null : _submit,
          ),
        ),
      ],
    ),
  );
}
