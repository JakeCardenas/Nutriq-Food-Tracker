import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../domain/models/photo_suggestion.dart';
import '../../widgets/buttons.dart';

/// "Might be in your photo" — on-device guesses the person can add (choosing
/// the serving), look up, or dismiss. Nothing here is part of the meal yet.
class PhotoSuggestionsCard extends StatelessWidget {
  const PhotoSuggestionsCard({super.key, required this.suggestions, required this.onAdd, required this.onDismiss});

  final List<PhotoSuggestion> suggestions;
  final ValueChanged<PhotoSuggestion> onAdd;
  final ValueChanged<PhotoSuggestion> onDismiss;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 14, 6, 8),
    decoration: BoxDecoration(
      color: NqColors.card,
      borderRadius: BorderRadius.circular(NqRadius.tile),
      border: Border.all(color: NqColors.hairline),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Might be in your photo', style: NqText.headline),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(right: 10),
          child: Text(
            'Guesses from your iPhone’s general image recognizer — it isn’t a food scanner and can be wrong. Add '
            'only what you ate; you’ll choose each serving.',
            style: NqText.footnote,
          ),
        ),
        const SizedBox(height: 6),
        for (final s in suggestions)
          PhotoSuggestionRow(key: ValueKey(s), suggestion: s, onAdd: () => onAdd(s), onDismiss: () => onDismiss(s)),
      ],
    ),
  );
}

/// One suggestion: Add (opens the serving sheet) when it names one food, Find
/// (searches the food list) when it could be several, or dismiss.
class PhotoSuggestionRow extends StatelessWidget {
  const PhotoSuggestionRow({super.key, required this.suggestion, required this.onAdd, required this.onDismiss});

  final PhotoSuggestion suggestion;
  final VoidCallback onAdd;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final direct = suggestion.food != null;
    return Row(
      children: [
        Expanded(child: Text(suggestion.label, style: NqText.body)),
        QuietButton(
          label: direct ? 'Add' : 'Find',
          icon: direct ? Icons.add_rounded : Icons.search_rounded,
          onPressed: onAdd,
        ),
        IconButton(
          tooltip: 'Not in my meal',
          visualDensity: VisualDensity.compact,
          onPressed: onDismiss,
          icon: const Icon(Icons.close_rounded, size: 18, color: NqColors.textSecondary),
        ),
      ],
    );
  }
}
