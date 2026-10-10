import 'package:arabic_decoded/providers/auth_providers.dart';
import 'package:arabic_decoded/screens/sign_in_screen.dart';
import 'package:arabic_decoded/services/auth_service.dart';
import 'package:arabic_decoded/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

/// A scripted stand-in for Supabase Auth: each test sets up how the
/// "server" should respond, then checks what the screen asked it to do.
class _FakeAuth implements AuthService {
  _FakeAuth({this.emailCodesAvailable = true});

  @override
  final bool emailCodesAvailable;

  @override
  bool get googleSignInAvailable => false;

  final calls = <String>[];
  bool emailConfirmed = true;
  SignUpResult signUpResult = SignUpResult.confirmationSent;
  String validCode = '12345678';

  @override
  Future<bool> signInWithPassword({
    required String email,
    required String password,
  }) async {
    calls.add('signIn $email $password');
    if (password != 'correct') {
      throw const AuthException('Invalid login credentials');
    }
    return emailConfirmed;
  }

  @override
  Future<SignUpResult> signUp({
    required String email,
    required String password,
  }) async {
    calls.add('signUp $email $password');
    return signUpResult;
  }

  @override
  Future<void> confirmEmail({
    required String email,
    required String code,
  }) async {
    calls.add('confirmEmail $email $code');
    if (code != validCode) {
      throw const AuthException('Token has expired or is invalid');
    }
  }

  @override
  Future<void> resendConfirmation(String email) async {
    calls.add('resendConfirmation $email');
  }

  @override
  Future<void> sendPasswordResetCode(String email) async {
    calls.add('sendPasswordResetCode $email');
  }

  @override
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    calls.add('resetPassword $email $code $newPassword');
  }

  @override
  Future<bool> signInWithGoogle() async => false;

  @override
  Future<void> signOut() async {}

  @override
  Future<void> deleteAccount() async {}
}

/// Opens the sign-in screen on top of a placeholder route, the way
/// Settings does, so "the screen closed itself" is observable as the
/// placeholder being back on top.
Future<void> _open(WidgetTester tester, _FakeAuth auth) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [authServiceProvider.overrideWithValue(auth)],
      child: MaterialApp(
        theme: buildAppTheme(brightness: Brightness.light),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SignInScreen())),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Future<void> _enter(WidgetTester tester, String label, String text) async {
  await tester.enterText(find.widgetWithText(TextFormField, label), text);
}

