import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import '../providers/auth_providers.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/pattern_divider.dart';

/// Which form the screen is currently showing. They share one screen (and
/// one email field) rather than being separate routes, so moving between
/// them — "wrong form, I already have an account", "forgot my password" —
/// never loses what's already been typed.
enum _Step {
  signIn,
  createAccount,

  /// Typing the code from the confirmation email of a new account.
  confirmEmail,

  /// Asking for a password reset code.
  forgotPassword,

  /// Typing that code, plus the new password.
  newPassword,
}

/// Reached from the Account section in Settings: signing in, creating an
/// account, and resetting a forgotten password, plus "Continue with
/// Google" where that's available.
///
/// Signing in is optional — the app is fully usable without it — so this
/// is a screen you choose to open, not a gate in front of the app. It pops
/// itself once someone is signed in; sync then starts on its own (see
/// `SyncNotifier`).
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _codeController = TextEditingController();

  _Step _step = _Step.signIn;
  bool _busy = false;
  String? _error;
  String? _notice;

  AuthService get _auth => ref.read(authServiceProvider)!;
  String get _email => _emailController.text.trim();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  /// Switches form, clearing whatever only made sense on the old one. The
  /// email is deliberately kept.
  void _goTo(_Step step, {String? notice}) {
    setState(() {
      _step = step;
      _error = null;
      _notice = notice;
      _codeController.clear();
      if (step == _Step.newPassword) _passwordController.clear();
    });
  }

  /// Runs one request, showing a spinner meanwhile and turning whatever
  /// goes wrong into a message under the form.
  Future<void> _attempt(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await action();
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Couldn\'t reach the server. Check your connection and try '
              'again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final email = _email;
    final password = _passwordController.text;
    final code = _codeController.text.trim();

    await _attempt(() async {
      switch (_step) {
        case _Step.signIn:
          final signedIn = await _auth.signInWithPassword(
            email: email,
            password: password,
          );
          if (signedIn) {
            _close();
          } else {
            _awaitConfirmation(email);
          }
        case _Step.createAccount:
          switch (await _auth.signUp(email: email, password: password)) {
            case SignUpResult.signedIn:
              _close();
            case SignUpResult.confirmationSent:
              _awaitConfirmation(email);
            case SignUpResult.alreadyRegistered:
              _goTo(
                _Step.signIn,
                notice: 'You already have an account — sign in instead.',
              );
          }
        case _Step.confirmEmail:
          await _auth.confirmEmail(email: email, code: code);
          _close();
        case _Step.forgotPassword:
          await _auth.sendPasswordResetCode(email);
          _goTo(
            _Step.newPassword,
            notice:
                'If $email has an account, a reset code is on its way. '
                'Enter it below with your new password.',
          );
        case _Step.newPassword:
          await _auth.resetPassword(
            email: email,
            code: code,
            newPassword: password,
          );
          _close();
      }
    });
  }

  /// A confirmation email has gone out to [email]. With code emails set
  /// up, ask for the code right here; with Supabase's stock email there's
  /// only a link, so all the app can do is say to click it and come back.
  void _awaitConfirmation(String email) {
    if (!mounted) return;
    if (_auth.emailCodesAvailable) {
      _goTo(
        _Step.confirmEmail,
        notice: 'We\'ve emailed a confirmation code to $email.',
      );
    } else {
      _goTo(
        _Step.signIn,
        notice:
            'Almost there — open the confirmation link we sent to $email, '
            'then sign in here.',
      );
    }
  }

  Future<void> _resendCode() async {
    final email = _email;
    await _attempt(() async {
      if (_step == _Step.confirmEmail) {
        await _auth.resendConfirmation(email);
      } else {
        await _auth.sendPasswordResetCode(email);
      }
      if (mounted) setState(() => _notice = 'A new code is on its way.');
    });
  }

  Future<void> _continueWithGoogle() async {
    await _attempt(() async {
      if (await _auth.signInWithGoogle()) _close();
    });
  }

  void _close() {
    if (mounted) Navigator.of(context).pop();
  }

  String get _title => switch (_step) {
    _Step.signIn => 'Sign in',
    _Step.createAccount => 'Create account',
    _Step.confirmEmail => 'Confirm your email',
    _Step.forgotPassword || _Step.newPassword => 'Reset password',
  };

  String get _submitLabel => switch (_step) {
    _Step.signIn => 'Sign in',
    _Step.createAccount => 'Create account',
    _Step.confirmEmail => 'Confirm',
    _Step.forgotPassword => 'Email me a reset code',
    _Step.newPassword => 'Set new password',
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final auth = ref.watch(authServiceProvider);

    final asksForCode =
        _step == _Step.confirmEmail || _step == _Step.newPassword;
    final asksForPassword =
        _step == _Step.signIn ||
        _step == _Step.createAccount ||
        _step == _Step.newPassword;
    final choosingPassword =
        _step == _Step.createAccount || _step == _Step.newPassword;

    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: SafeArea(
        child: Column(
          children: [
            const PatternDivider(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (_step == _Step.signIn || _step == _Step.createAccount)
                    Text(
                      'Your progress is saved to your account, so it '
                      'follows you to any device you sign in on.',
                      style: TextStyle(color: colors.inkMuted),
                    ),
                  if (_notice != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Text(
                        _notice!,
                        style: TextStyle(color: colors.deepGreen),
                      ),
                    ),
                  const SizedBox(height: 20),
                  Form(
                    key: _formKey,
                    child: AutofillGroup(
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _emailController,
                            // Once a code has been sent, the address it
                            // went to is fixed.
                            enabled: !_busy && !asksForCode,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.email],
                            autocorrect: false,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                            ),
                            validator: (value) {
                              final email = value?.trim() ?? '';
                              if (!email.contains('@')) {
                                return 'Enter your email address';
                              }
                              return null;
                            },
                          ),
                          if (asksForCode) ...[
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _codeController,
                              enabled: !_busy,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              textInputAction: asksForPassword
                                  ? TextInputAction.next
                                  : TextInputAction.done,
                              autofillHints: const [AutofillHints.oneTimeCode],
                              decoration: const InputDecoration(
                                labelText: 'Code from the email',
                              ),
                              onFieldSubmitted: asksForPassword
                                  ? null
                                  : (_) => _submit(),
                              // How many digits is a Supabase project
                              // setting, so only "something was typed" is
                              // checked here; the server judges the rest.
                              validator: (value) => (value ?? '').trim().isEmpty
                                  ? 'Enter the code from the email'
                                  : null,
                            ),
                          ],
                          if (asksForPassword) ...[
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _passwordController,
                              enabled: !_busy,
                              obscureText: true,
                              textInputAction: TextInputAction.done,
                              autofillHints: [
                                choosingPassword
                                    ? AutofillHints.newPassword
                                    : AutofillHints.password,
                              ],
                              decoration: InputDecoration(
                                labelText: _step == _Step.newPassword
                                    ? 'New password'
                                    : 'Password',
                              ),
                              onFieldSubmitted: (_) => _submit(),
                              validator: (value) {
                                final password = value ?? '';
                                if (password.isEmpty) {
                                  return 'Enter your password';
                                }
                                // Supabase's default minimum; only worth
                                // enforcing up front when choosing one.
                                if (choosingPassword && password.length < 6) {
                                  return 'Use at least 6 characters';
                                }
                                return null;
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_submitLabel),
                    ),
                  ),
                  if (_step == _Step.signIn &&
                      auth != null &&
                      auth.googleSignInAvailable) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 50,
                      child: OutlinedButton(
                        onPressed: _busy ? null : _continueWithGoogle,
                        child: const Text('Continue with Google'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  ..._links(auth),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The text links under the main button: the ways out of the current
  /// form.
  List<Widget> _links(AuthService? auth) {
    Widget link(String label, VoidCallback onPressed) {
      return TextButton(
        onPressed: _busy ? null : onPressed,
        child: Text(label),
      );
    }

    final backToSignIn = link('Back to sign in', () => _goTo(_Step.signIn));
    return switch (_step) {
      _Step.signIn => [
        link('New here? Create an account', () => _goTo(_Step.createAccount)),
        if (auth != null && auth.emailCodesAvailable)
          link('Forgot password?', () => _goTo(_Step.forgotPassword)),
      ],
      _Step.createAccount => [
        link('Already have an account? Sign in', () => _goTo(_Step.signIn)),
      ],
      _Step.confirmEmail ||
      _Step.newPassword => [link('Send a new code', _resendCode), backToSignIn],
      _Step.forgotPassword => [backToSignIn],
    };
  }
}
