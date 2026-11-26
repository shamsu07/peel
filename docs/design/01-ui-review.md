# UI Review: Peel. (sticker maker), first-pass design

_26 Nov 2026 · Reviews the design canvas at https://claude.ai/artifact/5f2WobZ1bTBLRSUs4y3aQs (version 11) against the [research](../research/01-whatsapp-stickers.md) and the [MVP spec](../spec/01-mvp-spec.md)._

---

## 1. Summary

The first pass was already strong. The look is distinctive and it fits the product: pastel die-cut stickers, heavy black headlines ending in a full stop, a light grey "paper" background and black pill buttons. That look is the product's best asset, and I kept it exactly.

The weak points were not in the look. They were in **the experience between the screens**:

- **The best moments were missing.** There was no screen for the photo being "peeled" (the moment the app is named after) and no "it worked" screen after adding to WhatsApp. These are the moments people remember and tell friends about.
- **Some required states were missing.** The spec requires a progress bar with a Cancel button while a video is processed (up to 30 s on a cheap phone), a message when WhatsApp isn't installed, a way to delete a sticker, and a voice-recording flow. None were designed.
- **The "Ready" screen asked too much at once.** It had six possible actions, and the sound step, which is the headline feature, sat at the very bottom.
- **Technical words leaked into the UI**, such as "38 KB of 100 KB" and "Compressed". The spec's own principle is that the user never sees the plumbing.
- **Several accessibility and low-end-phone issues**: buttons smaller than a fingertip, fixed-height boxes that break when people use large text (common in the target markets), and Hindi text that would fall back to a mismatched font.

The canvas now has **16 artboards (8 new, 8 refined)**, laid out as three rows: *Make a sticker*, *Send it*, and *The system behind it*. The most important screens now work when tapped: the cut-out and outline toggles, the trim-length quality label, the sound-length chips, recording, and the feedback card.

---

## 2. What I checked against

Each item is a standard design yardstick. In plain words:

