# MVP Spec: Ultra-Simple Sticker Maker for WhatsApp (Android + iOS)

_Draft v0.1 · 26 Nov 2026 · Based on [research](../research/01-whatsapp-stickers.md)_

**Decisions already made:** all processing happens **on-device** (no backend), and **sound stickers ship in the MVP** through an MP4 hand-off to WhatsApp's own "Create sticker" until WhatsApp opens its third-party sound-sticker API.

---

## 1. Problem statement

People want stickers of their own photos and clips (friends, pets, kids, memes) in WhatsApp. The existing ways are slow:
- WhatsApp's built-in creator makes one sticker at a time and lacks key options on some devices.
- Third-party makers are cluttered with ads, watermarks, sign-ups and many steps.
- WhatsApp's new **sound stickers** (beta since 25 Nov 2026) can only be made inside WhatsApp from a video. No third-party app helps you prepare them: turning a *photo* plus audio, or a video plus *different* audio, into one takes video-editing skills.

If we don't solve this, WhatsApp's own tool and its upcoming "Stickers" app will absorb the casual market.

## 2. Goals

1. **Speed for a single sticker:** a first-time user gets their **first single sticker** into WhatsApp in **≤ 60 s median** from first app open, with no need to make 3. A returning user needs **≤ 4 taps** after picking media.
2. **Reliability:** **< 1 %** of "Add to WhatsApp" attempts fail because of file or spec problems. Everything is validated before handing to WhatsApp.
3. **Activation:** **≥ 50 %** of new installs create a sticker in their first session, and **≥ 30 %** add a pack to WhatsApp in their first session.
4. **Sound:** **≥ 15 %** of created stickers have audio attached, proving the headline feature has pull before the official API arrives.
5. **Retention groundwork for ads later:** **D7 retention ≥ 15 %** and a store rating of **≥ 4.3**.

## 3. Non-goals (MVP)

| Non-goal | Why |
|---|---|
| Accounts, cloud sync, backend | On-device decision; zero server cost; privacy simplicity |
| Ads / monetisation | Planned later. We only reserve layout space and set up the consent flow (see P1) |
| Public sticker library, browsing or sharing packs with other users | That's moderation, IP and DMCA load, and a different product. Meta is building this ("WhatsApp Stickers" app) |
| Background removal on **video** | Heavy and slow on low-end phones. Square crop is enough for v1 |
| Drawing, multiple text layers, filters, AI generation | Against "ultra simple". WhatsApp's tool already covers drawing and AI |
| Reverse-engineering WhatsApp's sound-sticker format | Fragile and policy-risky. We wait for the official API |
| Telegram / Signal export | P2, after the WhatsApp loop is proven |

## 4. Users

- **Casual sender (primary):** heavy WhatsApp user, often on a mid or low-end Android phone. Wants "my face / my dog as a sticker" now, with no learning.
- **Group joker:** makes reaction stickers from clips, wants funny audio on them, and sends them in group chats.
- **Returning collector:** keeps adding to their own packs over weeks.

## 5. Core flows

```
Home (my packs) ──[+]──► Pick: Photo | Video
   Photo ─► Auto cut-out ─► Adjust (cut-out/full, crop) ─► (Sound?) ─► Save
   Video ─► Trim (up to 10 s) ─► Square crop ─► Sound: original/replace/mute ─► Save
Save ─► auto-compress + validate ─► sticker lands in a hidden auto-pack ─► "Add / Send to WhatsApp" (one tap)
          └─ if it has sound ─► "Make it a sound sticker" hand-off guide
```

### 5.1 Single stickers first; packs stay invisible

**Product principle:** the user thinks in **stickers, not packs.** Most users will make one sticker, send it, and leave, so making one sticker and sending it is the primary flow.

**The constraint:** WhatsApp's third-party API only accepts *packs* of 3 to 30 stickers. There is no single-sticker import. Static and animated stickers can't share a pack. We can't change this, so we hide it.

**How "one sticker" works:**
1. **Hidden rolling packs.** Each user has two packs managed in the background: **"My Stickers"** (static) and **"My Animated"** (animated). When one reaches 30, a new one starts ("My Stickers 2"). The UI never asks the user to create, choose or fill a pack.
2. **The first sticker is sendable immediately.** While a pack has fewer than 3 of the user's own stickers, we **fill the gap with 1–2 "bonus" stickers** that we design and own: generic, useful reactions like "okay!" and "haha". They are **not shown in My stickers** (handled automatically) and are **automatically replaced** as the user makes their 2nd and 3rd stickers. So the very first sticker shows one button, **"Add to WhatsApp"**, and works.
   - Bonus stickers carry our app's style and are seen when sent, which is light organic discovery. They must feel like a gift, not a watermark or ad.