Future<void> _tapButton(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

/// The screen's primary button, as opposed to its app bar title — several
/// steps use the same words for both.
Future<void> _submit(WidgetTester tester, String label) async {
  final button = find.widgetWithText(ElevatedButton, label);
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

bool _isClosed() => find.byType(SignInScreen).evaluate().isEmpty;

void main() {
  testWidgets('signing in with the right password closes the screen', (
    tester,
  ) async {
    final auth = _FakeAuth();
    await _open(tester, auth);

    await _enter(tester, 'Email', ' me@example.com ');
    await _enter(tester, 'Password', 'correct');
    await _submit(tester, 'Sign in');

    expect(auth.calls, ['signIn me@example.com correct']);
    expect(_isClosed(), isTrue);
  });

  testWidgets('a wrong password shows the error and stays put', (tester) async {
    final auth = _FakeAuth();
    await _open(tester, auth);

    await _enter(tester, 'Email', 'me@example.com');
    await _enter(tester, 'Password', 'wrong');
    await _submit(tester, 'Sign in');

    expect(find.text('Invalid login credentials'), findsOneWidget);
    expect(_isClosed(), isFalse);
  });

  testWidgets('nothing is sent until the form is filled in properly', (
    tester,
  ) async {
    final auth = _FakeAuth();
    await _open(tester, auth);
    await _tapButton(tester, 'New here? Create an account');

    await _enter(tester, 'Email', 'not-an-email');
    await _enter(tester, 'Password', '123');
    await _submit(tester, 'Create account');

    expect(find.text('Enter your email address'), findsOneWidget);
    expect(find.text('Use at least 6 characters'), findsOneWidget);
    expect(auth.calls, isEmpty);
  });

  testWidgets('a new account is confirmed with the emailed code', (
    tester,
  ) async {
    final auth = _FakeAuth();
    await _open(tester, auth);
    await _tapButton(tester, 'New here? Create an account');

    await _enter(tester, 'Email', 'new@example.com');
    await _enter(tester, 'Password', 'secret1');
    await _submit(tester, 'Create account');

    expect(find.text('Confirm your email'), findsOneWidget);
    expect(find.textContaining('new@example.com'), findsWidgets);

    // A mistyped code is reported, and can simply be corrected.
    await _enter(tester, 'Code from the email', '00000000');
    await _submit(tester, 'Confirm');
    expect(find.text('Token has expired or is invalid'), findsOneWidget);
    expect(_isClosed(), isFalse);

    await _enter(tester, 'Code from the email', '12345678');
    await _submit(tester, 'Confirm');

    expect(auth.calls, [
      'signUp new@example.com secret1',
      'confirmEmail new@example.com 00000000',
      'confirmEmail new@example.com 12345678',
    ]);
    expect(_isClosed(), isTrue);
  });

  testWidgets('when the project does not require confirmation, creating an '
      'account signs straight in', (tester) async {
    final auth = _FakeAuth()..signUpResult = SignUpResult.signedIn;
    await _open(tester, auth);
    await _tapButton(tester, 'New here? Create an account');

    await _enter(tester, 'Email', 'new@example.com');
    await _enter(tester, 'Password', 'secret1');
    await _submit(tester, 'Create account');

    expect(_isClosed(), isTrue);
  });

  testWidgets('creating an account with an email that already has one '
      'sends them to sign in', (tester) async {
    final auth = _FakeAuth()..signUpResult = SignUpResult.alreadyRegistered;
    await _open(tester, auth);
    await _tapButton(tester, 'New here? Create an account');

    await _enter(tester, 'Email', 'me@example.com');
    await _enter(tester, 'Password', 'secret1');
    await _submit(tester, 'Create account');

    expect(
      find.text('You already have an account — sign in instead.'),
      findsOneWidget,
    );
    expect(find.widgetWithText(ElevatedButton, 'Sign in'), findsOneWidget);
  });

  testWidgets('signing in before confirming the email asks for the code', (
    tester,
  ) async {
    final auth = _FakeAuth()..emailConfirmed = false;
    await _open(tester, auth);

    await _enter(tester, 'Email', 'me@example.com');
    await _enter(tester, 'Password', 'correct');
    await _submit(tester, 'Sign in');

    expect(find.text('Confirm your email'), findsOneWidget);

    await _tapButton(tester, 'Send a new code');
    expect(auth.calls.last, 'resendConfirmation me@example.com');
    expect(find.text('A new code is on its way.'), findsOneWidget);
  });

  testWidgets('a forgotten password is reset with an emailed code', (
    tester,
  ) async {
    final auth = _FakeAuth();
    await _open(tester, auth);

    await _enter(tester, 'Email', 'me@example.com');
    await _tapButton(tester, 'Forgot password?');
    await _submit(tester, 'Email me a reset code');

    await _enter(tester, 'Code from the email', '12345678');
    await _enter(tester, 'New password', 'brand-new');
    await _submit(tester, 'Set new password');

    expect(auth.calls, [
      'sendPasswordResetCode me@example.com',
      'resetPassword me@example.com 12345678 brand-new',
    ]);
    expect(_isClosed(), isTrue);
  });

  testWidgets('without code emails set up, the code-based flows are not '
      'offered and confirmation falls back to the emailed link', (
    tester,
  ) async {
    final auth = _FakeAuth(emailCodesAvailable: false);
    await _open(tester, auth);

    expect(find.text('Forgot password?'), findsNothing);

    await _tapButton(tester, 'New here? Create an account');
    await _enter(tester, 'Email', 'new@example.com');
    await _enter(tester, 'Password', 'secret1');
    await _submit(tester, 'Create account');

    expect(find.textContaining('open the confirmation link'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Sign in'), findsOneWidget);
    expect(find.text('Code from the email'), findsNothing);
  });
}
