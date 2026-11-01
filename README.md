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

- **Content** is JSON in `assets/data/`, listed by `manifest.json`. A copy
  ships in the app, and pushing to `main` publishes it online, where apps
  pick it up without a store update (see "Updating content" below).
  - `quran.json` is the Quran campaign: the Quran's most common roots in
    order. Most entries just name a root another campaign teaches
    (`{"root": "ق و ل"}`), so there's one card per root and progress is
    shared; roots no campaign has are full entries in the Quran's own deck.
  - `lessons.json` and `stories.json` are read-once cards, each shown
    after `after_roots` roots have been introduced. Add or delete an entry
    and the card follows.
  - `sentences.json` is the sentence corpus, loaded into its own indexed
    table whenever the file changes. It holds the app's own example sentences followed by
    about 13,000 from [Tatoeba](https://tatoeba.org) (CC BY 2.0 FR; credited
    on the About screen), chosen because they use words the app teaches.
- **Progress** lives in an on-device SQLite database
  (`lib/services/database_service.dart`). The app always reads and writes
  that, so it works offline and without an account.
- **Sync** (`lib/services/sync_service.dart`) copies progress to and from
  Supabase for a signed-in user. Each card is matched by deck name + Arabic
  word, and whichever device graded it last wins. Review history and
  the library (favorites and collections) sync alongside it.
- **Accounts** go through `lib/services/auth_service.dart`, a thin wrapper
  over Supabase Auth.

## Updating content

To change roots, words, lessons, stories or sentences:

1. Edit the JSON in `assets/data/`. For a new campaign, add the file and list
   it under `campaigns` in `manifest.json`. If a card's Arabic or deck
   changes, add a line to `moves`, so progress follows it.
2. Run `python3 tool/build_manifest.py` (a test fails if you forget).
3. Push to `main`. Apps download it on their next launch and use it from the
   launch after, with no store release.

New features or database changes still need an app update. If content
needs something older apps can't handle, raise `contentSchema` and the
manifest's `schema`; those apps stay on what they have.

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