3. **Later stickers need no pack step.** Once the pack is in WhatsApp, each new sticker is **added to the same pack and pushed as an update**:
   - Android: we bump `image_data_version`, and WhatsApp refreshes from our ContentProvider. Whether this happens without a re-add tap is to be verified in Phase 0.
   - iOS: we re-send the pack, which is one tap plus WhatsApp's own preview confirmation (behaviour to verify in Phase 0, Q-E2).
   - The button label after saving is **"Add to WhatsApp"** the first time and **"Send to WhatsApp"** after that. The user never sees the word "pack" in the main flow.
4. **Alternative single-file route (spike, not committed):** save the finished sticker image to Photos and hand off to WhatsApp's own *Create sticker* → "use a photo". This would avoid packs entirely, but takes more taps and depends on WhatsApp keeping our transparent cut-out as-is. Phase 0 tests it. If it works well, it becomes a secondary "Just this one" option.
5. A **packs screen** for organising (rename, reorder, split into themed packs) exists only as a P1 power-user feature.

## 6. Requirements

### P0: must-have

**P0-1 Photo → static sticker**
- Pick from gallery or take a photo with the camera.
- Automatic subject cut-out (Android: ML Kit Subject Segmentation · iOS 17+: Vision foreground mask). A toggle switches between cut-out and full image. A simple square crop with pinch/pan is available.
- An 8 px white outline is on by default, with a toggle.
- Output is WebP, 512×512, transparent, **≤ 95 KB** (safety margin under 100 KB).
- Acceptance:
  - [ ] Given a photo with a clear subject, when picked, then a cut-out preview appears in ≤ 3 s on the reference low-end device (Q-E3).
  - [ ] If segmentation finds no subject or the model isn't downloaded yet, the app falls back to the full image with a non-blocking hint. It never blocks the user.
  - [ ] Saved files always pass the validator (P0-6).

**P0-2 Video → animated sticker**
- Pick a video from the gallery. Users get the **full 10 s that WhatsApp allows**. The trim defaults to the whole clip, up to 10 s. A square crop with pan is available.
- Output is animated WebP, 512×512, **≤ 480 KB**, frames ≥ 8 ms, and a first frame that shows the full sticker.
- **Automatic compressor:** the user never has to fix size themselves. The encoder runs a step-down loop until the file fits:
  1. Lower the quality.
  2. Lower the frame rate: 15 → 12 → 10 → 8 → 6 fps.
  3. Shrink the content inside the 512 canvas, and reduce colours.
  4. Drop frames as a last resort.

  Because frames can always be dropped, **it always produces a valid sticker.** It never fails and never cuts the user's chosen length.
- **Honest size notice:** when compression lowers quality noticeably, show a short, friendly message under the preview, for example: _"WhatsApp limits animated stickers to 500 KB, so we compressed this one to fit. Shorter clips look sharper."_ Offer an optional "Shorten for better quality" action. It's information, not a blocker: **Add to WhatsApp stays enabled.**
- **Live quality hint in the trimmer:** as the user drags the trim length, a label shows the expected result (**Sharp / Good / Compressed**). People can choose between length and quality before encoding.
- Expectation to set with design: 500 KB over 10 s is about 50 KB per second. A 10 s sticker will be visibly softer and choppier than a 3 s one. That's WhatsApp's limit, and the notice explains it.
- Acceptance:
  - [ ] A 10 s 1080p clip encodes in ≤ 30 s on the reference low-end device (≤ 15 s for a 3 s clip), with visible progress and a cancel button.
  - [ ] Every clip from 0.5 to 10 s produces a sticker that passes the validator. Test with fast-motion, high-detail footage as the worst case.
  - [ ] The size notice appears only when quality was reduced below "Good", never for clips that fit easily.

**P0-3 Sound on stickers (in-app)**
- Any sticker can carry one audio track:
  - Video: **keep original**, **mute**, or **replace**.
  - Photo: **add** or **none**.
- Audio sources: **pick an audio file** (Files / media library) or **record a voice clip** in the app (needs the mic permission).
- Audio length:
  - Video: equals the clip length.
  - Photo: user-chosen, 1–10 s, default 3 s.
  - A draggable window selects which part of a longer audio file is used.
