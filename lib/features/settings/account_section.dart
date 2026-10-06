import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/format.dart';
import '../../app/theme.dart';
import '../../data/sync_models.dart';
import '../../services/auth/auth_service.dart';
import '../../state/sync_controller.dart';
import '../../widgets/adaptive.dart';
import '../../widgets/buttons.dart';
import '../../widgets/surfaces.dart';
import '../account/account_prompts.dart';
import '../account/auth_screen.dart';

/// The account card at the top of Settings: sign in / create an account in
/// local-only mode; sync status, conflicts, import and linking when signed in.
class AccountSection extends StatelessWidget {
  const AccountSection({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final session = scope.session;
    if (!session.isAccount) return _SignedOut(configured: scope.auth.isConfigured);
    return _SignedIn(user: scope.auth.currentUser ?? session.user!, sync: scope.sync!);
  }
}

class _SignedOut extends StatelessWidget {
  const _SignedOut({required this.configured});
  final bool configured;

  @override
  Widget build(BuildContext context) {
    if (!configured) {
      return const NqCard(
        child: Row(
          children: [
            _Avatar(letter: null),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('On this phone only', style: NqText.headline),
                  SizedBox(height: 2),
                  Text(
                    'Accounts and sync aren’t set up in this build, so everything stays on this phone.',
                    style: NqText.footnote,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return NqCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              _Avatar(letter: null),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Back up and sync', style: NqText.headline),
                    SizedBox(height: 2),
                    Text(
                      'A free account keeps your meals and goals in sync across devices. Meal photos stay on '
                      'this phone.',
                      style: NqText.footnote,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: NqSpace.lg),
          Row(
            children: [
              Expanded(
                child: PrimaryButton(
                  label: 'Create account',
                  height: 48,
                  onPressed: () => AuthScreen.open(context, signUp: true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SecondaryButton(label: 'Sign in', height: 48, onPressed: () => AuthScreen.open(context)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SignedIn extends StatelessWidget {
  const _SignedIn({required this.user, required this.sync});

  final AuthUser user;
  final SyncController sync;

  static String _providerLabel(String p) => switch (p) {
    'apple' => 'Apple',
    'google' => 'Google',
    'email' => 'Email',
    _ => p,
  };

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final auth = scope.auth;
    return ListenableBuilder(
      listenable: sync,
      builder: (context, _) {
        final name = user.displayName?.trim();
        final title = (name?.isNotEmpty ?? false) ? name! : (user.email ?? 'Signed in');
        final status = switch (sync.state) {
          SyncState.syncing => 'Syncing…',
          SyncState.offline => 'Offline — changes are saved on this phone',
          SyncState.error => 'Sync needs attention',
          SyncState.synced || SyncState.idle =>
            sync.pending > 0
                ? '${sync.pending} ${sync.pending == 1 ? 'change' : 'changes'} waiting to sync'
                : (sync.lastSyncedAt == null ? 'Ready to sync' : 'Synced ${relativeTime(sync.lastSyncedAt!)}'),
        };
        final canLinkGoogle = auth.supportsGoogle && !user.providers.contains('google');
        final canLinkApple = auth.supportsApple && !user.providers.contains('apple');
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            NqCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      _Avatar(letter: title.characters.first.toUpperCase()),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: NqText.headline, maxLines: 1, overflow: TextOverflow.ellipsis),
                            if (name != null && name.isNotEmpty && user.email != null)
                              Text(user.email!, style: NqText.footnote, maxLines: 1, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 2),
                            Text(
                              'Sign in with ${user.providers.map(_providerLabel).join(' · ')}',
                              style: NqText.caption,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: NqSpace.md),
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
                    decoration: BoxDecoration(color: NqColors.fill, borderRadius: BorderRadius.circular(NqRadius.chip)),
                    child: Row(
                      children: [
                        Icon(
                          switch (sync.state) {
                            SyncState.offline => Icons.cloud_off_rounded,
                            SyncState.error => Icons.error_outline_rounded,
                            SyncState.syncing => Icons.sync_rounded,
                            _ => sync.pending > 0 ? Icons.cloud_upload_outlined : Icons.cloud_done_outlined,
                          },
                          size: 20,
                          color: sync.state == SyncState.error ? NqColors.danger : NqColors.ink,
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text(status, style: NqText.subhead)),
                        QuietButton(
                          label: 'Sync now',
                          onPressed: sync.state == SyncState.syncing ? null : sync.syncNow,
                        ),
                      ],
                    ),
                  ),
                  if (sync.message != null) ...[
                    const SizedBox(height: NqSpace.sm),
                    Text(sync.message!, style: NqText.footnote),
                  ],
                ],
              ),
            ),
            if (sync.conflicts.isNotEmpty) ...[const SizedBox(height: NqSpace.md), _Conflicts(sync: sync)],
            NqGroup(
              header: 'Account',
              children: [
                NqRow(
                  icon: Icons.download_rounded,
                  title: 'Import data from this phone',
                  subtitle: 'Meals and goals you logged before signing in',
                  onTap: () => _offerImport(context),
                ),
                if (canLinkApple)
                  NqRow(
                    icon: Icons.apple,
                    title: 'Link Sign in with Apple',
                    onTap: () => _link(context, 'apple', auth.linkApple),
                  ),
                if (canLinkGoogle)
                  NqRow(
                    icon: Icons.g_mobiledata_rounded,
                    title: 'Link Google',
                    onTap: () => _link(context, 'google', auth.linkGoogle),
                  ),
                NqRow(icon: Icons.logout_rounded, title: 'Sign out', onTap: () => _signOut(context)),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _offerImport(BuildContext context) async {
    final sessions = AppScope.of(context).sessions;
    final summary = await sessions.localImportSummary();
    if (!context.mounted) return;
    if (summary == null) {
      showToast(context, 'There’s nothing on this phone left to import.');
      return;
    }
    await showImportSheet(context, summary);
  }

  Future<void> _link(BuildContext context, String provider, Future<bool> Function() link) async {
    final sessions = AppScope.of(context).sessions;
    sessions.markLinkedInApp(provider);
    try {
      final linked = await link();
      if (context.mounted && linked) showToast(context, '${_providerLabel(provider)} is now linked to this account');
    } on AuthFailure catch (e) {
      if (context.mounted) showToast(context, e.message);
    }
  }

  Future<void> _signOut(BuildContext context) async {
    final sessions = AppScope.of(context).sessions;
    final pending = await sessions.pendingChanges();
    if (!context.mounted) return;
    final ok = await confirmAction(
      context,
      title: 'Sign out?',
      message: pending > 0
          ? '$pending ${pending == 1 ? 'change hasn’t' : 'changes haven’t'} synced yet. They stay on this phone and '
                'will sync the next time you sign in here.'
          : 'Your data stays in your account. This phone switches back to its own local data.',
      confirmLabel: 'Sign out',
      destructive: false,
    );
    if (ok) await sessions.signOut();
  }
}

class _Conflicts extends StatelessWidget {
  const _Conflicts({required this.sync});
  final SyncController sync;

  @override
  Widget build(BuildContext context) => NqCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Replaced by a newer version', style: NqText.headline),
        const SizedBox(height: 4),
        Text(
          'These edits from this phone lost to newer changes made elsewhere. Restore one to use your version instead.',
          style: NqText.footnote,
        ),
        for (final SyncConflict c in sync.conflicts) ...[
          const Divider(height: 24),
          Text(c.summary, style: NqText.subhead),
          Text(dateTimeLabel(c.createdAt), style: NqText.caption),
          Row(
            children: [
              QuietButton(label: 'Restore mine', onPressed: () => sync.restoreConflict(c)),
              QuietButton(label: 'Dismiss', color: NqColors.textSecondary, onPressed: () => sync.dismissConflict(c)),
            ],
          ),
        ],
      ],
    ),
  );
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.letter});
  final String? letter;

  @override
  Widget build(BuildContext context) => Container(
    width: 52,
    height: 52,
    alignment: Alignment.center,
    decoration: const BoxDecoration(color: NqColors.fill, shape: BoxShape.circle),
    child: letter == null
        ? const Icon(Icons.person_outline_rounded, color: NqColors.ink, size: 26)
        : Text(letter!, style: NqText.title),
  );
}
