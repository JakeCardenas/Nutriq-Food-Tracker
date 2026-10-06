import 'package:flutter/foundation.dart';

import '../services/coach/coach_service.dart';
import 'meal_log_controller.dart';
import 'profile_controller.dart';

/// Chat state for the coach. Conversations live in memory only and are
/// cleared when the app closes.
class CoachController extends ChangeNotifier {
  CoachController(this.service, this._context);

  final CoachService service;
  final CoachContext Function() _context;

  final List<ChatMessage> _messages = [];
  bool _isReplying = false;
  String _draft = '';
  int _draftVersion = 0;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isReplying => _isReplying;
  String get draft => _draft;

  /// Bumps whenever [prefill] runs so the composer can pick the text up.
  int get draftVersion => _draftVersion;

  CoachContext currentContext() => _context();

  void prefill(String text) {
    _draft = text;
    _draftVersion++;
    notifyListeners();
  }

  Future<void> send(String text) async {
    final message = text.trim();
    if (message.isEmpty || _isReplying) return;
    _messages.add(ChatMessage(role: ChatRole.user, text: message));
    _draft = '';
    _isReplying = true;
    notifyListeners();
    try {
      final reply = await service.reply(message: message, context: _context(), history: List.unmodifiable(_messages));
      _messages.add(ChatMessage(role: ChatRole.coach, text: reply.text, isDemo: reply.isDemo, kind: reply.kind));
    } catch (_) {
      _messages.add(
        ChatMessage(
          role: ChatRole.coach,
          text: 'Sorry — I couldn’t reply just now. Please try again.',
          isDemo: service.isDemo,
        ),
      );
    } finally {
      _isReplying = false;
      notifyListeners();
    }
  }

  void clear() {
    _messages.clear();
    notifyListeners();
  }

  /// Builds the coach's view of the person's data from the controllers.
  static CoachContext Function() contextFrom(ProfileController profile, MealLogController log) => () {
    final now = DateTime.now();
    final today = log.today(now);
    return CoachContext(
      profile: profile.profile,
      today: log.totalsForDay(today),
      todayMealCount: log.mealsForDay(today).length,
      recentDays: log.summariesEnding(today),
      now: now,
    );
  };
}
