# Peel website

One page to download Peel, plus `/privacy` for the app stores. Static
HTML and CSS with a few lines of JS, served by Vercel from `public/`.

- **Android** visitors get a big "Download for Android" button for the APK
  and three install steps.
- **iPhone and iPad** visitors see "App Store, soon" and no APK.
- **Desktop** visitors see a QR code that opens the page on their phone,
  plus a small APK link.

It follows the system light or dark setting and uses the app's own tokens,
fonts, wordmark and stickers.

## What's where

| Path | What it is |
|---|---|
| `public/index.html` | The page. Its CSS and JS are inline, so the first paint needs no extra requests. Edit this by hand. |
| `public/privacy.html` | Built from `docs/store/privacy-policy.md`. Don't edit it; edit the Markdown and rebuild. |
| `public/assets/` | Fonts, stickers (AVIF and WebP), wordmark and the QR drawer. Names carry a content hash and are cached for a year. |
| `public/download/peel.apk` | The APK. Built locally, ignored by git. |
| `public/og.png`, icons, `site.webmanifest` | Share image and icons. |
| `vercel.json` | Clean URLs, cache headers, APK headers, security headers. |
| `.vercelignore` | Uploads only `public/` and `vercel.json`. |
| `tool/build_apk.sh` | Builds the APK and updates the page. |
| `tool/build.mjs` | Updates the page in place: APK version and size, site URL, privacy page. No dependencies. |
| `tool/media.mjs` | Regenerates fonts, images and icons from `app/` and `design/`. Needs `npm install` in `tool/`. |

## Build the APK

```bash
website/tool/build_apk.sh
```

It runs, from `app/`:

```
flutter build apk --release --target-platform android-arm64 --obfuscate --split-debug-info=build/symbols/apk
```

then copies the result to `public/download/peel.apk` and writes the
version (from `app/pubspec.yaml`) and size into the page. Keep
`app/build/symbols/apk` for each version you publish: you need it to read
crash stack traces.

The APK is arm64 only (about 20.6 MB for 1.0.0). Almost every Android phone
from the last several years is arm64; a few very old or very cheap 32-bit
phones will say "App not installed".

## Before the first deploy

1. **Site address.** Share previews need absolute links. Once you know the
   domain, run:

   ```bash
   node website/tool/build.mjs --site https://your-domain.example
   ```

   It's remembered in the HTML, so later runs keep it. Until then, links
   point at the placeholder `https://peel.example`.

2. **Privacy contact.** The policy ends with a highlighted
   `[your support email]` placeholder. Fill it with:

   ```bash
   node website/tool/build.mjs --contact support@your-domain.example
   ```

   (or put the address in `docs/store/privacy-policy.md` and rebuild).
   It's only stored in the generated `privacy.html`, so pass it again on
   later runs, or put it in the Markdown.

3. **Signing.** Read the next section before you share the APK with anyone.

## Signing

**Right now the APK is signed with the debug key**, because
`app/android/key.properties` doesn't exist. `build_apk.sh` warns about
this. A debug-signed APK installs and works, but:

- the debug key lives in `~/.android/debug.keystore` on this Mac, so a
  build from another machine can't update it;
- nothing signed with a real key can update it either.

Anyone who installs a debug-signed APK will have to uninstall it before
installing a properly signed Peel, **and uninstalling deletes their
stickers** (they live inside the app). So treat debug builds as test
builds only.

### The APK and Google Play

Android installs an update only if it's signed with the same certificate
as the installed app. New apps on Google Play must use **Play App
Signing**. Google signs what users download from Play with the *app
signing key*, not with the upload key in `key.properties`. If Google
generates that key, you never get its private half. Then no APK you build
can update a Play install, and no Play update can install over your APK.

### Recommended: one signing key for both

1. Create one key for signing the app, kept outside the repo and backed up
   (see `docs/store/release.md`, section 2, for the `keytool` command).
