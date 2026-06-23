# Outloud — On-Device English TTS Reader

100% on-device English text-to-speech. Share a PDF or web page → it reads aloud
in a high-quality Kokoro voice. No account, no upload, no internet (after the
one-time voice download). Pay once.

> **Build status / honesty note:** this tree is the complete v1 Swift/SwiftUI
> source for the app described in the build brief. It was authored in a Linux
> environment with **no Xcode/macOS toolchain**, so it has **not been compiled
> on-device**. Treat the Kokoro integration (`KokoroSpeechEngine.swift`) and the
> Readability vendor file as the two spots to verify first in Xcode. Everything
> port-specific is isolated so fixes are local.

## Architecture

Two app targets + one shared SPM package (brief §4):

```
Outloud/            SwiftUI host app — all synthesis + playback
ShareExtension/     extracts text only, hands off via App Group (NO synthesis)
Packages/ReaderCore SPM package shared by both targets
 ├─ TextExtraction/   PDF + Vision OCR fallback + Web(Readability) + PlainText
 ├─ TranslationStage/ v1.1 SEAM — passthrough in v1
 ├─ Chunking/         NLTokenizer sentence split → token-bounded chunks
 ├─ KokoroEngine/     SpeechEngine protocol + KokoroSwift adapter + model dl
 ├─ Playback/         AVAudioEngine, prefetch producer/consumer, now-playing
 ├─ Paywall/          StoreKit 2 + free-tier length gate + voice gating
 └─ Library/          local recent documents + resume position
```

Pipeline: `Share → extract → TranslationStage(passthrough) → chunk →
synthesize-first-sentence-fast → schedule buffers gaplessly`.

## Prerequisites

- macOS + **Xcode 16** (iOS 18 SDK).
- [XcodeGen](https://github.com/yonadev/xcodegen): `brew install xcodegen`.
- An Apple Developer team (for the App Group capability + signing).

## Generate & open

```bash
cd outloud-app
xcodegen generate          # reads project.yml → Outloud.xcodeproj
open Outloud.xcodeproj
```

Set your team id in `project.yml` (`DEVELOPMENT_TEAM`) and in
`StoreKit/Outloud.storekit` before archiving.

## Before it runs (the 3 things to wire)

1. **Kokoro model hosting.** Set `ModelManager.Remote.baseURL` to where you host
   `kokoro-82m-int8.bin` + `voices.bin`. Default is download-on-first-run
   (brief §6.4) to keep the binary small.
2. **Voice embeddings.** `VoiceEmbeddingLoader` expects `voices.bin` as a
   safetensors/npz archive keyed by the voice ids in `VoiceCatalog`. Pack it to
   match, or adjust the loader.
3. **Readability.** Replace `ReaderCore/.../Readability.js` with the full Mozilla
   file (a working heuristic shim ships so the project builds today).

## Tests

Pure logic is unit-tested (no device needed):

```bash
cd Packages/ReaderCore && swift test
```

Covers sentence chunking (`ChunkerTests`) and the free-tier gate
(`FreeTierGateTests`).

## Acceptance criteria → where it lives (brief §9)

| Criterion | Implementation |
|---|---|
| Audio starts ~2s after share | First-sentence fast path in `PlaybackEngine.produceLoop` |
| 20-page PDF gapless, no crash | `AudioScheduler` back-to-back buffers + bounded prefetch |
| Scanned PDF → OCR | `PDFTextExtractor` heuristic → `OCRTextExtractor` (Vision) |
| Safari article body only | `WebArticleExtractor` + Readability |
| Background + lockscreen controls | `NowPlayingController` (AVAudioSession + MPRemoteCommandCenter) |
| Free cap → paywall; lifetime removes it; Restore | `FreeTierGate` + `StoreManager` + `PaywallView` |
| Airplane mode after one download | `ModelManager` local model; no cloud TTS |
| ANE compile failure fallback | N/A for MLX port — see note in `KokoroSpeechEngine` |
| TranslationStage passthrough w/ clean seam | `TranslationStage.swift` |

## App Store submission checklist

This repo's `../outloud/index.html` is the **privacy policy** page — paste its
public URL into App Store Connect (App Privacy → Privacy Policy URL). Then:

- App Privacy: **Data Not Collected** (matches `PrivacyInfo.xcprivacy`).
- In-App Purchases: create `au.com.flysky.outloud.lifetime` (Non-Consumable,
  $29.99) and `au.com.flysky.outloud.monthly` ($4.99/mo) to match `Products.swift`.
- Background mode "Audio" + App Group `group.au.com.flysky.outloud` enabled on
  both targets in the Developer portal.
- Archive → upload via Xcode Organizer / `xcodebuild -exportArchive`.