- In the app, sound stickers show a 🔊 badge and play their audio on tap, mimicking WhatsApp: muted by default, tap to play.
- Acceptance:
  - [ ] Recording works offline. Denying mic permission still leaves "pick a file" available.
  - [ ] Audio formats accepted on input include at least m4a/aac, mp3, wav and ogg/opus (WhatsApp voice notes).

**P0-4 Add to WhatsApp (silent stickers)**
- Android:
  - A ContentProvider serves the packs from internal storage.
  - The `ENABLE_STICKER_PACK` intent adds a pack.
  - A whitelist check covers **WhatsApp and WhatsApp Business**. The button reads "Added ✓" or "Add", per app.
  - `image_data_version` is bumped on every change so WhatsApp refreshes the pack.
- iOS:
  - Pasteboard JSON plus `whatsapp://stickerPack`, one pack per tap.
- Every sticker gets ≥ 1 emoji automatically: 😀 by default; choosing your own is P1.
- The tray icon is generated from the pack's first sticker: 96×96 PNG, ≤ 50 KB.
- Acceptance:
  - [ ] If WhatsApp isn't installed: show a clear message with a store link. No crash.
  - [ ] After adding a sticker to an already-added pack, re-adding updates WhatsApp's copy. _iOS update behaviour must be verified in a spike; see Q-E2._

**P0-5 Sound-sticker hand-off ("Make it a sound sticker")**
- For stickers with audio, render an **MP4 (H.264 + AAC, square 720×720, ≤ 10 s)**. WhatsApp's own size and length limits for sound stickers are unpublished; adjust once known:
  - Photo: the still sticker image (cut-out on white or on its own background, Q-D3) held for the audio's length.
  - Video: the cropped clip with the chosen audio muxed in.
- Save the MP4 to Photos / Gallery in a "Stickers" album. Then show a **3-step guide** with illustrations: open a chat → sticker tray → **Create sticker** → pick this video → keep its sound. An **"Open WhatsApp"** button launches WhatsApp.
- The guide includes a note: "Sound stickers are still rolling out in WhatsApp. If you don't see the sound option yet, update WhatsApp — your sticker is saved."
- Also put the silent version in the normal pack, so the sticker is usable either way.
- Acceptance:
  - [ ] The MP4 plays with audio in the phone's gallery app and imports into WhatsApp's Create sticker. Test on current WhatsApp stable and beta, both platforms.
  - [ ] Never send the MP4 through the share sheet to a chat, because that sends a video message, not a sticker.

**P0-6 Pre-export validator** (runs on save and before every Add)
- Checks:
  - 512×512 canvas.
  - WebP format.
  - Size limits: static ≤ 95 KB, animated ≤ 480 KB, tray icon ≤ 50 KB.
  - Animation: frames ≥ 8 ms and duration ≤ 10 s.
  - Pack contents: 3 to 30 stickers, no static/animated mix, 1 to 3 emojis per sticker.
  - Identifier and name rules.
- **Auto-fix first, explain second.** Every fixable failure is fixed automatically:
  - Oversized file → re-compress.
  - Wrong canvas → re-render.
  - Missing emoji → default 😀.
  - Fewer than 3 stickers → bonus stickers.
  - Mixed pack → route the sticker to the right pack.
  - Pack full → start a new pack.

  When a fix changes what the user sees, mainly a quality drop, show a one-line plain-language reason that names WhatsApp's rule (e.g. "WhatsApp allows max 500 KB per animated sticker"). The user never sees a raw error or a dead end.
- Show the checklist as a small **"Ready for WhatsApp ✓"** badge on the preview. Tapping it lists each rule passed: size, dimensions, length, format.

**P0-7 Save / share outside WhatsApp**
- Save a sticker as PNG or GIF/WebP to Photos and share via the system share sheet. This makes the app useful on its own, which reduces Apple 4.2 / 4.3 risk.

**P0-8 Basics**
- Delete a sticker. Deleting from an added pack updates WhatsApp. If a pack drops below 3, bonus stickers refill it automatically.
- Onboarding: none beyond the system permission prompts, which are asked just in time. The first screen is the big "+".
- Privacy policy page and in-app link. No personal data leaves the device except anonymous analytics and crash reports (see P0-9).
- Store listings: no "WhatsApp" in the app name. Use the keywords `WAStickerApps` (Play) and `WAStickers` (App Store).

**P0-9 Measurement**
- Anonymous event analytics plus crash reporting, for the funnel: open → pick → save → add-to-WA → hand-off started.
- Collect no media, and nothing that identifies users. Provide a consent prompt where the law requires one.
- **Launch checklist item:** the Home screen promises "Your photos never leave your phone". Before launch, verify that no analytics event, crash report or log carries photos, video, audio or file names.

