# ADR-001: Mobile framework and tech stack

**Status:** Accepted (26 Nov 2026)
**Date:** 26 Nov 2026
**Deciders:** Product owner and engineering lead
**Inputs:** [MVP spec](../spec/01-mvp-spec.md) · [WhatsApp research](../research/01-whatsapp-stickers.md) · [UI design canvas](https://claude.ai/artifact/5f2WobZ1bTBLRSUs4y3aQs)

## Context

We're building one free sticker-maker app for **Android and iOS** (spec Q-E1). The constraints that shape this decision:

1. **The look is custom and detailed.** The design has die-cut white edges, tilted sticker cards, a "peeling" animation, sticker-style text with outlines, and pastel ink pairs. Nothing in it uses stock Material or iOS components. It must look identical on both platforms.
2. **The heavy lifting is native media work, whatever framework we pick:**
   - Subject cut-out: ML Kit on Android, Vision (iOS 17+) on iOS.
   - Video decode and trim, and MP4 export with replaced audio: Media3 on Android, AVFoundation on iOS.
   - Animated WebP encoding under 500 KB: libwebp, a C library.
   - Audio recording.
   - The WhatsApp export bridge: a ContentProvider plus an Intent on Android, the pasteboard plus a URL scheme on iOS.
   - Saving to the gallery.
3. **What you see must equal what you get.** The sticker preview (cut-out + white edge + sticker text) must be pixel-identical to the 512×512 file we hand WhatsApp. Ideally one rendering path produces both.
4. **Low-end Android is the main audience.** That means 3 GB RAM phones, an app download of 30 MB or less, and fast first launch.
5. **Small team, two platforms, MVP speed.** Roughly 17 screens. Building the UI twice would roughly double the UI effort.
6. **Store rules:**
   - Google Play now requires native libraries to support 16 KB memory pages, which affects libwebp and any media binaries.
   - Apple's 4.2/4.3 review risk is handled by the product itself, not by the framework.

## Decision (proposed)

**Flutter for the app and all UI.** Small native modules handle the platform-specific media and WhatsApp work. **libwebp is called directly from Dart through FFI**, so sticker composition and encoding run the same code on both platforms.

## Options considered

### Option A: Flutter + native modules (recommended)
| Dimension | Assessment |
|---|---|
| Complexity | Medium. One UI codebase plus about 6 small native modules |
| Cost | Lowest for a small team |
| Visual fidelity | Excellent. Flutter draws every pixel itself, so the die-cut look is identical on both platforms |
| Performance on low-end Android | Good. Compiled ahead of time, with the Impeller renderer |
| App size | About +5–7 MB over native. Fits the 30 MB budget |
| Team familiarity | **Unknown: see below** |

**Pros**
- **The same rendering code makes the preview and the final file.** `dart:ui` Canvas draws the sticker (image, white edge, outlined text) on screen and can draw the same thing off-screen at 512×512, so what users see is exactly what WhatsApp gets.
- **One encoder for both platforms.** libwebp's animated encoder (`WebPAnimEncoder`) through `dart:ffi` gives the size-limit loop (P0-2) a single implementation and single tests.
- Strong animation tools for the "peeling" moment and the micro-interactions in the design.
- Mature packages for the boring parts: image picking, camera, audio recording, gallery saving, local database.

**Cons**
- Each platform needs one native folder (Kotlin and Swift): segmentation, video frames, MP4 export, the WhatsApp bridge. Its size is the same in every option.
- Dart is less common than JavaScript or Kotlin when hiring.
- Platform text input and accessibility need explicit testing. They're good, but not "free".

### Option B: React Native (Expo, New Architecture) + native modules
| Dimension | Assessment |
|---|---|
| Complexity | Medium |
| Cost | Low |
| Visual fidelity | Good, but uses real platform views, so small differences between Android and iOS need fixing |
| Performance on low-end Android | Good with Hermes and Reanimated. More care needed in long sticker grids |
| App size | About +7–10 MB |
| Team familiarity | Likely higher if the team knows JS/TS |

**Pros**
- JavaScript/TypeScript, the biggest hiring pool.
- The Expo Modules API makes Kotlin and Swift modules pleasant to write.
- Over-the-air JS updates through EAS let us fix copy and UI bugs without a store release.

**Cons**
- Matching the preview to the final file needs react-native-skia for off-screen rendering. That's doable, but it's a second rendering system beside React views.
- libwebp would have to sit behind a native module on each platform (C++ via JSI). It isn't a single shared call.
- Heavier JS bundle and bridge, so the low-end performance budget is tighter.

### Option C: Fully native (Kotlin + Compose, Swift + SwiftUI)
| Dimension | Assessment |
|---|---|
| Complexity | High. Everything is built twice |
| Cost | Highest, roughly 1.7–2× the UI effort |
| Visual fidelity | Excellent, but the two copies must be kept in sync by hand |
| Performance / size | Best |
| Team familiarity | Needs both Android and iOS specialists |

**Pros:** best size and performance; direct access to every API; no framework risk.
**Cons:** two codebases for ~17 custom screens; design changes cost twice; slowest to MVP.

### Option D: Kotlin Multiplatform + Compose Multiplatform
| Dimension | Assessment |
|---|---|
| Complexity | Medium-high |
| Cost | Medium |
| Visual fidelity | Good |
| Maturity on iOS | Newer. Fewer ready-made libraries for camera, media and pickers on iOS |
| Team familiarity | Good if the team is Android-first |

**Pros:** direct Kotlin on Android, shared logic and UI, native interop.
**Cons:** the iOS side has less tooling and fewer libraries. Our heaviest iOS work (Vision, AVFoundation, pasteboard) would still be Swift, so we'd gain less sharing than it seems.

## Trade-off analysis

All four options need the **same native media and WhatsApp code**: about six modules per platform. The real differences are:

- **(a)** how cheaply we build ~17 custom, design-heavy screens once;
- **(b)** whether the sticker preview and the exported file come from one renderer;
- **(c)** whether the size-limit encoder can be one shared implementation.

**Flutter wins on all three:** one UI, `dart:ui` Canvas for both preview and export, and libwebp through FFI.

React Native is a close second and the right choice **if the team is strongly JS/TS**. The cost is a Skia layer and per-platform libwebp wiring. Fully native is the quality ceiling but doubles UI cost for an MVP. KMP is promising, but less proven on iOS for a media-heavy app today.

**The one input that could flip this is team skills.** A JS/TS-only team should pick React Native (Expo). A team with no Dart, JS or mobile experience should still pick Flutter.

## The stack (if accepted)

| Area | Choice | Notes |
|---|---|---|
| Framework | **Flutter** (current stable), Dart 3 | Impeller on both platforms |
| Min OS | Android 7.0 (API 24), iOS 17 | From the spec: ML Kit and Vision floors |
| State management | **Riverpod** | Testable, no boilerplate |
| Navigation | **go_router** | Covers the clickable flow in the design |
| Local data | **Drift** (SQLite) | Stickers, packs, edit settings (spec §7 data model) |
| Files | App documents folder | Originals, rendered WebP, MP4 hand-offs |
| Sticker rendering | `dart:ui` Canvas, off-screen at 512×512 | Cut-out, white edge, sticker text: same code as the preview |
| WebP encoding | **libwebp via `dart:ffi`** (static and animated) | Built for Android (CMake/NDK, **16 KB page aligned**) and iOS (xcframework) |
| Subject cut-out | Android: **ML Kit Subject Segmentation** · iOS: **Vision `VNGenerateForegroundInstanceMaskRequest`** | Native module `segmenter` |
| Video frames and trim | Android: **Media3** (frame extraction / MediaCodec) · iOS: **AVFoundation** (`AVAssetImageGenerator`) | Native module `video_frames` |
| MP4 hand-off (photo + audio, video + new audio) | Android: **Media3 Transformer** · iOS: **AVMutableComposition + AVAssetExportSession** | Native module `handoff_exporter`. No FFmpeg |
| WhatsApp export | Android: **ContentProvider + `ENABLE_STICKER_PACK` intent + whitelist check** · iOS: **pasteboard + `whatsapp://stickerPack`** | Our own native module `wa_bridge`, owned and tested by us rather than a third-party plugin |
| Audio recording / playback | `record`, `just_audio` | Mic permission requested just in time |
| Pickers / camera | `image_picker` (photo, video, camera) | |
| Save to gallery | `gal` | |
| Fonts | Bundled: Inter Tight, Instrument Serif, Titan One, Luckiest Guy, Baloo 2 | All free licences. Bundled, so they work offline. **Watch the size** |
| Crash + analytics | **Firebase Crashlytics + Analytics**, with no media or file names | AdMob later plugs into the same setup. The privacy line on Home stays true (spec P0-9) |
| Testing | Dart unit tests (validator, compressor loop, pack logic) · golden tests for screens · `integration_test` on real devices with WhatsApp | Phase 0 spike runs on the reference low-end phone |
| CI/CD | GitHub Actions (tests, lint) + **Fastlane** for store builds | Codemagic is an alternative for iOS builds without a Mac runner |

**Project layout (proposed)**
```
app/                      Flutter app
  lib/
    features/             home, create, photo_editor, video_editor, text, sound, export, library
    core/                 design system (tokens, die-cut widgets), routing, db
    sticker_engine/       composition (dart:ui), validator, compressor loop, libwebp FFI
  android/                Kotlin: segmenter, video_frames, handoff_exporter, wa_bridge (+ ContentProvider)
  ios/                    Swift: segmenter, video_frames, handoff_exporter, wa_bridge
native/libwebp/           pinned libwebp source + build scripts (Android CMake, iOS xcframework)
docs/                     research, spec, design, adr
```

## Consequences

- **Easier:**
  - The design ships once, and design changes cost once.
  - The preview always matches the exported sticker.
  - The compressor and validator are one codebase with one test suite.
- **Harder:**
  - We maintain native code on both platforms: about 4 modules each, plus libwebp builds.
  - Needs one person comfortable with Kotlin and Swift for those modules.
  - Flutter upgrades must be tracked.
- **Revisit:**
  - If Phase 0 shows Dart-side frame handling is too slow or memory-hungry for 10 s clips on the reference phone, move the whole animated-encode loop into native code (still libwebp), keeping the same API.
  - If the team turns out to be JS-only, switch to Option B before Phase 1.

## Action items

1. [x] Confirm team skills, then accept or flip this ADR. Accepted: Flutter.
2. [ ] Phase 0 spike, Flutter app skeleton:
   - libwebp through FFI on both platforms;
   - encode a 10 s clip at 480 KB or less on the reference phone;
   - add a 1+2-bonus pack to WhatsApp and update it (Q-E2, Q-E5);
   - MP4 hand-off kept with sound in WhatsApp's Create sticker.
3. [ ] Pick the reference low-end Android phone (Q-E3).
4. [ ] Set up the repo, CI and the design tokens from the canvas style guide.
