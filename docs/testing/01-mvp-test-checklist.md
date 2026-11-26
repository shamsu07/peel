# MVP test checklist (first full build, 26 Nov 2026)

Installed on: iPhone 15 Pro (release build). Android builds too but hasn't been run on a phone yet.

**Automated:** 55 tests pass, the analyzer reports no issues, and Android and iOS both build.

**Not yet tried on a device:** every screen below except the Phase 0 lab. The native parts (cut-out, video frames, sound video, clipboard) compile but have never run. Expect a few fixes during this session.

## 1. First run
- [ ] Home shows "Snap. Peel. Send.", the three design stickers, Photo and Video cards, the sound card and the privacy line.
- [ ] The gear opens Settings. Long-pressing "Peel." opens the test lab.

## 2. Photo sticker
- [ ] Photo card → gallery opens (first time: Photos permission prompt).
- [ ] Camera button on the Photo card → camera opens (first time: camera permission prompt).
- [ ] Peeling screen: the sweep runs, then the editor opens with the background removed.
- [ ] Photo with no clear subject → the editor keeps the whole photo and explains why.
- [ ] "Skip, keep the whole photo" works.
- [ ] Editor: Cut-out / Whole photo switch, white edge on/off, and the "Ready for WhatsApp" pill opens its list.
- [ ] Text: type, 4 fonts, 7 colours, outline/block, drag up/down, Done. Remove takes the text off.
- [ ] Add a sound → Record: permission prompt, live bars, auto-stop at 10 s, Again, Play, Use this sound.
- [ ] Add a sound → Audio file: pick, slide to the part, How long chips, Play, Use this sound.
- [ ] Save sticker → "It’s ready." with the bonus stickers (first sticker only).

## 3. Video sticker
- [ ] Video card → pick a clip → the editor plays it looping inside the rounded frame.
- [ ] Drag to reframe. The filmstrip trimmer moves both ends and the window. 10 s max.
- [ ] The quality label changes with length. On a long clip: "Make it 4 s and sharper", then Undo.
- [ ] Sound: Original / New sound / Mute. Text button.
- [ ] Save → "Making it." with progress, steps and a working Cancel → "It’s ready." (the sticker animates).
- [ ] Note the time "Making it." takes for a 10 s clip.

## 4. WhatsApp
- [ ] Add to WhatsApp → WhatsApp's add-pack preview → back in Peel, "It’s in WhatsApp."
- [ ] The sticker is in WhatsApp's tray, padded with "okay!" and "haha".
- [ ] Make a 2nd sticker → Add to WhatsApp. **iPhone:** a new pack with only the new sticker (no duplicate of the first).
- [ ] Sticker with sound → "Next: give it its sound" → saved to Photos → follow the 3 steps in WhatsApp → does the sound sticker work?
- [ ] My stickers: "N new stickers to send" bar → Send.

## 5. My stickers and details
- [ ] Home now shows My stickers: grid, moving/sound badges, blue dot on unsent stickers.
- [ ] Tap a sticker → details: play sound, Save to Photos, Share, Copy sticker (then try pasting it in a WhatsApp chat: iPhone single-sticker route test), Delete → Undo.
- [ ] Delete without Undo → it's gone from Peel. Check whether it's also gone from WhatsApp's pack.

## 6. Known gaps (not built yet)
- Bonus stickers and the Home sticker art use the design styling, but caption fonts and the bonus serif download on first use. They aren't bundled yet, so they need internet once.
- No crop tool for photos. Captions on video stickers are supported by the engine; the preview is approximate.
- Re-editing a saved sticker, emoji choice, analytics and crash reports, and ads are not in this build.
