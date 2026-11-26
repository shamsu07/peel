# Phase 0 log

Goal (spec §11): prove the risky parts on real devices before building screens.

| # | Question | Status |
|---|---|---|
| 1 | Any 0.5–10 s clip → animated WebP ≤ 480 KB, fast enough on a low-end Android phone | **✅ iPhone 15 Pro: worst case 6.2 s.** Still needs a low-end Android run (Q-E3) |
| 2 | 1 sticker + 2 bonus pack is accepted; adding more updates WhatsApp (Q-E2, Q-E5) | **iOS: ✅ accepted, ❌ no updates (a re-send adds a duplicate pack).** Android not yet tested |
| 3 | Single-file route via WhatsApp's Create sticker (Q-E6) | **iOS: ✅ Copy sticker → paste in a chat arrives as a sticker** (no pack). Animated paste and Android not yet tested |
| 4 | MP4 hand-off keeps its sound in WhatsApp's Create sticker | Not started |

## 26 Nov 2026: WebP engine

**Built**
- **libwebp v1.6.0**, vendored in `app/third_party/libwebp` (official source, commit `4fa21912`). It's compiled for every platform by `app/hook/build.dart` through Dart native assets: no CMake files and no prebuilt binaries. Android builds get 16 KB page alignment automatically.
- **`app/native/peel_webp.c`**: a small C layer, so Dart only passes numbers and pointers.
- **`lib/sticker_engine/`:**
  - the encoder (still and streamed animation, one frame in memory at a time);
  - a WebP inspector that reads RIFF chunks for size, frames and durations;
  - `checkSticker`, the pre-export checklist;
  - the automatic compressors.
- **Animated compressor:**
  - It works down a 12-step ladder from 15 fps / q80 to 1 fps / q10. It predicts sizes to skip steps that won't fit, and steps back up once if it landed well under the target.
  - The full length is never cut.
  - It reports Sharp, Good or Squeezed.
- **Encoder lab:** long-press "Peel." on Home. It runs the real encoder on the phone in a background isolate and shows size, step and time.

**Results on the Mac (tests)**
| Case | Result |
|---|---|
| Detailed still photo | Fits 95 KB |
| 3 s flat cartoon | Fits at the sharpest step |
| 10 s worst case (random grain every frame) | **355 KB at 4 fps / q25, 3 encodes, 4.4 s.** Full 10 s kept |

The worst-case clip is harsher than real footage, because it has new random noise in every frame. Real clips should land at higher frame rates. Confirm with real video once frame extraction exists.

**Still to measure on the reference phone**
- encode time for the 10 s detailed case (budget ≤ 30 s);
- memory use;
- whether the result looks acceptable.

## 26 Nov 2026: WhatsApp bridge