2. Point `app/android/key.properties` at it. From then on,
   `build_apk.sh` signs the website APK with it.
3. When you create the app in Play Console, choose to **use your own app
   signing key** instead of letting Google generate one. Play Console
   walks you through exporting it with Google's PEPK tool. Google then
   signs Play downloads with the same key.
4. Optionally, register a separate upload key later. It only proves the
   upload came from you; it doesn't change what users get.

Result: website installs and Play installs are the same app. Either one
updates the other, and nobody loses their stickers. Keep the same
`versionCode` rules: every release raises the number after `+` in
`pubspec.yaml`, on both channels.

### Alternative: let Google make the key

This is simpler in Play Console, but then the website APK and the Play app
can't update each other. When Peel is on Play, swap the download button
for a Play link. Tell existing APK users to uninstall and reinstall from
Play, and warn them that this deletes their stickers.

## Deploy

The APK isn't in git, so deploy with the Vercel CLI from your machine,
after building it:

```bash
website/tool/build_apk.sh
```

```bash
cd website && npx vercel deploy --prod
```

The first run asks you to log in and link a project. Accept the defaults:
`vercel.json` sets "Other" as the framework, no build command, and
`public` as the output folder. `.vercelignore` limits the upload to
`public/` and `vercel.json`, about 22 MB in total.

Then check that the APK is served with the right headers:

```bash
curl -sI https://your-domain.example/download/peel.apk
```

Expect `content-type: application/vnd.android.package-archive` and
`content-disposition: attachment; filename="peel.apk"`.

If you connect the GitHub repo to Vercel instead (root directory
`website`), the page deploys but the APK doesn't, because it isn't in git.
Use GitHub Releases for the file in that case (see below).

### Limits, and when to use GitHub Releases

- **Upload size.** On the Hobby plan, a CLI deploy can upload at most
  100 MB of files. The APK is about 21 MB, so there's plenty of room.
  `build.mjs` warns if the APK passes 90 MB.
- **Bandwidth.** Hobby includes about 100 GB of transfer a month, roughly
  4,800 downloads of a 21 MB APK.

If either limit becomes a problem, attach `peel.apk` to a GitHub Release
of a **public** repository and change the three `href="/download/peel.apk"`
links in `public/index.html` to
`https://github.com/<owner>/<repo>/releases/latest/download/peel.apk`.
GitHub serves it as a generic download. Android browsers still save it as
an `.apk` and open the installer.

## Changing the page

- **Text and layout:** edit `public/index.html`. The CSS at the top is shared
  with the privacy page, which `build.mjs` copies from between the
  `<!-- shared-head -->` markers. Run `node tool/build.mjs` afterwards.
- **Stickers, logo or fonts changed in the app:**

  ```bash
  cd website/tool && npm install && node media.mjs && node build.mjs
  ```

  New files get new hashed names, and the HTML is updated to match.
- **Preview locally:**

  ```bash
  python3 -m http.server 4173 -d website/public
  ```

  Open `/privacy.html` there. Clean URLs (`/privacy`) only work on Vercel.

## Notes

- Fonts are the app's own (Inter Tight, Instrument Serif, Titan One,
  Luckiest Guy, Baloo 2), subset to Latin and self-hosted as WOFF2. Their
  OFL and Apache licences are in `app/assets/google_fonts/`.
- Motion only runs when the system allows it (`prefers-reduced-motion`):
  - stickers pop in on load;
  - the sticker pile settles as it scrolls into view (scroll-driven
    animation, where supported);
  - a view transition plays between the page and `/privacy`.

  Without motion, everything simply sits in place.
- Corners use `corner-shape: squircle` where the browser supports it, and
  normal rounded corners elsewhere.
- No analytics, cookies or third-party requests. The QR code is drawn in
  the browser from the page's own address.
- Peel isn't made by or affiliated with WhatsApp or Meta. The page says so
  and doesn't use WhatsApp's logo.
