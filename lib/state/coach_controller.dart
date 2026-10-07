import 'package:flutter/foundation.dart';

import '../data/local_store.dart';
import '../services/coach/ai_coach_service.dart';
import '../services/coach/coach_backend.dart';
import '../services/coach/coach_service.dart';
import 'meal_log_controller.dart';
import 'profile_controller.dart';

enum AiCoachChoice { undecided, on, off }

/// Chat state for the coach. Conversations live in memory only and are
/// cleared when the app closes.
///
/// For a signed-in account, [ai] reaches the AI coach. It is only used after
/// the person turns it on; the choice is stored per account on this phone.
class CoachController extends ChangeNotifier {
  CoachController(this._demo, this._context, {CoachBackend? ai, this._store})
    : _ai = ai == null ? null : AiCoachService(backend: ai, fallback: _demo);

  final CoachService _demo;
  final AiCoachService? _ai;
  final LocalStore? _store;
  final CoachContext Function() _context;

  static const _aiKey = 'coach_ai';

  final List<ChatMessage> _messages = [];
  AiCoachChoice _aiChoice = AiCoachChoice.undecided;
  bool _isReplying = false;
  String? _streaming;
  String _draft = '';
  int _draftVersion = 0;
  int _conversation = 0;
  bool _disposed = false;

  /// The coach answering right now.
  CoachService get service => aiEnabled ? _ai! : _demo;

  /// True for a signed-in account in a build with accounts set up.
  bool get aiAvailable => _ai != null;
  bool get aiEnabled => _ai != null && _aiChoice == AiCoachChoice.on;
  bool get needsAiChoice => _ai != null && _aiChoice == AiCoachChoice.undecided;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isReplying => _isReplying;

  /// The AI's reply so far while it streams in.
  String? get streamingText => _streaming;
  String get draft => _draft;

  /// Bumps whenever [prefill] runs so the composer can pick the text up.
  int get draftVersion => _draftVersion;

  CoachContext currentContext() => _context();

  Future<void> load() async {
    _aiChoice = switch (await _store?.readMeta(_aiKey)) {
      'on' => AiCoachChoice.on,
      'off' => AiCoachChoice.off,
      _ => AiCoachChoice.undecided,
    };
    _notify();
  }

  Future<void> setAiEnabled(bool enabled) async {
    _aiChoice = enabled ? AiCoachChoice.on : AiCoachChoice.off;
    _notify();
    await _store?.writeMeta(_aiKey, enabled ? 'on' : 'off');
  }

  void prefill(String text) {
    _draft = text;
    _draftVersion++;
    _notify();
  }

  Future<void> send(String text) async {
    final message = text.trim();
    if (message.isEmpty || _isReplying) return;
    final conversation = _conversation;
    final coach = service;
    _messages.add(ChatMessage(role: ChatRole.user, text: message));
    _draft = '';
    _isReplying = true;
    _notify();
    ChatMessage reply;
    try {
      final r = await coach.reply(
        message: message,
        context: _context(),
        history: List.unmodifiable(_messages),
        onPartial: (soFar) {
          if (conversation != _conversation) return;
          _streaming = soFar;
          _notify();
        },
      );
      reply = ChatMessage(role: ChatRole.coach, text: r.text, isDemo: r.isDemo, kind: r.kind, notice: r.notice);
    } catch (_) {
      reply = ChatMessage(
        role: ChatRole.coach,
        text: 'Sorry — I couldn’t reply just now. Please try again.',
        isDemo: coach.isDemo,
      );
    }
    if (conversation == _conversation) _messages.add(reply);
    _streaming = null;
    _isReplying = false;
    _notify();
  }

  void clear() {
    _conversation++;
    _messages.clear();
    _streaming = null;
    _isReplying = false;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Builds the coach's view of the person's data from the controllers.
  static CoachContext Function() contextFrom(ProfileController profile, MealLogController log) => () {
    final now = DateTime.now();
    final today = log.today(now);
    final meals = log.mealsForDay(today);
    return CoachContext(
      profile: profile.profile,
      today: log.totalsForDay(today),
      todayMealCount: meals.length,
      recentDays: log.summariesEnding(today),
      now: now,
      todayMeals: meals,
      savedFoods: [for (final s in log.savedFoods) s.item],
      units: profile.settings.units,
    );
  };
}
