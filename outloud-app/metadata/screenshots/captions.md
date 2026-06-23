# Screenshot plan (capture_shots → upload_shots)

Capture one set per required display size: **6.9" iPhone**, **6.5" iPhone**,
**13" iPad**. Same 5 frames in this order, same captions.

| # | Screen (simulator route) | Overlay caption |
|---|---|---|
| 1 | NowPlayingView, mid-read, waveform animating | Listen to any PDF |
| 2 | iOS share sheet with Outloud selected | Share from anywhere |
| 3 | LibraryView with 3–4 recent docs, one mid-progress | Pick up where you left off |
| 4 | VoicePickerView, free + locked voices visible | Natural on-device voices |
| 5 | PaywallView, lifetime CTA highlighted | Pay once. No subscription. |

Notes:
- Frame 1 is the hero — use a recognizable document title (e.g. a paper).
- Keep captions short; lead with on-device / offline / pay-once, never voices.
- Seed the simulator with sample docs before `capture_shots` so frames 1–3 look real.
