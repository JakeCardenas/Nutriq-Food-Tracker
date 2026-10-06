import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/theme.dart';
import '../../data/local_data_importer.dart';
import '../../services/auth/auth_service.dart';
import '../../state/session_controller.dart';
import '../../widgets/adaptive.dart';
import '../../widgets/buttons.dart';
import '../../widgets/sheet.dart';

/// Shows session-level prompts: the explicit import offer after sign-in and
/// the "choose a new password" step after a reset link.
class AccountPrompts extends StatefulWidget {
  const AccountPrompts({super.key, required this.child});
  final Widget child;

  @override
  State<AccountPrompts> createState() => _AccountPromptsState();
}

class _AccountPromptsState extends State<AccountPrompts> {
  ImportSummary? _shownOffer;
  bool _shownRecovery = false;
  SessionController? _sessions;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final sessions = AppScope.of(context).sessions;
    if (!identical(sessions, _sessions)) {
      _sessions?.removeListener(_check);
      _sessions = sessions..addListener(_check);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    _sessions?.removeListener(_check);
    super.dispose();
  }

  void _check() {
    final sessions = _sessions;
    if (!mounted || sessions == null) return;
    final offer = sessions.importOffer;
    if (offer != null && !identical(offer, _shownOffer)) {
      _shownOffer = offer;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) showImportSheet(context, offer);
      });
    }
    if (sessions.notice != null) {
      final notice = sessions.takeNotice()!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) showToast(context, notice);
      });
    }
    if (sessions.passwordRecovery && !_shownRecovery) {
      _shownRecovery = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showNewPassword(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// "Bring this phone's data into your account?" — nothing uploads until the person agrees.
Future<void> showImportSheet(BuildContext context, ImportSummary offer) {
  final sessions = AppScope.of(context).sessions;
  var busy = false;
  final lines = [
    if (offer.meals > 0) '${offer.meals} ${offer.meals == 1 ? 'meal' : 'meals'}',
    if (offer.hasProfile) 'Your profile and goals',
    if (offer.savedFoods > 0) '${offer.savedFoods} saved ${offer.savedFoods == 1 ? 'food' : 'foods'}',
    if (offer.feedback > 0) '${offer.feedback} scan ${offer.feedback == 1 ? 'rating' : 'ratings'}',
  ];
  return showNqSheetWith<void>(
    context,
    dismissible: false,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setState) => SheetBody(
        title: 'Bring this phone’s data into your account?',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('You used Nutriq on this phone before signing in. Import:', style: NqText.callout),
            const SizedBox(height: NqSpace.md),
            for (final l in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, size: 18, color: NqColors.inRange),
                    const SizedBox(width: 8),
                    Text(l, style: NqText.body),
                  ],
                ),
              ),
            const SizedBox(height: NqSpace.md),
            Text(
              'They’ll be copied into your account and synced. Meal photos stay on this phone and are never uploaded. '
              'The local copy isn’t deleted.',
              style: NqText.footnote,
            ),
            const SizedBox(height: NqSpace.xl),
            PrimaryButton(
              label: 'Import to my account',
              busy: busy,
              onPressed: () async {
                setState(() => busy = true);
                try {
                  final r = await sessions.acceptImport();
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                  if (context.mounted) {
                    showToast(context, 'Imported ${r.meals} ${r.meals == 1 ? 'meal' : 'meals'} — syncing now');
                  }
                } catch (e) {
                  setState(() => busy = false);
                  if (sheetContext.mounted) showToast(sheetContext, 'Import failed: $e. Nothing was lost.');
                }
              },
            ),
            Center(
              child: QuietButton(
                label: 'Not now',
                color: NqColors.textSecondary,
                onPressed: busy
                    ? null
                    : () async {
                        await sessions.declineImport();
                        if (sheetContext.mounted) Navigator.pop(sheetContext);
                      },
              ),
            ),
            Text('You can import later from Settings → Account.', style: NqText.caption, textAlign: TextAlign.center),
          ],
        ),
      ),
    ),
  );
}

Future<void> _showNewPassword(BuildContext context) {
  final scope = AppScope.of(context);
  final form = GlobalKey<FormState>();
  final password = TextEditingController();
  final confirm = TextEditingController();
  var busy = false;
  String? error;
  return showNqSheet<void>(
    context,
    title: 'Choose a new password',
    child: StatefulBuilder(
      builder: (sheetContext, setState) => Form(
        key: form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: password,
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              decoration: const InputDecoration(labelText: 'New password', helperText: 'At least 8 characters'),
              validator: (v) => (v ?? '').length < 8 ? 'Use at least 8 characters' : null,
            ),
            const SizedBox(height: NqSpace.md),
            TextFormField(
              controller: confirm,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Confirm password'),
              validator: (v) => v != password.text ? 'Passwords don’t match' : null,
            ),
            if (error != null) ...[
              const SizedBox(height: NqSpace.md),
              Text(error!, style: NqText.footnote.copyWith(color: NqColors.danger)),
            ],
            const SizedBox(height: NqSpace.xl),
            PrimaryButton(
              label: 'Save password',
              busy: busy,
              onPressed: () async {
                if (!(form.currentState?.validate() ?? false)) return;
                setState(() {
                  busy = true;
                  error = null;
                });
                try {
                  await scope.auth.updatePassword(password.text);
                  scope.sessions.clearPasswordRecovery();
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                  if (context.mounted) showToast(context, 'Password updated');
                } on AuthFailure catch (e) {
                  setState(() {
                    busy = false;
                    error = e.message;
                  });
                }
              },
            ),
          ],
        ),
      ),
    ),
  );
}
