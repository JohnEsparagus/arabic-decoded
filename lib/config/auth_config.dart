/// Sign-in options that depend on setup outside this codebase. Each one is
/// off until that setup is done, and the app simply doesn't offer it.
library;

/// Whether Supabase's emails carry a code to type into the app (see
/// `supabase/templates/`) instead of the stock "click this link" emails.
/// Turns on the two flows that depend on a code: confirming a new
/// account's email inside the app, and "Forgot password?".
///
/// Off for now because Supabase only allows custom email templates once
/// the project sends mail through its own SMTP provider. Until then email
/// confirmation is switched off altogether, so accounts work without any
/// email at all. `supabase/config.toml` has the steps for turning both on
/// together; this is the last of them.
const emailCodesEnabled = false;

// "Continue with Google". Both ids come from the Google Cloud console
// (APIs & Services > Credentials); the web client id also has to be
// entered in the Supabase dashboard under Authentication > Sign In /
// Providers > Google. See `AuthService.googleSignInAvailable`.

/// The *web application* client id. Required on every platform: it's the
/// audience Supabase checks the Google ID token against.
const googleWebClientId = '';

/// The iOS client id. Only needed for iOS builds.
const googleIosClientId = '';
