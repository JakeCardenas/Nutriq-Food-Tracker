import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/theme.dart';
import '../../services/coach/coach_service.dart';
import '../../widgets/labels.dart';
import '../../widgets/pressable.dart';
import '../shell/home_shell.dart';

/// Chat with the coach. Messages live in memory only.
class CoachScreen extends StatefulWidget {
  const CoachScreen({super.key});

  @override
  State<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends State<CoachScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  int _seenDraft = -1;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send([String? text]) async {
    final message = (text ?? _input.text).trim();
    if (message.isEmpty) return;
    _input.clear();
    final coach = AppScope.of(context).coach;
    final sending = coach.send(message);
    _scrollToEnd();
    await sending;
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final coach = AppScope.of(context).coach;
    return ListenableBuilder(
      listenable: coach,
      builder: (context, _) {
        if (coach.draftVersion != _seenDraft) {
          _seenDraft = coach.draftVersion;
          if (coach.draft.isNotEmpty) {
            _input.text = coach.draft;
            _input.selection = TextSelection.collapsed(offset: _input.text.length);
          }
        }
        final messages = coach.messages;
        // The shell hides its tab bar while the keyboard is up.
        final keyboard = View.of(context).viewInsets.bottom > 0;
        final top = MediaQuery.paddingOf(context).top;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(NqSpace.page, top + 8, 8, 0),
              child: Row(
                children: [
                  const Text('Coach', style: NqText.largeTitle),
                  if (coach.service.isDemo) ...[const SizedBox(width: 10), const DemoBadge(label: 'Demo coach')],
                  const Spacer(),
                  if (messages.isNotEmpty)
                    IconButton(
                      tooltip: 'Clear conversation',
                      icon: const Icon(Icons.refresh_rounded, color: NqColors.ink),
                      onPressed: coach.clear,
                    ),
                ],
              ),
            ),
            if (coach.service.isDemo)
              Padding(
                padding: const EdgeInsets.fromLTRB(NqSpace.page, 4, NqSpace.page, NqSpace.sm),
                child: Text(
                  'Scripted replies that use your log — not live AI, and not medical advice. Chats aren’t saved.',
                  style: NqText.caption,
                ),
              ),
            Expanded(
              child: messages.isEmpty
                  ? _EmptyCoach(onPrompt: _send)
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(NqSpace.page, NqSpace.sm, NqSpace.page, NqSpace.lg),
                      itemCount: messages.length + (coach.isReplying ? 1 : 0),
                      itemBuilder: (context, i) =>
                          i == messages.length ? const _Typing() : _Bubble(message: messages[i]),
                    ),
            ),
            if (messages.isNotEmpty)
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: NqSpace.page),
                  itemCount: CoachPrompts.all.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, i) => _PromptChip(
                    text: CoachPrompts.all[i],
                    compact: true,
                    onTap: coach.isReplying ? null : () => _send(CoachPrompts.all[i]),
                  ),
                ),
              ),
            _Composer(
              controller: _input,
              enabled: !coach.isReplying,
              onSend: () => _send(),
              bottomPadding: keyboard ? 0 : HomeShell.bottomInset(context) - 8,
            ),
          ],
        );
      },
    );
  }
}

class _EmptyCoach extends StatelessWidget {
  const _EmptyCoach({required this.onPrompt});

  final ValueChanged<String> onPrompt;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(NqSpace.page, NqSpace.xl, NqSpace.page, NqSpace.lg),
    children: [
      Container(
        width: 48,
        height: 48,
        alignment: Alignment.centerLeft,
        child: Container(
          width: 48,
          height: 48,
          decoration: const BoxDecoration(color: NqColors.card, shape: BoxShape.circle, boxShadow: NqShadow.card),
          child: const Icon(Icons.auto_awesome_outlined, color: NqColors.ink),
        ),
      ),
      const SizedBox(height: NqSpace.lg),
      const Text('Small steps, steady progress.', style: NqText.title),
      const SizedBox(height: NqSpace.sm),
      Text(
        'Ask about your protein, a meal idea for your goal, your week, or staying consistent. '
        'Answers use your profile and the meals you’ve logged.',
        style: NqText.callout,
      ),
      const SizedBox(height: NqSpace.xl),
      for (final p in CoachPrompts.all)
        Padding(
          padding: const EdgeInsets.only(bottom: NqSpace.sm),
          child: _PromptChip(text: p, onTap: () => onPrompt(p)),
        ),
    ],
  );
}

class _PromptChip extends StatelessWidget {
  const _PromptChip({required this.text, required this.onTap, this.compact = false});

  final String text;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    child: Container(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: compact ? 10 : 14),
      decoration: BoxDecoration(
        color: NqColors.card,
        borderRadius: BorderRadius.circular(compact ? 22 : NqRadius.tile),
        border: Border.all(color: NqColors.hairline),
      ),
      child: Row(
        mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
        children: [
          if (!compact) ...[
            const Icon(Icons.north_east_rounded, size: 16, color: NqColors.ink),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Text(text, style: compact ? NqText.footnote.copyWith(color: NqColors.textPrimary) : NqText.subhead),
          ),
        ],
      ),
    ),
  );
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final user = message.role == ChatRole.user;
    final careful =
        message.kind != null && message.kind != CoachReplyKind.answer && message.kind != CoachReplyKind.fallback;
    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.82),
        child: Padding(
          padding: const EdgeInsets.only(bottom: NqSpace.md),
          child: Column(
            crossAxisAlignment: user ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: user ? NqColors.inkSoft : NqColors.card,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(user ? 18 : 6),
                    bottomRight: Radius.circular(user ? 6 : 18),
                  ),
                  border: user
                      ? null
                      : Border.all(color: careful ? NqColors.inRange.withValues(alpha: 0.45) : NqColors.hairline),
                ),
                child: Text(
                  message.text,
                  style: NqText.body.copyWith(fontSize: 16, color: user ? NqColors.onInk : NqColors.ink),
                ),
              ),
              if (!user && message.isDemo)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 6),
                  child: Text('Demo coach · scripted', style: NqText.caption),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Typing extends StatelessWidget {
  const _Typing();

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Semantics(
      label: 'Coach is replying',
      child: Container(
        margin: const EdgeInsets.only(bottom: NqSpace.md),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: NqColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: NqColors.hairline),
        ),
        child: const SizedBox(
          width: 28,
          height: 8,
          child: LinearProgressIndicator(
            backgroundColor: NqColors.track,
            color: NqColors.ink,
            borderRadius: BorderRadius.all(Radius.circular(4)),
          ),
        ),
      ),
    ),
  );
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.enabled, required this.onSend, required this.bottomPadding});

  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onSend;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(NqSpace.page, NqSpace.sm, 12, NqSpace.sm + bottomPadding),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            minLines: 1,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => onSend(),
            decoration: InputDecoration(
              hintText: 'Ask your coach…',
              filled: true,
              fillColor: NqColors.card,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: const BorderSide(color: NqColors.hairline, width: 1.2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: const BorderSide(color: NqColors.ink, width: 1.2),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final canSend = enabled && controller.text.trim().isNotEmpty;
            return IconButton.filled(
              tooltip: 'Send',
              onPressed: canSend ? onSend : null,
              style: IconButton.styleFrom(
                backgroundColor: NqColors.inkSoft,
                disabledBackgroundColor: NqColors.fillPressed,
                minimumSize: const Size(48, 48),
              ),
              icon: Icon(Icons.arrow_upward_rounded, color: canSend ? NqColors.onInk : NqColors.textTertiary),
            );
          },
        ),
      ],
    ),
  );
}