**P0-10 Text caption** _(moved up from P1, decided 26 Nov 2026)_
- One line of text (max 40 characters) on a photo or video sticker. The user drags it to place it.
- **Sticker-style typography**, 4 fonts, all free Google Fonts that can be bundled in the app:
  - Bubble: Titan One
  - Comic: Luckiest Guy
  - Round: Baloo 2 ExtraBold, which also covers Hindi
  - Classy: Instrument Serif italic
- **Bright colour options:**
  - Colours: sun yellow, hot pink, electric blue, lime, tangerine, white, black.
  - Two looks: **White outline** (coloured letters with a thick white edge, like a die-cut sticker; white text gets a black edge) or **Colour block** (text on a bright rounded block with a white edge).
- Acceptance:
  - [ ] Text stays inside the 512×512 canvas with the white outline applied, and is readable at WhatsApp's small sticker size.
  - [ ] It supports emoji and non-Latin scripts used in the launch markets.

**P0-11 Sound rights line**
- The Add sound screen shows one short line: "Use sounds you're allowed to share." The terms of use cover user-supplied audio.

### P1: fast follow

- **Built-in sound effects:** a small royalty-free library (licence needed; Q-L1).
- Choosing emojis per sticker. Renaming, reordering and deleting packs. Making extra packs by hand.
- Ads groundwork: a consent framework (UMP / ATT) and layout slots. No ads shown yet.
- Re-editing a saved sticker.
- Localisation into the top WhatsApp markets (Q-S1).

### P2: design for, don't build