**Built** (matching WhatsApp's official sample, `WhatsApp/stickers` main branch):
- **Dart owns the packs:**
  - `lib/whatsapp/pack_store.dart` keeps the hidden auto-packs in `<app support>/sticker_packs/` with `packs.json` as the index.
  - Still and moving stickers go to separate packs (`peel_still_N`, `peel_moving_N`). A new pack starts at 30.
  - Packs under 3 are filled with **Bonus** stickers, which drop out as the user adds their own and refill after deletes.
  - `image_data_version` goes up on every change.
  - It validates packs before sending: 3–30 stickers, 96×96 PNG tray of 50 KB or less, every sticker passing `checkSticker`, 1–3 emojis.
  - It builds the iOS pasteboard JSON.
- **Bonus stickers** ("okay!" and "haha", still and wiggling versions) are drawn in code for now (`bonus_stickers.dart`). Final artwork comes later.
- **Tray icon** made from the first sticker (`render.dart`). This is also the start of the shared drawing path, so what users see matches what they export.
- **Android** (`android/app/src/main/kotlin/app/peel/peel/`):
  - `StickerContentProvider.kt` serves `metadata`, `stickers` and `stickers_asset/<id>/<file>` with WhatsApp's column names. It only serves files listed in the index, and only WhatsApp (`com.whatsapp.sticker.READ`) can read it.
  - `MainActivity.kt` sends `ENABLE_STICKER_PACK` (chooser when both apps lack the pack) and reports added, cancelled or rejected (with WhatsApp's `validation_error`).
  - `WhatsAppApps.kt` runs the "already added?" check for WhatsApp and WhatsApp Business.
- **iOS** (`ios/Runner/AppDelegate.swift`): the pack JSON goes on the pasteboard under `net.whatsapp.third-party.sticker-pack` (local only, expires in 60 s), then we open `whatsapp://stickerPack`. `LSApplicationQueriesSchemes` includes `whatsapp`.
- **Lab:** a "WhatsApp bridge" section with Make still, Make moving, Send pack, and a log of each result.

**Tests:** 38 of 38 pass. They cover pack rules, bonus fill and refill, the 31st sticker, the iOS payload, how the bridge reads native replies, that invalid packs are never sent, and that bonus stickers and the tray pass WhatsApp's rules. Both platforms build.

**On-phone test script** (answers Q-E2 and Q-E5)
1. Lab → Make still → Send "My Stickers" (1+2). Expect WhatsApp's add dialog. Note the outcome and any `validation_error`.
2. Make still again → **don't send**. Open WhatsApp: does the new sticker appear on its own (Android reads our provider, version bumped)?
3. Send again. Note what WhatsApp shows (an "already added" message, or an update) and count the taps.
4. Repeat with Make moving.
5. iOS: steps 1 and 3 (iOS can't check whether a pack is already added).

## 26 Nov 2026: first iPhone run (iPhone 15 Pro, release build)

**Encoder lab**
| Case | Result | Mac, for comparison |
|---|---|---|
| 10 s cartoon (flat colours) | **367.5 KB in 2.2 s**, 15 fps / q80, 150 frames, 1 encode, "Sharp" | — |
| 10 s detailed (worst case) | **355.4 KB in 6.2 s**, 4 fps / q25, 40 frames, 3 encodes, "Squeezed" | 4.4 s |

- Full 10 s kept in both. Both pass the WhatsApp checklist at our 480 KB target.
- A flagship phone is about 1.4× slower than the Mac. A low-end Android phone may be 4–6× slower than this iPhone, so roughly 25–37 s for the worst case, which is around the 30 s budget. If it's over, lower the libwebp `method` (4 → 2) on slow devices, or cut wasted encodes. To measure on the reference phone.
- A flat-colour 10 s clip stays at full quality, so most real stickers should be "Sharp".

**Bug found and fixed:** the lab's background encoding crashed with "object is unsendable", because a closure created inside widget State captured the State. The isolate entry points are now top-level functions, and `test/features/lab_isolate_test.dart` runs them on a real isolate.

**WhatsApp (iOS)**
- ✅ Make still → Send "My Stickers" (1 of yours + 2 bonus): **the pack arrives in WhatsApp's sticker tray.** WhatsApp on iOS accepts our pasteboard JSON, the bonus fill and the tray icon.
- Still open: what happens when the pack is sent again after adding a sticker (update or duplicate), the moving pack, and all of Android.

## 26 Nov 2026: iOS WhatsApp answers (iPhone 15 Pro)

1. ✅ The first pack shows exactly the user's sticker + "okay!" + "haha" in WhatsApp's tray.
2. ❌ **Q-E2 answered: WhatsApp on iOS does not update packs.** After adding a 2nd sticker and sending "My Stickers" again (same identifier `peel_still_1`, higher `image_data_version`), WhatsApp created a **second "My Stickers" section** containing both sets. iOS hands packs over only through the pasteboard, and WhatsApp doesn't de-duplicate by identifier there.
3. ✅ The moving pack (1 + 2 wiggling bonus stickers) arrives and animates.

**Impact:** the spec's plan of one hidden rolling pack updated on every send works only if Android updates packs (still to test). On iOS every send creates a new pack in WhatsApp, so the "one sticker → send" flow needs a different design on iOS. Options are under review (see the conversation, 26 Nov).

**Lab redesign:** the WhatsApp section now has a Still/Moving switch, one card showing the pack's real stickers (bonus ones tagged), "Make a test sticker", "Send to WhatsApp", an iPhone warning before a duplicate send, and "Clear test packs".

## 27 Nov 2026: one sticker without a pack (iPhone 15 Pro)

- ✅ **Copy sticker, then paste into a WhatsApp chat, sends it as a real sticker.** Peel puts the WebP (as `org.webmproject.webp` and `public.webp`) plus a PNG fallback on the pasteboard. This is the first route that sends a single sticker without a pack or bonus stickers.
- ❌ **Sharing through the share sheet does not.** WhatsApp on iPhone treats any shared image as a photo and fills transparent areas with black. Peel now shares photo stickers on white there ("Share as image"), and stickers with sound as their video with the sound.
- Still to test: pasting a moving (animated) sticker, and the same route on Android.

**Impact:** Copy is now a first-class action on the Ready screen (Save · Copy · Share) and sits second in sticker details, right after Send to WhatsApp.
