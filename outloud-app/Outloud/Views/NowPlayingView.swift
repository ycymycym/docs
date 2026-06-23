import SwiftUI
import ReaderCore

/// The now-playing screen: title, transport, speed, scrubber, voice picker.
/// Word/sentence highlight is intentionally OUT of v1 (brief §6.7).
struct NowPlayingView: View {
    @EnvironmentObject private var playback: PlaybackEngine
    @EnvironmentObject private var store: StoreManager
    @EnvironmentObject private var env: AppEnvironment
    @State private var showVoicePicker = false
    @State private var showPaywall = false

    private let speeds: [Float] = [0.75, 1.0, 1.25, 1.5, 2.0]

    var body: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 8)

            // Artwork-ish header
            Image(systemName: "waveform")
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(.tint)
                .symbolEffect(.variableColor.iterative, isActive: playback.status == .playing)

            VStack(spacing: 6) {
                Text(playback.title).font(.title2.bold()).multilineTextAlignment(.center)
                Text(playback.voice.displayName + " · " + statusLabel)
                    .font(.subheadline).foregroundStyle(.secondary)
            }

            scrubber

            transport

            speedControl

            Button { showVoicePicker = true } label: {
                Label("Voice: \(playback.voice.displayName)", systemImage: "person.wave.2.fill")
            }
            .buttonStyle(.bordered)

            Spacer()
        }
        .padding()
        .navigationTitle("Now Playing")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showVoicePicker) { VoicePickerView() }
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .overlay { if playback.status == .preparing { ModelDownloadOverlay() } }
        .onChange(of: playback.status) { _, new in
            if new == .reachedFreeLimit { showPaywall = true }
        }
    }

    private var statusLabel: String {
        switch playback.status {
        case .preparing: return "Preparing…"
        case .buffering: return "Buffering…"
        case .playing: return "Playing"
        case .paused: return "Paused"
        case .finished: return "Finished"
        case .reachedFreeLimit: return "Free preview ended"
        case .failed(let m): return m
        case .idle: return "Ready"
        }
    }

    private var scrubber: some View {
        VStack(spacing: 4) {
            Slider(
                value: Binding(
                    get: { Double(playback.currentIndex) },
                    set: { playback.seek(to: Int($0)) }
                ),
                in: 0...Double(max(playback.sentenceCount - 1, 1)),
                step: 1
            )
            HStack {
                Text("Sentence \(min(playback.currentIndex + 1, playback.sentenceCount))")
                Spacer()
                Text("\(playback.sentenceCount)")
            }
            .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var transport: some View {
        HStack(spacing: 44) {
            Button { playback.skip(by: -1) } label: {
                Image(systemName: "backward.fill").font(.title)
            }
            Button { playback.toggle() } label: {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 64))
            }
            Button { playback.skip(by: 1) } label: {
                Image(systemName: "forward.fill").font(.title)
            }
        }
        .tint(.accentColor)
    }

    private var speedControl: some View {
        Picker("Speed", selection: Binding(
            get: { playback.speed },
            set: { playback.speed = $0 }
        )) {
            ForEach(speeds, id: \.self) { s in
                Text(s == 1.0 ? "1×" : "\(speedString(s))×").tag(s)
            }
        }
        .pickerStyle(.segmented)
    }

    private var isPlaying: Bool {
        playback.status == .playing || playback.status == .buffering
    }

    private func speedString(_ s: Float) -> String {
        s.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(s))
            : String(format: "%.2g", s)
    }
}

/// Lightweight overlay shown while the model downloads on first run.
private struct ModelDownloadOverlay: View {
    @EnvironmentObject private var env: AppEnvironment

    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(spacing: 14) {
                if case .downloading(let p) = env.modelState {
                    ProgressView(value: p) { Text("Downloading voice…") }
                        .frame(width: 220)
                    Text("\(Int(p * 100))% · one-time, ~170 MB")
                        .font(.caption).foregroundStyle(.secondary)
                } else if case .failed(let msg) = env.modelState {
                    Text("Download failed").font(.headline)
                    Text(msg).font(.caption).multilineTextAlignment(.center)
                    Button("Retry") { Task { try? await env.modelManager.ensureAvailable() } }
                        .buttonStyle(.borderedProminent)
                } else {
                    ProgressView("Preparing…")
                }
            }
            .padding(24)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
        }
    }
}
