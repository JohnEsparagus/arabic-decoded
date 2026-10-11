# Releasing Arabic Decoded

The app's ID on both stores is `com.johnesparagus.arabicdecoded`. It can be
changed freely until the first upload, and never after; if you want a
different one, change it now in `android/app/build.gradle.kts` (two places,
plus the folder under `android/app/src/main/kotlin/`) and in Xcode.

## Once, before the first release

### Android

1. Create the upload key. Keep the file and the passwords somewhere safe
   and backed up: every future update has to be signed with it.

   ```bash
   keytool -genkey -v -keystore ~/arabic-decoded-upload.jks \
     -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```

2. Create `android/key.properties` (it is git-ignored; never commit it):

   ```properties
   storeFile=/home/john/arabic-decoded-upload.jks
   storePassword=<the keystore password>
   keyAlias=upload
   keyPassword=<the key password>
   ```

3. In [Play Console](https://play.google.com/console): create the app,
   fill in the store listing, the data safety form and the content rating,
   and give it the privacy policy URL (see below).

### iOS (on a Mac)

1. Open `ios/Runner.xcworkspace` in Xcode. Under Runner > Signing &
   Capabilities, pick your team and leave "Automatically manage signing"
   on.
2. In [App Store Connect](https://appstoreconnect.apple.com): create the
   app with the bundle ID above, and fill in the listing, the privacy
   answers and the privacy policy URL.

### Privacy policy

Both stores need a public URL. `PRIVACY.md` in this repo is the text; put
it on any public page (your GitHub Pages site is fine) and use that link.

### Supabase

Apply any new migrations before the build that needs them reaches users:

```bash
npx supabase db push
```

## Every release

1. Bump the version in `pubspec.yaml`, e.g. `1.0.0+1` to `1.0.1+2`. The
   number after the `+` must go up every time. Set `appVersion` in
   `lib/config/app_info.dart` to match, and add an entry to
   `assets/data/dev_updates.json`.
2. Check it: `flutter analyze && flutter test`.
3. Build and upload.

   **Android**

   ```bash
   flutter build appbundle
   ```

   Upload `build/app/outputs/bundle/release/app-release.aab` in Play
   Console under Production (or a testing track) > Create new release.

   **iOS**, on a Mac

   ```bash
   flutter build ipa
   ```

   Drag `build/ios/ipa/*.ipa` into the Transporter app, then pick that
   build for a new version in App Store Connect.

4. Submit each for review.

## Letting GitHub build it

Pushing a tag builds the signed Android bundle for you
(`.github/workflows/release.yml`):

```bash
git tag v1.0.1 && git push --tags
```

The bundle appears as a download on the workflow run. It needs four
repository secrets (Settings > Secrets and variables > Actions):

| Secret | Value |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | `base64 -w0 ~/arabic-decoded-upload.jks` |
| `ANDROID_KEYSTORE_PASSWORD` | the keystore password |
| `ANDROID_KEY_ALIAS` | `upload` |
| `ANDROID_KEY_PASSWORD` | the key password |

iOS isn't in that workflow: it needs Apple signing certificates set up on
a macOS runner. [Codemagic](https://codemagic.io) does that part for you
and is the quickest way to get tag-to-TestFlight without owning a Mac.

## Changing the icon

Replace the two images in `assets/icon/` and run
`dart run flutter_launcher_icons`.