| Yardstick | What it means here |
|---|---|
| **Nielsen's 10 usability heuristics** | Ten widely used rules of thumb, for example "always show what's happening", "speak the user's language", "let people undo mistakes", "prefer recognising over remembering". |
| **Hick's law** | Every extra choice on a screen slows people down. Fewer choices mean faster decisions. |
| **Fitts's law** | Big targets close to the thumb are faster and easier to hit than small, far-away ones. |
| **Gestalt principles** | How people group things visually: things that are close together, or look alike, are read as related. |
| **Peak-end rule** | People judge an experience mostly by its best moment and its last moment. |
| **Apple Human Interface Guidelines / Material 3** | Apple's and Google's design rules, for example tap targets of at least 44 pt (iOS) and 48 dp (Android), and sheets, toasts and back behaviour that feel native. |
| **WCAG 2.2 (level AA)** | The accessibility standard. Text needs a contrast of at least 4.5:1 against its background, meaning must never rely on colour alone, text must stay usable at 200% size, and motion must respect the "Reduce Motion" setting. |
| **Low-end Android reality** | 3 GB RAM phones, slow processors, large system font settings, patchy connections. Visual effects must be cheap to draw. |
| **Localisation readiness** | Portuguese, Indonesian and Hindi text is 20–40% longer than English, and Hindi uses a different script. |
| **The spec's own rules** | "Think in stickers, not packs." "Never a dead end." "Plain-language reasons that name WhatsApp's rule." The P0 acceptance criteria. |
| **Store and brand rules** | No "WhatsApp" in the name or icon. App must be a real creation tool (Apple's 4.2 / 4.3 rejections). |

---

## 3. What I found

**Severity scale**
- **Critical**: breaks a P0 requirement or blocks the main flow.
- **High**: noticeably hurts first-time success, trust or the headline feature.
- **Medium**: friction, inconsistency or an accessibility gap.
- **Low**: polish.

### 3.1 Across the whole app

| # | Finding | Severity |
|---|---|---|
| A1 | **No progress screen for video processing.** The spec requires visible progress and a Cancel button. A 10 s clip can take 30 s on a cheap phone, which is a long, silent wait. | Critical |
| A2 | **No "it worked" moment.** After the WhatsApp confirmation the user was dropped back on the sticker grid. That's the most important moment in the app (the peak-end rule), and it was blank. It's also where we should tell people *where* to find the sticker in WhatsApp. | High |
| A3 | **The "peel" moment wasn't designed.** The 1–3 s while the background is removed is the brand's signature, the reason it's called Peel. It needs to be a small delight, not a spinner. | High |
| A4 | **Voice recording wasn't designed.** Recording is likely the most popular sound source ("my dog + my voice"), yet only the audio-file path existed. | High |
| A5 | **Missing required states:** WhatsApp not installed (P0-4), delete a sticker (P0-8), no subject found in the photo (P0-1), microphone permission denied (P0-3), first-time download of the cut-out model on Android. | High |
| A6 | **Technical words in the UI**: "38 KB of 100 KB", "512 × 512", "Compressed", "Search tag added", "478 KB". Casual users don't know what a KB is, and the numbers add worry rather than confidence. | Medium |
| A7 | **Fixed-height boxes.** Many cards had a fixed height. In India, Brazil and Indonesia many people run their phones with large text, and fixed boxes then cut words off. | Medium |
| A8 | **Small tap targets.** Several controls were 32–40 px tall ("Shorten to 4 s", length chips, Send), below the 44 px minimum. | Medium |
| A9 | **Hindi has no matching font.** Inter Tight has no Devanagari (Hindi) letters. Hindi would fall back to whatever the phone has, losing the heavy, confident look. | Medium |
| A10 | **Heavy visual effects.** The white die-cut edges are drawn live with 4–5 stacked shadow filters, plus soft blurred shadows and rotations. On low-end Android this can cause dropped frames when scrolling. This is an engineering note, not a look change. | Medium (eng) |
| A11 | **The placeholder art flatters the design.** All sample stickers are clean vector drawings. Real stickers will be messy phone photos of faces and pets. The grid and Ready screens must be checked with real cut-outs before sign-off. | Medium |
| A12 | **Settings icon looked like a "filter" icon** (sliders). A gear is clearer. | Low |
| A13 | **Small inconsistencies**: the yellow "Butter" ink colour differed between the style guide (#8A4B00) and the screens (#6B3A00); 11 px tags; mixed time formats ("0:03.1 / 7.4 s"). | Low |

### 3.2 Screen by screen

**Home, first run (`Main`)**
- *High*: **No camera option.** P0-1 requires "gallery or take a photo". Only the gallery was reachable.
- *Medium*: The "Stickers with sound" card opened the sound sheet before any photo or video was chosen. That's a logic gap: you can't add sound to nothing. The copy didn't set the expectation either.
- *Low*: No reassurance for a first-time user. "No sign-up, your photos stay on your phone" is a real advantage over competitors (on-device processing, no account) and costs one line.
- *Good*: The "Snap. Peel. Send." hero, two big clear choices (Photo / Video) and the sticker cluster are excellent. Two choices is the right number.

**Home, my stickers (`Library`)**
- *Medium*: **"Stickers / Animated" tabs** exposed WhatsApp's pack rule (static and animated can't be mixed) to people who just think "my stickers". It doubles the places to look for no user benefit.
- *Medium*: Three faded, empty tiles at the end of the grid read as "still loading".
- *Medium*: Tapping a sticker went nowhere, so there was no way to preview, share or delete.
- *Medium*: "New sticker" jumped back to the first-run home screen, which is the wrong context for a returning user.
- *Low*: The blue "new" dot carried meaning by colour alone.
- *Note*: The spec's one-tap "Did it work?" question after a sound hand-off had no home.

**Photo sticker (`PhotoEditor`)**
- *Medium*: The size line ("512 × 512 · 38 KB of 100 KB") is jargon. The spec asks for a "Ready for WhatsApp ✓" badge that you tap to see the rules.
- *Medium*: "Outline on" described a state as if it were an action. It wasn't clear whether tapping turns it on or off.
- *Medium*: No fallback when no subject is found. The spec says: fall back to the whole photo with a gentle hint, and never block.
- *Low*: "Full photo" vs "Cut-out": fine, but "Whole photo" is plainer.
- *Scope note*: the **Text** tool is a P1 (fast-follow) feature in the spec. See the open questions.

**Video sticker (`VideoEditor`)**
- *High*: The **live quality label** (Sharp / Good / Compressed) that the spec asks for was a static picture, so it couldn't show its main job: helping people trade length for quality before processing.
- *Medium*: "478 KB" again; and "Compressed to fit" reads like an error.
- *Medium*: No hint that you can drag to frame the square crop.
- *Medium*: "Shorten to 4 s" was a 32 px button. Once tapped, nothing confirmed it or let you undo.
- *Low*: In the sound selector, "New sound" was a link pretending to be a radio button. Screen readers would announce it wrongly.

**Add sound (`SoundSheet`)**
- *Medium*: The two source cards used two different pastel colours (pink and blue), which suggests a meaning that isn't there. The selected state relied mostly on a border.
- *Medium*: "Drag the yellow window" points at a colour. Instructions shouldn't rely on colour (an accessibility rule).
- *Medium*: The length chips were 40 px tall.
- *Good*: The waveform with a selection window is exactly right, and "It plays when someone taps your sticker" honestly sets expectations.

**Ready (`Ready`)**
- *High*: **Too many choices (Hick's law).** Close, Edit, Add to WhatsApp, Save to Photos, Share, and Make it a sound sticker, plus a four-line technical checklist. The main button sat mid-screen, not in thumb reach.
- *High*: **Confusing sound logic.** The dog sticker has sound, but the black button added the *silent* version, and the sound step was the last item on the page. People who added a sound would wonder where it went.
- *Medium*: The "STARTER" stickers looked like grey, generic system labels. The spec asks that they feel like a gift, not an ad. The explanatory copy talked about the system ("swapped out"), not the benefit.

**Finish sound sticker (`SoundHandoff`)**
- *Medium*: Step 2 asked people to find a video by name ("Peel · dog"). Gallery pickers show thumbnails, not names. Showing the thumbnail lets people *recognise* rather than *remember* it.
- *Low*: The spec asks for illustrated steps. The numbers were there, but no visual cues.
- *Good*: The honest "No sound option yet? WhatsApp is still rolling it out" note is excellent.

**Design language (`StyleGuide`)**
- *Low*: The ink colour mismatch (A13). No contrast ratios recorded, so nobody can check new colours against the rule. No "plain words" principle, even though it is central to the spec.

---

## 4. What I changed, and why

### 4.1 Refined screens

**Home, first run (`Main`)**
- Added a **camera button** on the Photo card (P0-1). It's a smaller, secondary target, so the gallery stays the obvious choice.
- Card captions now describe outcomes: "Background removed for you", "A moving sticker, up to 10 s".
- The sound card now says "Pick a photo or clip, then add your voice", which sets the right order. *In the real app, this card opens the picker first and lands in the editor with the sound sheet open. The prototype jumps straight to the sheet.*
- Added a quiet trust line at the bottom: "No sign-up. Your photos never leave your phone."
- Gear icon for Settings. Cards grow with large text. Gentle press feedback.

**Home, my stickers (`Library`)**
- **Removed the Stickers / Animated tabs.** It's now one grid, newest first. Moving stickers get a small ▶ badge, and stickers with sound get a speaker badge. The pack split happens invisibly, as the spec intends.
- Removed the empty placeholder tiles. The grid now continues under the fade, so it reads as "scroll for more".
- Added the spec's **"Did the sound sticker work?"** one-time card: "It worked" or "Not yet, help" (which reopens the guide). It's dismissible.
- Tapping a sticker opens the new **Sticker details** sheet. "New sticker" opens the new **New sticker** sheet.
- The "2 stickers aren't in WhatsApp yet" banner moved to the States board as a conditional component, shown only when it's true.

**Photo sticker (`PhotoEditor`)**, now interactive
- **Cut-out / Whole photo** really switches the preview.
- **White edge** is a clear on/off switch ("White edge" is plainer than "Outline").
- The jargon line became a green **"Ready for WhatsApp ✓"** pill. Tap it to see the rules in plain words ("Small enough: 38 KB of 100 KB", "See-through background"…). The numbers are one tap away, never in the way.
- Added a **"no subject found" state**, switchable in the artboard's Tweaks panel. It shows the whole photo plus a calm blue hint, with nothing blocked.
- "Add a sound" now says "Record your voice or pick a song clip".

**Video sticker (`VideoEditor`)**, now interactive
- The **quality label is live.** At 7.4 s it reads "Squeezed to fit" with the explanation. Tap **"Make it 4 s and sharper"**: the trim window shrinks, the label becomes "Good", the note turns into a green "Sharper now" confirmation, and **Undo** appears.
- Removed "478 KB". The note names WhatsApp's rule in plain words, as the spec asks.
- Added a "Drag to frame" hint on the preview for the square crop.
- The sound selector buttons (Original / Mute) work. "New sound" is styled as what it is: a link to the sound sheet.
- "Save sticker" now goes to the new **Making it** progress screen.

**Add sound (`SoundSheet`)**
- Both source cards share one neutral style. Selection is a black border **plus** a check badge (not colour alone). "Record" opens the new recording screen.
- "Slide to pick the best part" replaces the colour-based instruction. Added "Change" to swap the file.
- **Length chips (2 / 3 / 5 / 10 s) work** and resize the selection window. They're 44 px tall.

**Ready (`Ready`)**
- **One job: "Add to WhatsApp"**, now at the bottom in thumb reach. Save and Share sit just above it as quieter buttons.
- The technical checklist became the same tappable "Ready for WhatsApp ✓" pill.
- **Sound expectation set up front**: "The sound comes next. WhatsApp needs one extra step for it. We'll walk you through." The actual sound step moved to the success screen, so people do one thing at a time (silent sticker first, which always works, then the sound version).
- Starter stickers are now **"BONUS"** stickers, designed in the brand ("okay!", "haha" in the sticker serif). The copy leads with the benefit: "Two bonus stickers come with it, so you can send yours right now. They make room as you make more."
- A big play button on the sticker, so you can hear the sound before sending.

**Finish sound sticker (`SoundHandoff`)**
- Step 2 now shows the **video's thumbnail** with its length, "the newest one in your gallery".
- Each step has a small visual cue on the right (sticker icon, thumbnail, speaker).
- Copy tightened: "Your silent sticker already works" reassures people that nothing is lost.

**Design language (`StyleGuide`)**
- Recorded the contrast ratio and job of each colour pair (Mint = photo, Bubblegum = video, Butter = sound, Sky = info, Lilac = moving). All pass 4.5:1.
- Unified the Butter ink to #6B3A00.
- Added a fifth principle: **"Plain words, no tech."**
- Tags are now 12 px. "STARTER" became "BONUS". Added a build note: bake the white edges into images on Android, don't draw them live.

### 4.2 New screens and boards

| Artboard | Why it exists |
|---|---|
| **New sticker** (`Create`) | A proper "what do you want to make?" sheet for returning users: Photo, Video, or "Take a photo now". It notes that sound can be added next. |
| **Peeling** (`Peeling`) | The signature moment. The photo appears, a white edge **traces around the subject** while a light sweep passes over it, and a "Peeling…" sticker sits on top. It includes "Skip, keep the whole photo" for control. Motion turns off with Reduce Motion. |
| **Recording** (`SoundRecord`) | A big pink timer ("0:02.4 of 10 s"), a live waveform, and a large stop button with a pulsing ring. **Tap stop** to switch to the review state: play it back, "Again", or "Use this sound". A tip mentions press-and-hold, which WhatsApp users already know from voice notes. |
| **Making it** (`Making`) | Video processing with a real progress bar, time left, three plain steps ("Squeezing it under WhatsApp's size limit"), and a full-width **Cancel**. Meets P0-2. |
| **WhatsApp not installed** (`NoWhatsApp`) | A friendly, honest sheet: "No WhatsApp here." "Get WhatsApp" opens the store, and "Save to Photos instead" is the fallback. No dead end (P0-4). |
| **Added to WhatsApp** (`Sent`) | The peak moment: "It's in WhatsApp." The sticker slaps into a simple chat illustration. It tells people **where to find it** ("look for My Stickers"), offers WhatsApp Business (Android, P0-4), and leads with **"Next: give it its sound"**, with "Open WhatsApp" and "Make another" as secondary options. |
| **Sticker details** (`StickerDetail`) | Tap any sticker: big preview, play its sound, an "In WhatsApp ✓" status, then Make the sound version, Save to Photos, Share, and **Delete** ("Also removes it from WhatsApp. You can undo."). Meets P0-7 and P0-8. |
| **States and details** (`SystemStates`) | The supporting system: an **app icon concept** (a butter "P." sticker peeling at the corner, on black, with no WhatsApp green), **motion rules** (Peel, Stick, Press, Calm), **edge-state components** (toast, Undo snackbar, "not in WhatsApp yet" banner, first-time cut-out model download, microphone denied), the **accessibility rules**, and a **longer-language test** in Portuguese, Indonesian and Hindi. |

### 4.3 The prototype path

Tap through from **Home** with the Play button: Photo → Peeling → Photo sticker → Add a sound → (Record) → Save → Ready → Add to WhatsApp → It's in WhatsApp → Next: give it its sound → Finish in WhatsApp → Open WhatsApp → My stickers (with the feedback card) → tap the dog → Sticker details. The video path is Home → Video → Video sticker → Save → Making it → Ready.

---

## 5. What I deliberately left alone

- **The visual direction**, exactly as the product owner asked: pastel die-cut stickers with dark-ink pairs, heavy Inter Tight headlines ending in a full stop, Instrument Serif italic only on sticker text, black pill buttons, and light grey paper. Every new screen uses only these parts.
- **The colour palette.** I didn't add a single new brand colour. The delete red (#B42318) is a functional warning colour used in one place.
- **"Snap. Peel. Send."**, the hero layout, the Photo / Video cards and the sticker cluster on Home. They're right.
- **The working name "Peel."** It's a placeholder, but a good one: short, physical, and it describes the action.
- **The honest copy** about WhatsApp's limits and the sound rollout. It's exactly the right tone, so I only tightened it.
- **No onboarding tour.** The spec says the first screen is the make button, and that's correct.
- **No dark mode.** The light paper look *is* the brand, and dark mode is not in the spec. Raised as an open question below.
- **Settings screen** not designed. It's mostly links (privacy policy, analytics consent, WhatsApp Business) and is low risk.
- **Re-editing a saved sticker**, **choosing emojis**, **packs screen**: all P1 or later in the spec, so not designed.

---

## 6. Open questions for the product owner

1. **"Bonus" or "Starter"?** I renamed the filler stickers "Bonus" because it reads as a gift. "Bonus" is also a familiar loanword in Portuguese, Indonesian and Hindi. The spec says "starter". Your call, ideally after the 5-user test the spec plans (Q-D1).
2. **Should bonus stickers appear in "My stickers"?** The spec says they're removable, but they aren't the user's own work. Options: (a) hide them and handle everything automatically; (b) show them at the end of the grid with a "Bonus" tag so people can remove them. I lean towards (a) for simplicity.
3. **Text tool in the MVP?** The photo editor shows a "Text" tool, but text captions are P1 in the spec. Keep it visible (it's what the sticker serif font exists for), mark it "Soon", or remove it for launch?
4. **Sound order: silent first, then sound.** The Ready screen adds the silent sticker first and *then* guides people to the sound version. This always gives people a working sticker, but the sound version is one screen further away. The alternative is to lead with the sound hand-off for stickers with sound. Do you agree with "silent first"?
5. **The "Added" screen depends on two engineering answers** (Q-E2, Q-E5): whether adding a later sticker needs WhatsApp's confirmation again on iOS and Android. If it does, returning users see WhatsApp's dialog each time, and the button should say "Send to WhatsApp" (as the spec plans) with this success screen after it. If not, we can show a toast instead of a full screen for later stickers.
6. **App icon direction.** The concept is black with a butter "P." sticker. Black stands out against WhatsApp's green and colourful icons. Do you want to explore 2–3 icon options?
7. **Dark mode.** Many Android users in the target markets use dark mode, and WhatsApp itself has it. A dark "paper" version is very doable with the ink/pastel pairs. Is it in scope for v1, or later?
8. **The privacy line on Home**, "Your photos never leave your phone", is a strong selling point. It must stay 100% true, including analytics and crash reports. Please confirm with whoever owns privacy before launch.
9. **Hindi typography.** Which heavy Devanagari font do we pair with Inter Tight? I suggest Noto Sans Devanagari ExtraBold, and the font file size needs checking against the 30 MB app budget.
10. **Copyrighted audio.** People will pick song clips. Do we need a short line ("Use sounds you're allowed to share") in the sound sheet, or terms only? (Spec Q-L1.)

---

### Answers (26 Nov 2026)

| # | Decision |
|---|---|
| 1 | **"Bonus"** |
| 2 | **Hidden** from My stickers (option a) |
| 3 | **Text tool stays** in the MVP (now spec P0-10) |
| 4 | **Silent first**, then sound |
| 5 | Waits on the Phase 0 tests (Q-E2, Q-E5) |
| 6 | Explore 2–3 icon options once the name is settled |
| 7 | **Dark mode later**, not in v1 |
| 8 | Keep the line; verify before launch (spec P0-9) |
| 9 | Decide with launch languages; candidate Noto Sans Devanagari |
| 10 | Add "Use sounds you're allowed to share." to the Add sound screen, plus a line in the terms (spec P0-11) |

---

## 7. Notes for engineering (from the design side)

- **Draw the white die-cut edges as pre-rendered images**, or use a single blur-free outline, on Android. Avoid stacked live shadow filters in scrolling lists.
- **No fixed heights** on cards or banners. Use minimum heights so text at 200% still fits.
- **Respect Reduce Motion / Remove animations**: every animation falls back to a 200 ms fade.
- **Recording** supports both tap-to-toggle (accessible) and press-and-hold (familiar from WhatsApp voice notes).
- **Each sticker needs a spoken description** in the app ("dog sticker, with sound"). Consider reusing it for WhatsApp's `accessibility_text`.
- **Delete uses Undo (about 5 s)** instead of a confirmation dialog. Only push the WhatsApp pack update after the Undo window closes.