- **Native sound-sticker export** when WhatsApp publishes the API (repo [issue #1163](https://github.com/WhatsApp/stickers/issues/1163)). The data model already stores audio per sticker, so this should be just a new exporter.
- Video background removal.
- Export to Telegram and Signal.
- Publishing to the future "WhatsApp Stickers" app, if it opens to third parties.
- Ads and premium (no ads, more effects).

## 7. Data model (local)

```
Sticker {
  id, kind: static|animated, source: photo|video,
  webpPath, previewPath, emojis[1..3],
  audio?: { path, origin: original|file|recording|preset, startMs, durationMs },
  handoffMp4Path?, createdAt
}
Pack {
  identifier, name, kind: static|animated, stickerIds[3..30],
  trayIconPath, imageDataVersion, addedTo: { whatsapp: bool, business: bool }
}
```
Keep the original media plus the edit parameters (crop, trim, cut-out on/off), so stickers can be re-rendered when the sound API arrives or limits change.

## 8. Platform & technical constraints

- **Minimum OS:** Android 7.0 (API 24, the ML Kit floor) and iOS 17 (the Vision foreground mask floor; Q-E4).
- **Media stack:** platform-native only.
  - Android: Media3 Transformer / MediaCodec.
  - iOS: AVFoundation.
  - Both: libwebp for encoding.
  - No dependency on the retired FFmpegKit.
- **Performance budget:** a reference low-end Android device with 3 GB RAM (Q-E3). App download ≤ 30 MB.
- **Testing:** real devices with WhatsApp **stable and beta** installed, plus WhatsApp Business on Android.

## 9. Success metrics

| Metric | Type | Target (success / stretch) | When |
|---|---|---|---|
| First-session sticker created | Leading | 50 % / 65 % of installs | Week 1–4 |
| First-session pack added to WA | Leading | 30 % / 45 % | Week 1–4 |
| Median time: open → added to WA (first session) | Leading | ≤ 60 s / ≤ 40 s | Week 1–4 |
| Add-to-WA failures (validator or WhatsApp reject) | Leading | < 1 % / < 0.3 % | Continuous |
| Stickers with audio | Leading | 15 % / 25 % | Month 1 |
| Hand-off guide → "Open WhatsApp" tapped | Leading | 60 % of hand-offs | Month 1 |
| D7 / D30 retention | Lagging | 15 % / 6 % | Month 1–2 |
| Store rating | Lagging | ≥ 4.3 | Month 2 |
| Crash-free sessions | Lagging | ≥ 99.5 % | Continuous |

We can't see inside WhatsApp, so whether a hand-off ends in a real sound sticker isn't measurable. A one-tap "Did it work? 👍/👎" asked once after a hand-off is the proxy.

## 10. Open questions

| # | Question | Owner | Blocking? |
|---|---|---|---|
| Q-E1 | Framework: fully native (Kotlin + Swift) or a cross-platform UI (Flutter / React Native) with native media modules? The UI is small (~7 screens) and the media pipeline is native either way | Engineering | **Yes** |
| Q-E2 | iOS: does re-sending a pack with the same identifier update the copy already in WhatsApp, or create a duplicate or error? | Engineering (spike) | **Yes** |
| Q-E3 | Pick a reference low-end Android device for the performance budgets | Engineering | **Yes** |
| Q-E4 | iOS 17 minimum OK, or support iOS 16 with a crop-only fallback (no auto cut-out)? | Eng + Product | No |
| Q-D1 | ~~Starter stickers naming~~ **Decided: "Bonus", hidden from My stickers.** Still open: which 2 designs. Test with 5 users | Design | No |
| Q-E5 | Android: after `image_data_version` changes, does WhatsApp pick up new stickers by itself, or must the user re-add the pack? This decides whether "Send to WhatsApp" is 0 or 1 confirmations | Engineering (spike) | **Yes** |
| Q-E6 | Single-file route: does WhatsApp's own *Create sticker → use a photo* keep our transparent cut-out unchanged? If yes, add a "Just this one" option | Engineering (spike) | No |
| Q-D2 | Home screen: pack-centric or a sticker grid with packs hidden? | Design | No |
| Q-D3 | Photo hand-off MP4 background: white, blurred original, or the user's choice? (WhatsApp's creator may offer its own cut-out) | Design (spike) | No |
| Q-L1 | Licensing for built-in sound effects (P1). Also: do we need terms covering user-supplied copyrighted audio? | Legal | No |
| Q-S1 | Launch markets and languages (WhatsApp-heavy markets: India, Brazil, Indonesia, Mexico, …) | Product | No |
| Q-S2 | App name and brand (must not contain "WhatsApp") | Product | Before store submission |

## 11. Timeline & phasing

- **Phase 0 (spike, ~1–2 weeks):** de-risk the hard parts on real devices.
  1. Auto-compressor: any 0.5–10 s clip → animated WebP ≤ 480 KB within the time budget on the reference device, with acceptable quality at 10 s.
  2. Single-sticker experience: a 1-sticker + 2-bonus pack is accepted; adding a 2nd/3rd/4th sticker updates WhatsApp's copy. Test on Android (both WhatsApp apps) and iOS. Count the taps for each.
  3. Single-file route via WhatsApp's Create sticker with a transparent image.
  4. MP4 hand-off accepted by WhatsApp's Create sticker with its sound kept.

  Answers Q-E1, Q-E2, Q-E3, Q-E5, Q-E6 and Q-D3.
- **Phase 1 (MVP build):** P0-1 … P0-9, then internal testing and beta tracks (Play internal testing, TestFlight). Leave time for App Store review, and expect a possible 4.2 / 4.3 back-and-forth.
- **Phase 2 (fast follow):** P1 items, starting with sound effects.
- **Phase 3 (triggered externally):** native sound-sticker export as soon as WhatsApp publishes the API. Watch repo issue #1163 weekly. Being first is the opportunity.

**External dependencies:**
- WhatsApp's sound-sticker rollout, currently gradual and in beta.
- The third-party sound API (no date).
- The "WhatsApp Stickers" standalone app (no date). This is a competitive threat, and possibly a distribution channel.

## 12. Decision log

| Date | Decision | Notes |
|---|---|---|
| 26 Nov 2026 | All processing on-device; MP4 hand-off for sound stickers in the MVP | From the research phase |
| 26 Nov 2026 | Single stickers are the main flow; packs stay hidden | Bonus stickers fill packs below 3 |
| 26 Nov 2026 | Full 10 s video with automatic compression and an honest size notice | Replaces the earlier 6 s cap |
| 26 Nov 2026 | Filler stickers are called **"Bonus"** and are **hidden from My stickers** | Was "starter" |
| 26 Nov 2026 | **Text caption is in the MVP** (P0-10), with sticker-style fonts and bright colours | Was P1 |
| 26 Nov 2026 | **Silent first**: the moving sticker is added to WhatsApp in one tap, then "Make it a sound sticker" is offered | Users always end up with a working sticker |
| 26 Nov 2026 | **Dark mode later**, not in the MVP | The colour pairs already support it |
| 26 Nov 2026 | Keep "Your photos never leave your phone"; verify before launch (P0-9) | |
| 26 Nov 2026 | Sound rights line on the Add sound screen (P0-11) | |
| Pending | App icon: explore 2–3 options once the name is settled | Concept: butter "P." sticker on black |
| Pending | Hindi font: decide with launch languages (Q-S1) | Candidate: Noto Sans Devanagari |
