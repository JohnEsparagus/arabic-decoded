import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/auth_config.dart';

/// What happened when someone tried to create an account.
enum SignUpResult {
  /// Account created and already signed in (email confirmation is turned
  /// off in the Supabase project).
  signedIn,

  /// Account created, but the email has to be confirmed before signing in.
  confirmationSent,

  /// That email already has an account.
  alreadyRegistered,
}

/// Everything to do with accounts: creating one, signing in and out,
/// resetting a password, deleting the account. A thin wrapper over
/// Supabase Auth so screens don't talk to the Supabase client directly.
///
/// Who is currently signed in isn't exposed here — that's a stream, so it
/// lives in `auth_providers.dart` where widgets can watch it.
class AuthService {
  AuthService(this._client);

  final SupabaseClient _client;

  bool _googleInitialized = false;

  /// The email whose reset code has already been accepted — see
  /// [resetPassword].
  String? _recoveryVerifiedFor;

  /// Whether emails contain a typeable code — see `auth_config.dart`.
  bool get emailCodesAvailable => emailCodesEnabled;

  /// Whether to offer "Continue with Google": the client ids have to be
  /// filled in (see `auth_config.dart`), and the google_sign_in plugin
  /// only has native implementations for Android and iOS — on desktop
  /// it's email + password only.
  bool get googleSignInAvailable {
    if (googleWebClientId.isEmpty || kIsWeb) return false;
    if (Platform.isIOS) return googleIosClientId.isNotEmpty;
    return Platform.isAndroid;
  }

  /// Returns false, having sent a fresh confirmation email, if the
  /// password was right but the account's email hasn't been confirmed yet.
  /// Any other failure (wrong password, no connection) throws.
  Future<bool> signInWithPassword({
    required String email,
    required String password,
  }) async {
    try {
      await _client.auth.signInWithPassword(email: email, password: password);
      return true;
    } on AuthException catch (e) {
      if (e.code != 'email_not_confirmed') rethrow;
      await resendConfirmation(email);
      return false;
    }
  }

  Future<SignUpResult> signUp({
    required String email,
    required String password,
  }) async {
    final AuthResponse response;
    try {
      response = await _client.auth.signUp(email: email, password: password);
    } on AuthException catch (e) {
      // How Supabase reports a taken email when confirmation is off.
      if (e.code == 'user_already_exists') {
        return SignUpResult.alreadyRegistered;
      }
      rethrow;
    }
    if (response.session != null) return SignUpResult.signedIn;
    // With confirmation on it's subtler: so that sign-up can't be used to
    // find out who has an account, Supabase answers for an existing email
    // exactly as it would a new one, just with no identities attached —
    // and sends no email. Without this check the user would wait for a
    // confirmation that never comes.
    if (response.user?.identities?.isEmpty ?? false) {
      return SignUpResult.alreadyRegistered;
    }
    return SignUpResult.confirmationSent;
  }

  /// Confirms a new account with the code from its confirmation email,
  /// which also signs it in.
  Future<void> confirmEmail({
    required String email,
    required String code,
  }) async {
    await _client.auth.verifyOTP(
      email: email,
      token: code,
      type: OtpType.signup,
    );
  }

  Future<void> resendConfirmation(String email) async {
    await _client.auth.resend(email: email, type: OtpType.signup);
  }

  /// Emails a password reset code. Completes normally whether or not the
  /// address has an account, so it can't be used to find out who does.
  Future<void> sendPasswordResetCode(String email) async {
    _recoveryVerifiedFor = null;
    await _client.auth.resetPasswordForEmail(email);
  }

  /// Exchanges a reset [code] for a signed-in session, then sets
  /// [newPassword] on it.
  ///
  /// A code only works once. If it's accepted but the new password is
  /// then rejected (e.g. too weak), calling this again skips straight to
  /// the password rather than re-submitting a code that's now spent.
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    if (_recoveryVerifiedFor != email) {
      await _client.auth.verifyOTP(
        email: email,
        token: code,
        type: OtpType.recovery,
      );
      _recoveryVerifiedFor = email;
    }
    await _client.auth.updateUser(UserAttributes(password: newPassword));
    _recoveryVerifiedFor = null;
  }

  /// Runs the native Google account picker and hands the resulting ID
  /// token to Supabase. Returns false if the user backed out of the
  /// picker.
  Future<bool> signInWithGoogle() async {
    final google = GoogleSignIn.instance;
    if (!_googleInitialized) {
      await google.initialize(
        clientId: Platform.isIOS ? googleIosClientId : null,
        serverClientId: googleWebClientId,
      );
      _googleInitialized = true;
    }

    final GoogleSignInAccount account;
    try {
      account = await google.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return false;
      rethrow;
    }

    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw const AuthException('Google did not return an ID token.');
    }
    await _client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
    );
    return true;
  }

  /// Always leaves this device signed out: Supabase drops the local
  /// session first and only then tells the server, so failing to reach
  /// the server (e.g. offline) isn't worth surfacing.
  Future<void> signOut() async {
    try {
      if (_googleInitialized) await GoogleSignIn.instance.signOut();
      await _client.auth.signOut();
    } catch (_) {}
  }

  /// Permanently deletes the signed-in user's account and everything
  /// stored against it on the server (see the `delete_account` function in
  /// `supabase/migrations/`). The caller still needs to [signOut]
  /// afterwards to discard the now-useless local session.
  Future<void> deleteAccount() async {
    await _client.rpc('delete_account');
  }
}
