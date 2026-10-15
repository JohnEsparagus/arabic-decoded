# Arabic Decoded

A Flutter app for learning Arabic through its three-letter roots. Roots are
grouped into themed campaigns and studied as flashcards on a spaced-repetition
(SM-2) schedule. Signing in is optional: it backs up your progress and syncs
it between devices.

## Running it

```bash
flutter pub get
flutter run -d linux      # or an Android / iOS device
flutter test
```

It also runs in a browser (`flutter run -d chrome`), where SQLite runs as
WebAssembly and keeps its data in the browser's storage, offline included.
Pushes to `main` publish it to GitHub Pages (`.github/workflows/web.yml`).

## How it fits together

- **Content** is bundled with the app as JSON in `assets/data/`. To add a
  campaign, drop in a JSON file and list it in
  `lib/config/campaign_sources.dart`.
  - `lessons.json` and `stories.json` are read-once cards, each shown
    after `after_roots` roots have been introduced. Add or delete an entry
    and the card follows.
  - `sentences.json` is the sentence corpus. It is loaded into its own
    indexed table once per edition, so **bump `sentencesVersion`** in
    `campaign_sources.dart` whenever you change the file (a test fails if
    you forget). It is built to hold thousands of sentences.
- **Progress** lives in an on-device SQLite database
  (`lib/services/database_service.dart`). The app always reads and writes
  that, so it works offline and without an account.
- **Sync** (`lib/services/sync_service.dart`) copies progress to and from
  Supabase for a signed-in user. Each card is matched by deck name + Arabic
  word, and whichever device graded it last wins. Review history and
  the library (favorites and collections) sync alongside it.
- **Accounts** go through `lib/services/auth_service.dart`, a thin wrapper
  over Supabase Auth.

## Supabase

The backend is three tables (`card_progress`, `review_log` and
`user_library`) and one function (`delete_account`), all defined in
`supabase/migrations/`. With the
[Supabase CLI](https://supabase.com/docs/guides/cli):

```bash
npx supabase login
npx supabase link --project-ref <project-ref>
npx supabase db push        # apply new migrations
npx supabase config push    # apply supabase/config.toml
```

The project URL and publishable key are set in `lib/main.dart`.

### Optional sign-in features

These need setup outside the code and are switched on in
`lib/config/auth_config.dart`:

- **Email codes** (confirming an account inside the app, and "Forgot
  password?"). Supabase only allows custom email templates once the project
  sends mail through its own SMTP provider, so for now email confirmation is
  off and accounts need no email at all. The steps to turn it on are in
  `supabase/config.toml`.
- **Continue with Google** (Android and iOS). Needs OAuth client ids from the
  Google Cloud console, and the Google provider enabled in Supabase.
