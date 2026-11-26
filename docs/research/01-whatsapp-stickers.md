# WhatsApp Stickers: Research for an Ultra-Simple Sticker Maker

_Researched 26 Nov 2026. Sound stickers came out in beta on 25 Nov 2026, so expect the audio parts to change within weeks._

---

## TL;DR: what this means for us

1. **We can export photo stickers and video (animated) stickers to WhatsApp today.** WhatsApp has an official, stable, documented API for third-party apps on both platforms ([WhatsApp/stickers](https://github.com/WhatsApp/stickers)).
2. **We can't export audio stickers from a third-party app yet.** On 24 Nov 2026 a WhatsApp contributor replied on the official repo: *"This API isn't available yet for third party stickers, but it's on our roadmap."* No format, codec, duration or size spec is public ([issue #1163](https://github.com/WhatsApp/stickers/issues/1163)).
3. **Sound stickers are brand new and still in beta.** They're rolling out gradually in Android beta 2.26.47.1 and iOS TestFlight 26.46.10.70, plus a few App Store users. Users make them *inside WhatsApp*: Create sticker → pick a video → add sound (keep the original audio, use a preset effect, import a file, or record a voice note). Sound is muted by default, the recipient taps an icon to play it, and it loops 3×.
4. **Implication:** our two flows split into a part that works now and a part that waits for the API:
   - Photo → sticker ✅ now · Video → animated sticker ✅ now
   - Photo + audio → sound sticker ⏳ blocked on the API · Video + new audio → sound sticker ⏳ blocked on the API
   - **Workaround until the API ships:** our app renders an **MP4 with the chosen audio** (photo + audio, or video + replaced audio). The user then opens it in WhatsApp's own *Create sticker* flow, where WhatsApp keeps the original audio. This is a "hand-off" rather than a one-tap export, but it's legal, uses only public features, and gets the job done today.
5. **Competitive risk:** WhatsApp already has a built-in sticker maker (photo cutout, text, AI generation, and now video + sound). Meta is also building a standalone **"WhatsApp Stickers" app** with Browse, Create and creator publishing (reported 26 Nov 2026, no launch date). Our edge has to be **speed and simplicity**: fewer taps than WhatsApp's own tool, works on all devices, and batches stickers into packs.
6. **Store risk (iOS):** Apple has a long history of rejecting or removing "WhatsApp sticker" apps under **4.3 Spam** and **4.2 Minimum Functionality**. A real *maker* app (create, edit, organise) is fine. A static pack-only app is not.

---

## 1. Sticker types in WhatsApp (as of Nov 2026)

| Type | Source | Third-party export? | Notes |
|---|---|---|---|
| Static | Image | ✅ Yes | WebP, 512×512, ≤100 KB |
| Animated | Animated image / video | ✅ Yes | Animated WebP, 512×512, ≤500 KB, ≤10 s |
| Sound sticker (new) | Video + audio track | ❌ Not yet ("on our roadmap") | Created in WhatsApp's own editor. Format not public |
| Custom/"Create sticker" (in-app) | Photo, AI prompt, video | n/a (it's WhatsApp's own tool) | Cutout, text, drawings. Saved to user's stickers |
| AI stickers | Text prompt (Meta AI) | n/a | Built into WhatsApp |

---

## 2. Technical spec for third-party sticker packs (official)

Source: `Android/README.md` and `iOS/README.md` in [github.com/WhatsApp/stickers](https://github.com/WhatsApp/stickers). The Android README was last changed 17 Apr 2025.

### 2.1 Sticker images
| Rule | Static | Animated |
|---|---|---|
| Canvas | **exactly 512×512 px** | **exactly 512×512 px** |
| Format | **WebP**. iOS also accepts PNG in the JSON, but `image_data` is WebP | **Animated WebP only** |
| Max file size | **≤ 100 KB** (typical ≈ 15 KB) | **≤ 500 KB** |
| Background | Transparent | Transparent |
| Frame duration | — | **≥ 8 ms** per frame |
| Total duration | — | **≤ 10 s** |
| First frame | — | Must be the *complete* sticker. WhatsApp stops the animation on frame 1 after looping |
| Recommended | 8 px white (#FFFFFF) outline stroke so it reads on any chat background | same |

### 2.2 Pack rules
- **3 to 30 stickers** per pack.
- **1 to 10 packs** per app (Android README).
- A pack is **all static or all animated, never mixed**. Set `animated_sticker_pack: true` for animated packs.
- **Tray icon:** static, **96×96 px, ≤ 50 KB**, PNG on iOS.
- `identifier`: unique, < 128 chars, `[a-zA-Z0-9_\-. ]`.
- `name`, `publisher`: ≤ 128 chars each.
- `emojis`: up to 3 per sticker. Plan for **at least 1**; the SDK enforces this since 2020.
- `accessibility_text` (optional): ≤ 125 chars static, ≤ 255 animated. US English, present tense, no emoji.
- `image_data_version` (Android): bump this string whenever a pack's stickers change, so WhatsApp refreshes them. `avoid_cache` has been ignored since WhatsApp 2.25.9.78; WhatsApp now always caches.
- Optional links (must start with http/https): `android_play_store_link`, `ios_app_store_link`, `publisher_website`, `privacy_policy_website`, `license_agreement_website`.
- **Each pack needs its own "Add to WhatsApp" button.** Don't build an "add all packs" button.

> **Product implication:** a user's "pack" must reach 3 stickers before it can be exported. For "make one sticker and send it", we need to either auto-fill a pack (e.g. 3 variants: cutout, cutout + outline, cutout + text) or keep a rolling "My Stickers" pack that the user adds to. A rolling pack that we keep updating via `image_data_version` is the simplest UX.

### 2.3 Android integration
- Expose packs via a **ContentProvider**:
  - `android:exported="true"`, `android:readPermission="com.whatsapp.sticker.READ"`
  - URIs: `<authority>/metadata`, `/metadata/<pack_id>`, `/stickers/<pack_id>`, `/stickers_asset/<pack_id>/<file>` (returns an `AssetFileDescriptor`)
  - Files can be served from internal storage, which is how user-created stickers work, not just from bundled assets.
- **Add a pack:** `Intent("com.whatsapp.intent.action.ENABLE_STICKER_PACK")` with extras `sticker_pack_id`, `sticker_pack_authority`, `sticker_pack_name`. Launch with `startActivityForResult`. The user confirms in a WhatsApp dialog.
- **Check whether a pack is already added:** query `content://com.whatsapp.provider.sticker_whitelist_check/is_whitelisted?authority=…&identifier=…`, read column `result` (1 = added). For WhatsApp Business, use `com.whatsapp.w4b.provider.sticker_whitelist_check`. Packs can be added to either app or both.
- Play Store: put **"WAStickerApps"** in the description so WhatsApp's "get more stickers" search can find us.

### 2.4 iOS integration
- Build a JSON payload: `identifier`, `name`, `publisher`, `tray_image` (base64 PNG), `stickers[]` (`image_data` base64 WebP, `emojis`, `accessibility_text`), `animated_sticker_pack`, links.
- Put it on **`UIPasteboard`**, then open **`whatsapp://stickerPack`**. WhatsApp reads the pasteboard and shows a preview. **One pack at a time.**
- Add `whatsapp` to `LSApplicationQueriesSchemes` in Info.plist, so the app can check WhatsApp is installed.
- The sample uses `WebP.framework` and YYImage for WebP. Modern alternative: libwebp via SPM, e.g. SDWebImageWebPCoder.
- The bundle ID must not contain `WA.WAStickersThirdParty`. Add the keyword **`WAStickers`** in App Store Connect.
- You need a **real device** to test; the simulator has no WhatsApp.
- Cross-platform wrappers exist, e.g. `react-native-whatsapp-stickers` on npm and similar Flutter plugins. They are thin wrappers over the steps above, and the native logic is small enough to own ourselves.

### 2.5 Naming and branding rules
- **Don't use "WhatsApp" in the app name** or in the store's name field. Mentioning it in the description is fine; write it as "WhatsApp". This applies on both stores.
- Stickers must be legal, authorized and acceptable under the WhatsApp Terms of Service. This matters for user uploads: copyrighted characters and celebrity photos are a moderation and DMCA concern if we ever add sharing.

---

## 3. Sound stickers (new, Nov 2026)

**Status:** beta / gradual rollout. Android beta 2.26.41.3 had it hidden; 2.26.47.1 is rolling it out. iOS TestFlight 26.46.10.70 and some App Store users have it. No official Meta announcement or GA date yet. Sources: WABetaInfo [Android](https://wabetainfo.com/whatsapp-is-rolling-out-new-sound-sticker-messages-on-android/) and [iOS](https://wabetainfo.com/whatsapp-is-rolling-out-sticker-messages-with-audio-on-ios/), [9to5Mac](https://9to5mac.com/2026/11/25/whatsapp-testing-stickers-with-audio-including-make-your-own-option/) and [Android Headlines](https://www.androidheadlines.com/2026/11/whatsapp-testing-sound-stickers-android-beta.html), all dated 25 Nov 2026.

**How it works (confirmed across sources):**
- It's built on animated stickers. Creation: sticker keyboard → **Create sticker** → choose a **video** → WhatsApp converts it to an animated sticker → **audio button** in the editor.
- Audio options: keep the video's original sound, **preset effects** (e.g. "Evil Laugh", "Crickets", "Cat Purr"), **import an audio file**, or **record a voice note**. iOS has a preview step.
- Playback: **muted by default**. A small speaker icon on the sticker plays it on tap; it **loops 3 times** and stops.
- Sticker and audio are end-to-end encrypted (WABetaInfo).

**Unknown / not public:**
- The file format or container: whether audio is embedded with the WebP, a separate file, or MP4. WABetaInfo only says WhatsApp is "developing a new format".
- Maximum audio length and size limits.
- Whether a **static photo** can carry sound. Only one source (Android Headlines) suggests it; WABetaInfo describes video only.
- How older WhatsApp versions render a sound sticker. Most likely as a silent animated sticker, but unconfirmed.
- Third-party API: **not available; "on our roadmap"** ([issue #1163](https://github.com/WhatsApp/stickers/issues/1163), opened 24 Nov 2026, status "Backlog").

**What we should do:**
- Design the data model so a sticker can *optionally* have an audio track (`audioUri`, `audioStartMs`, `audioDurationMs`). Then exporting to the future API is just a new exporter.
- **Watch issue #1163 and the repo** for the spec. Being one of the first apps to support third-party sound stickers is our launch-timing opportunity.
- Meanwhile, ship the **MP4 hand-off**: render `photo + audio` → short MP4 (e.g. a gentle zoom/wiggle over the still, ≤10 s), or `video + replaced audio` → MP4. Then "Save & open in WhatsApp" with guided steps: Create sticker → pick the video → keep original sound. The audio ships inside the MP4, so the user just keeps it.
- Keep clips **≤ 10 s**, matching the animated-sticker limit, until real limits are known. Shorter is better: the sound loops 3×, so 2–4 s clips are the natural fit.
- **Hand-off must go via the gallery, not the share sheet.** Sharing an MP4 to WhatsApp sends it as a *video message*, not a sticker. The flow is: our app saves the MP4 to Photos/Gallery → the user opens a chat → sticker tray → Create sticker → picks that video → keeps the original sound. For photo + audio, a still-image MP4 (image held for the audio's length) is enough; motion is optional.
- **Why audio can't simply ride inside the WebP:** the WebP container has no audio stream. So whatever WhatsApp uses for sound stickers is a new wrapper or a separate file. Guesses include an MP4 or a metadata sidecar; this is unconfirmed. Don't reverse-engineer it. Wait for the published spec.

---

## 4. Other ways to get stickers into WhatsApp (and why the pack API wins)

| Route | Works? | Comment |
|---|---|---|
| Official pack API (ContentProvider / pasteboard) | ✅ | The only route that adds stickers to the tray. Needs ≥3 per pack |
| WhatsApp's own "Create sticker" from a photo or video the user picks | ✅ | A good hand-off target for sound stickers until the API exists |
| iOS system stickers (iOS 17+ "Add Sticker" from Photos) then drag into WhatsApp | ⚠️ partly | Works for cutouts via Apple's subject lift. Not controllable by our app |
| Share a .webp via the share sheet / `ACTION_SEND` | ⚠️ unreliable | Usually sends as an image or document, not a sticker. Don't rely on it |
| Clipboard paste of a sticker | ⚠️ unverified | Not confirmed for third-party content |

---

## 5. Competition

- **WhatsApp's built-in creator.** Photo → cutout/text/drawing, AI-generated stickers, and now video + sound. It's free and has zero install friction. This is our main competitor.
- **"WhatsApp Stickers" standalone app (in development).** Tabs: Browse, Search, Yours, Create, Profile. Creators publish packs publicly after manual review, and get an Insights dashboard. No launch date ([Beebom, 26 Nov 2026](https://gadgets.beebom.com/news/whatsapp-standalone-stickers-app-coming-soon), citing WABetaInfo). If it launches, *distribution* of packs moves into Meta's app; *creation tools* stay our playground.
- **Third-party makers:** Sticker.ly, Sticker Maker (several apps share this name), Personal Sticker Maker (iOS), WASticker Maker, plus Picsart, Photoroom and Canva tools. Typical features: one-tap background removal, text, animated GIF/video → sticker, watermark on the free tier, ads. Most are ad-heavy and full of extra steps.

**Where we can win:** "3 taps to a sticker in WhatsApp". That means auto cutout, an auto-built pack, and a single Add button, with no account, no watermark and few ads. Add sound before anyone else once the API lands.

---

## 6. Tech notes for building it

- **Background removal (on-device, free):**
  - Android: **ML Kit Subject Segmentation** (`play-services-mlkit-subject-segmentation`, API 24+). The model downloads via Play services (~200 KB app-size impact), and the first use may wait for that download.
  - iOS 17+: **Vision `VNGenerateForegroundInstanceMaskRequest`**, the same subject-lift tech WhatsApp uses on iPhone. Older iOS versions need a fallback (manual crop, or a small segmentation model).
- **Encoding:**
  - Static: resize/fit into 512×512 with transparent padding, add the optional white outline, encode WebP. Lower quality in a loop until ≤100 KB. Tray icon: 96×96 PNG ≤50 KB.
  - Animated: video → frames → animated WebP at 512×512, **≤500 KB**, ≤10 s. In practice: default to a **1–3 s** trim (allow up to ~6 s) at 10–15 fps, then a quality/fps/duration step-down loop until it fits. The first frame must look complete. Hitting 500 KB reliably is the hardest engineering problem in the app.
  - **Validate before export, with a safety margin.** WhatsApp rejects the whole pack if any one file breaks a rule, even by 1 byte. Target e.g. ≤95 KB / ≤480 KB, and re-check dimensions, frame durations, tray icon and sticker count on-device before calling the add-pack API.
  - Tools: libwebp (`WebPAnimEncoder`) natively on both platforms, or FFmpeg.
- **FFmpegKit warning:** the original `arthenica/ffmpeg-kit` was **retired and archived in 2025**. Community forks exist, but check maintenance and licensing (LGPL/GPL builds) before depending on one. Prefer platform APIs (MediaCodec/Media3 Transformer on Android, AVFoundation on iOS) for decode, trim and audio-replace, plus libwebp for encoding.
- **Audio replace / MP4 hand-off:** Android Media3 `Transformer` (with an audio track swap via a composition), iOS `AVMutableComposition` + `AVAssetExportSession`. Both are native and free.
- **Testing:** needs real devices with WhatsApp (and WhatsApp Business) installed.

---

## 7. App store policy notes

- **Apple:** strict review. WhatsApp's own README says an app that *only exports* stickers is likely to be rejected. Since 2018 there have been many **4.3 Spam** (same feature set as other apps) and **4.2 Minimum Functionality** rejections and removals of WhatsApp sticker apps. Mitigation: a real creation tool with a unique UI and no copy of the sample app; one app, not many clones; useful even without WhatsApp, e.g. save to Photos/Files or export to other apps.
- **Google Play:** fewer reported problems. Still avoid "WhatsApp" in the title or icon (impersonation and IP policies) and keep the content policy clean.
- **Ads later:** budget for a privacy policy and consent flows (UMP/ATT) from day one, since the pack metadata can link a `privacy_policy_website` anyway.

---

## 8. Open questions to track

1. The third-party sound-sticker API: format, limits, static support ([issue #1163](https://github.com/WhatsApp/stickers/issues/1163)).
2. The WhatsApp Stickers standalone app's launch, and whether third-party apps can publish into it.
3. What older WhatsApp clients do with sound stickers.
4. Which framework we build in: native (Kotlin + Swift) vs Flutter/React Native. The heavy work (segmentation, WebP encoding, media transform) is native either way.
5. **Where processing runs: on-device or a cloud backend (FFmpeg on a server).** Recommendation: **on-device**. It costs nothing per sticker, which suits a free/ads app. It works offline, user photos never leave the phone (simpler privacy policy, no upload of faces), and every step has a native on-device tool (ML Kit/Vision, Media3/AVFoundation, libwebp). Keep a server only as a possible later fallback for low-end devices that can't hit 500 KB in reasonable time.
6. **MVP scope:** stick to the public API (static + animated) only, or also build the audio editing + MP4 hand-off now? Recommendation: build the audio data model and the MP4 hand-off in the MVP. It's cheap with native media APIs, it's the headline feature, and it puts us first in line when the sound API ships.

---

## Appendix: cross-check with a parallel Gemini research run (26 Nov 2026)

The two runs agree on everything material: the specs and limits, sound stickers being in-app only and beta, the third-party API not existing yet, the MP4 hand-off workaround, and Apple's minimum-functionality risk. Corrections and clarifications to the Gemini version:
- **"Android uses an Intent to broadcast the pack data"**: partly wrong. The Intent only *names* the pack (id, authority, name). WhatsApp then *pulls* metadata and files from our **ContentProvider** (see §2.3).
- **"PNG or GIF will be rejected"**: GIF is rejected, but the iOS JSON path accepts PNG data for static stickers (and the tray icon *must* be PNG). Using WebP everywhere is still the safe default.
- **"Share the MP4 to WhatsApp directly to trigger the sound sticker"**: sharing sends a normal video. The MP4 must be picked from the gallery inside WhatsApp's *Create sticker* (see §3).
- **Apple guideline**: Gemini cites 4.2 (Minimum Functionality). Developer reports show **4.3 Spam** is at least as common for sticker apps (see §7). Both apply.
- **WhatsApp "likely uses a proprietary wrapper or hidden MP4"**: a plausible guess, still unconfirmed.

Useful additions taken from it: the 1–3 s default trim, the safety margin on file sizes, the note that WebP has no audio stream, and the two open decisions (on-device vs cloud processing; MVP scope).

---

## Sources
- WhatsApp/stickers repo: [README](https://github.com/WhatsApp/stickers), [Android README](https://github.com/WhatsApp/stickers/blob/main/Android/README.md), [iOS README](https://github.com/WhatsApp/stickers/blob/main/iOS/README.md), [Issue #1163: audio stickers for third parties](https://github.com/WhatsApp/stickers/issues/1163)
- WABetaInfo: [sound stickers on Android](https://wabetainfo.com/whatsapp-is-rolling-out-new-sound-sticker-messages-on-android/), [on iOS](https://wabetainfo.com/whatsapp-is-rolling-out-sticker-messages-with-audio-on-ios/)
- [9to5Mac, 25 Nov 2026](https://9to5mac.com/2026/11/25/whatsapp-testing-stickers-with-audio-including-make-your-own-option/) · [Android Headlines, 25 Nov 2026](https://www.androidheadlines.com/2026/11/whatsapp-testing-sound-stickers-android-beta.html)
- [Beebom: standalone WhatsApp Stickers app](https://gadgets.beebom.com/news/whatsapp-standalone-stickers-app-coming-soon)
- [TechCrunch: WhatsApp sticker maker](https://techcrunch.com/?p=2650846) · [MacRumors: custom WhatsApp stickers on iPhone](https://www.macrumors.com/how-to/make-custom-whatsapp-stickers-iphone/)
- Apple forums: [WhatsApp sticker apps rejected](https://developer.apple.com/forums/thread/110592), [sticker packs tagged as spam](https://developer.apple.com/forums/thread/110639) · [Apple removes WhatsApp sticker apps (2018)](https://www.thejakartapost.com/life/2018/11/19/apple-removes-whatsapp-sticker-apps-for-violating-guidelines.html)
- [ML Kit Subject Segmentation](https://developers.google.com/ml-kit/vision/subject-segmentation/android) · [FFmpegKit retirement](https://dev.to/lucquebec/ffmpegkit-is-retired-heres-how-to-fix-your-android-build-ndk-r26c-patch-35j0)
