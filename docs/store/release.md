# Releasing Peel

What's ready in the code, what only you can do, and the order to do it in.

## Already done in the app

| | iPhone | Android |
|---|---|---|
| App id | `app.peel.peel` | `app.peel.peel` |
| Version | 1.0.0 (1), from `pubspec.yaml` | same |
| Devices | iPhone only, portrait | phones, portrait |
| Minimum | iOS 17 | Android 7 (API 24), targets API 36 |
| Test lab | left out of store builds | left out of store builds |
| Privacy | privacy manifest (`ios/Runner/PrivacyInfo.xcprivacy`), no tracking | no photo or storage permissions |
| Encryption | `ITSAppUsesNonExemptEncryption = NO`, no export paperwork | n/a |
| Icons | light, dark and tinted, 1024 px, no transparency | adaptive and themed icons |
| Launch | Peel's paper colour, light and dark | same, with Android 12+ splash |
| Native code | n/a | every library aligned for 16 KB pages |
| Size | about 21 MB | about 20 MB per phone |

Android permissions in the final app: microphone (voice stickers), plus
internet, network state and wake lock, which the libraries add (ML Kit
downloads its cut-out model; the players keep the screen awake).

## 1. Things only you can do

- **Accounts.** Apple Developer Program and a Google Play developer account.
- **A web page for the privacy policy** (both stores require a link).
  Host `privacy-policy.md` anywhere public, e.g. GitHub Pages, Notion or
  Carrd, after filling in your contact email.
- **A support link** (App Store requires one): a web page or a `mailto:`.
- **Screenshots.** iPhone 6.9" (1320 × 2868 or 1290 × 2796), at least 3.
  Android phone, at least 2. Play also needs a 512 × 512 icon and a
  1024 × 500 feature graphic.

## 2. Android upload key (once)

Run this outside the repo and keep the file and passwords safe, e.g. in a
password manager. Losing it means asking Google to reset it.

```bash
keytool -genkey -v -keystore ~/peel-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Then create `app/android/key.properties` (git ignores it):

```
storePassword=…
keyPassword=…
keyAlias=upload
storeFile=/Users/<you>/peel-upload.jks
```

Turn on **Play App Signing** when you create the app in Play Console. Google
then holds the real signing key, and this one only uploads.

## 3. Build

```bash
app/tool/build_release.sh
```

It runs the tests, then builds `app-release.aab` and the `.ipa`. It stops if
`key.properties` is missing. Keep the `build/symbols/<version>` folder for
each release: it's needed to read crash reports.

For every later release, raise `version:` in `pubspec.yaml` (e.g.
`1.0.1+2`; the number after `+` must always go up) and `appVersion` in
`lib/core/build_info.dart`. A test checks the two match.

## 4. App Store Connect

1. New app: name, primary language English, bundle id `app.peel.peel`,
   SKU e.g. `peel-ios`.
2. Upload: open `build/ios/archive/Runner.xcarchive` in Xcode Organizer →
   Distribute App, or drag the `.ipa` into Transporter.
3. Fill in from `listing.md`: name, subtitle, description, keywords,
   category, age rating, review notes.
4. **App Privacy:** "Data Not Collected". The iPhone app sends nothing
   anywhere; cut-outs use Apple's Vision on the phone.
5. TestFlight first, then Submit for Review.

## 5. Play Console

1. Create app, free, app or game: App. Category: Art & Design (or
   Photography).
2. Upload `app-release.aab` to **Internal testing** first, then Production.
3. Fill in from `listing.md`: title, short and full description, content
   rating questionnaire, target audience (13+ is simplest; avoid "children"
   unless you want Families policy review).
4. **Data safety:** see `listing.md`. Peel itself collects nothing, but
   Google's ML Kit (the cut-out) sends Google some diagnostics, so the
   form can't say "no data collected".
5. New personal developer accounts must run a closed test with at least
   12 testers for 14 days before Production opens.

## Before each release

- `flutter test` passes, and the app is tried on a real iPhone and a real
  Android phone: photo sticker, video sticker, sound, Add to WhatsApp,
  Copy, Share, Save, dark mode.
- Version raised in both places.
