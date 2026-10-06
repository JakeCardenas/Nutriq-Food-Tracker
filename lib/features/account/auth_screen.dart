import 'package:flutter/material.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../app/app_scope.dart';
import '../../app/theme.dart';
import '../../services/auth/auth_service.dart';
import '../../widgets/buttons.dart';
import '../../widgets/labels.dart';
import 'google_logo.dart';

enum _Mode { signIn, signUp, reset, checkEmail, resetSent }

/// Sign in / create an account with Apple (iOS), Google, or email.
///
/// On success the session switches to the account automatically (this screen
/// belongs to the previous session's navigator and goes away with it).
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, this.startWithSignUp = false, this.fromOnboarding = false});

  final bool startWithSignUp;

  /// Signing up from "Save your progress": the person agreed to bring this
  /// phone's data into the new account.
  final bool fromOnboarding;

  static Future<void> open(BuildContext context, {bool signUp = false, bool fromOnboarding = false}) =>
      Navigator.of(context).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => AuthScreen(startWithSignUp: signUp, fromOnboarding: fromOnboarding),
        ),
      );

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  late _Mode _mode = widget.startWithSignUp ? _Mode.signUp : _Mode.signIn;
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  AuthService get _auth => AppScope.of(context).auth;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (widget.fromOnboarding) AppScope.of(context).sessions.expectImportConsent();
      await action();
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Something went wrong: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final email = _email.text.trim();
    switch (_mode) {
      case _Mode.signIn:
        await _run(() => _auth.signInWithEmail(email, _password.text));
      case _Mode.signUp:
        await _run(() async {
          final result = await _auth.signUpWithEmail(email, _password.text);
          if (result.needsEmailConfirmation && mounted) setState(() => _mode = _Mode.checkEmail);
        });
      case _Mode.reset:
        await _run(() async {
          await _auth.sendPasswordReset(email);
          if (mounted) setState(() => _mode = _Mode.resetSent);
        });
      case _Mode.checkEmail || _Mode.resetSent:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = _auth;
    return Scaffold(
      backgroundColor: NqColors.card,
      appBar: AppBar(
        backgroundColor: NqColors.card,
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(NqSpace.page, 0, NqSpace.page, NqSpace.xxl),
          children: switch (_mode) {
            _Mode.checkEmail => _sent(
              title: 'Check your email',
              message:
                  'We sent a confirmation link to ${_email.text.trim()}. Open it on this phone to finish creating '
                  'your account. Until then, Nutriq keeps working on this phone.',
              action: QuietButton(
                label: 'Resend email',
                icon: Icons.refresh_rounded,
                onPressed: _busy ? null : () => _run(() => auth.resendConfirmation(_email.text.trim())),
              ),
            ),
            _Mode.resetSent => _sent(
              title: 'Check your email',
              message:
                  'If an account exists for ${_email.text.trim()}, a reset link is on its way. Open it on this '
                  'phone to choose a new password.',
            ),
            _ => _form0(auth),
          },
        ),
      ),
    );
  }

  List<Widget> _form0(AuthService auth) {
    final signUp = _mode == _Mode.signUp;
    final reset = _mode == _Mode.reset;
    return [
      Text(
        reset ? 'Reset your password' : (signUp ? 'Create your account' : 'Sign in to Nutriq'),
        style: NqText.largeTitle,
      ),
      const SizedBox(height: NqSpace.sm),
      Text(
        reset
            ? 'Enter your email and we’ll send a link to set a new password.'
            : 'Sync your meals and goals across devices. Photos stay on this phone, and the app stays free.',
        style: NqText.callout,
      ),
      const SizedBox(height: NqSpace.xxl),
      if (!reset) ...[
        if (auth.supportsApple) ...[
          SizedBox(
            height: 56,
            child: SignInWithAppleButton(
              text: signUp ? 'Sign up with Apple' : 'Sign in with Apple',
              borderRadius: const BorderRadius.all(Radius.circular(28)),
              onPressed: _busy ? () {} : () => _run(() async => await auth.signInWithApple()),
            ),
          ),
          const SizedBox(height: NqSpace.md),
        ],
        if (auth.supportsGoogle) ...[
          SecondaryButton(
            label: 'Continue with Google',
            leading: const GoogleLogo(size: 20),
            onPressed: _busy ? null : () => _run(() async => await auth.signInWithGoogle()),
          ),
          const SizedBox(height: NqSpace.md),
        ],
        if (auth.supportsApple || auth.supportsGoogle)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: NqSpace.md),
            child: Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('or use email', style: NqText.footnote),
                ),
                const Expanded(child: Divider()),
              ],
            ),
          ),
      ],
      Form(
        key: _form,
        child: Column(
          children: [
            TextFormField(
              controller: _email,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              autocorrect: false,
              textInputAction: reset ? TextInputAction.done : TextInputAction.next,
              validator: (v) {
                final t = v?.trim() ?? '';
                return t.contains('@') && t.contains('.') ? null : 'Enter a valid email address';
              },
            ),
            if (!reset) ...[
              const SizedBox(height: NqSpace.md),
              TextFormField(
                controller: _password,
                decoration: InputDecoration(
                  labelText: 'Password',
                  helperText: signUp ? 'At least 8 characters' : null,
                  suffixIcon: IconButton(
                    tooltip: _obscure ? 'Show password' : 'Hide password',
                    icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                obscureText: _obscure,
                autofillHints: [signUp ? AutofillHints.newPassword : AutofillHints.password],
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                validator: (v) => (v ?? '').length < 8 ? 'Use at least 8 characters' : null,
              ),
            ],
          ],
        ),
      ),
      if (_error != null) ...[
        const SizedBox(height: NqSpace.md),
        NoticeCard(
          tone: NoticeTone.caution,
          icon: Icons.error_outline_rounded,
          title: 'Couldn’t continue',
          message: _error!,
        ),
      ],
      const SizedBox(height: NqSpace.xl),
      PrimaryButton(
        label: reset ? 'Send reset link' : (signUp ? 'Create account' : 'Sign in'),
        busy: _busy,
        onPressed: _submit,
      ),
      const SizedBox(height: NqSpace.sm),
      if (!reset)
        Center(
          child: QuietButton(
            label: signUp ? 'Already have an account? Sign in' : 'New here? Create an account',
            color: NqColors.textSecondary,
            onPressed: () => setState(() {
              _mode = signUp ? _Mode.signIn : _Mode.signUp;
              _error = null;
            }),
          ),
        ),
      Center(
        child: QuietButton(
          label: reset ? 'Back to sign in' : 'Forgot password?',
          color: NqColors.textSecondary,
          onPressed: () => setState(() {
            _mode = reset ? _Mode.signIn : _Mode.reset;
            _error = null;
          }),
        ),
      ),
      const SizedBox(height: NqSpace.lg),
      Text(
        'Signing in is optional. Without an account, everything stays on this phone.',
        style: NqText.caption,
        textAlign: TextAlign.center,
      ),
    ];
  }

  List<Widget> _sent({required String title, required String message, Widget? action}) => [
    const SizedBox(height: NqSpace.xxl),
    const Icon(Icons.mark_email_read_outlined, size: 48, color: NqColors.ink),
    const SizedBox(height: NqSpace.lg),
    Text(title, style: NqText.largeTitle, textAlign: TextAlign.center),
    const SizedBox(height: NqSpace.sm),
    Text(message, style: NqText.callout, textAlign: TextAlign.center),
    const SizedBox(height: NqSpace.lg),
    if (_error != null)
      NoticeCard(tone: NoticeTone.caution, icon: Icons.error_outline_rounded, title: 'Couldn’t send', message: _error!),
    if (action != null) Center(child: action),
    const SizedBox(height: NqSpace.lg),
    PrimaryButton(label: 'Done', onPressed: () => Navigator.pop(context)),
  ];
}
