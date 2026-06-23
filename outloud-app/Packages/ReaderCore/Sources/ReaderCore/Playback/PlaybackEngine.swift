import Foundation
import AVFoundation
import Combine

/// The producer/consumer playback orchestrator — the whole product is this flow
/// (brief §4). Drives synthesis ahead of playback while the AudioScheduler
/// consumes buffers gaplessly.
///
/// Start sequence (first-audio latency, §6.3):
///   synthesize sentence 0 ALONE → schedule → audio starts within ~2s
///   then keep synthesizing sentences[1...] up to `prefetchDepth` ahead.
///
/// Sentences (not chunks) are the scheduling unit: a sentence is always well
/// under the <15s per-call audio cap (§6.2), gives precise ±1-sentence skip and
/// resume, and makes the first-sentence fast path automatic. The Chunker's
/// token bound still guards pathologically long sentences.
@MainActor
public final class PlaybackEngine: ObservableObject {

    public enum Status: Equatable {
        case idle
        case preparing            // loading/downloading model
        case buffering            // synthesizing the first sentence
        case playing
        case paused
        case finished
        case reachedFreeLimit     // hit the free-tier cap → show paywall
        case failed(String)
    }

    // MARK: Published state (SwiftUI binds to these)
    @Published public private(set) var status: Status = .idle
    @Published public private(set) var currentIndex: Int = 0
    @Published public private(set) var sentenceCount: Int = 0
    @Published public var speed: Float = 1.0 { didSet { scheduler.setSpeed(speed) ; refreshNowPlaying() } }
    @Published public private(set) var voice: Voice
    @Published public private(set) var title: String = ""

    public var progress: Double {
        sentenceCount > 0 ? Double(currentIndex) / Double(sentenceCount) : 0
    }

    // MARK: Collaborators
    private let engine: SpeechEngine
    private let scheduler = AudioScheduler()
    private let nowPlaying = NowPlayingController()
    private let gate: FreeTierGate
    private let library: LibraryStore
    private var isUnlocked: () -> Bool

    // MARK: Document state
    private var documentID: String?
    private var sentences: [Sentence] = []

    // MARK: Producer state
    private var producer: Task<Void, Never>?
    private var nextToSynthesize = 0
    private var accumulatedAudio: TimeInterval = 0
    private let prefetchDepth = 3
    private var lookahead: AsyncSemaphore

    public init(engine: SpeechEngine,
                library: LibraryStore,
                gate: FreeTierGate = .default,
                isUnlocked: @escaping () -> Bool) {
        self.engine = engine
        self.library = library
        self.gate = gate
        self.isUnlocked = isUnlocked
        self.voice = VoiceCatalog.default
        self.lookahead = AsyncSemaphore(value: prefetchDepth)

        scheduler.onSentenceFinished = { [weak self] id in
            Task { @MainActor in self?.didFinishSentence(id) }
        }
        wireRemoteCommands()
    }

    /// Inject the live paid-entitlement provider once StoreKit has loaded.
    public func updateUnlockProvider(_ provider: @escaping () -> Bool) {
        isUnlocked = provider
    }

    // MARK: Loading a document

    /// Loads a document and begins playback from its resume point.
    public func load(document: ReaderDocument) {
        stopProducer()
        documentID = document.id
        title = document.title
        voice = VoiceCatalog.voice(id: document.voiceID) ?? VoiceCatalog.default

        let chunker = Chunker()
        sentences = chunker.sentences(in: document.body)
        sentenceCount = sentences.count

        guard !sentences.isEmpty else {
            status = .failed(ReaderError.emptyDocument.errorDescription ?? "Empty document.")
            return
        }
        let start = min(max(0, document.resumeSentenceIndex), sentences.count - 1)
        currentIndex = start
        play(from: start)
    }

    // MARK: Transport

    public func play(from index: Int? = nil) {
        let start = index ?? currentIndex
        Task { await beginPlayback(from: start) }
    }

    public func pause() {
        guard status == .playing || status == .buffering else { return }
        scheduler.pause()
        status = .paused
        refreshNowPlaying()
    }

    public func resume() {
        guard status == .paused else { return }
        scheduler.resume()
        status = .playing
        refreshNowPlaying()
    }

    public func toggle() {
        switch status {
        case .playing, .buffering: pause()
        case .paused: resume()
        case .idle, .finished, .reachedFreeLimit: play()
        default: break
        }
    }

    public func skip(by delta: Int) {
        let target = min(max(0, currentIndex + delta), max(0, sentences.count - 1))
        seek(to: target)
    }

    public func seek(to index: Int) {
        guard !sentences.isEmpty else { return }
        let target = min(max(0, index), sentences.count - 1)
        currentIndex = target
        play(from: target)
    }

    public func setVoice(_ newVoice: Voice) {
        guard newVoice.id != voice.id else { return }
        voice = newVoice
        if let id = documentID, var doc = library.document(id: id) {
            doc.voiceID = newVoice.id
            library.upsert(doc)
        }
        // Re-prime from the current sentence with the new voice.
        if status == .playing || status == .paused || status == .buffering {
            play(from: currentIndex)
        }
    }

    public func stop() {
        stopProducer()
        scheduler.stop()
        nowPlaying.clear()
        nowPlaying.deactivateSession()
        status = .idle
    }

    // MARK: Producer/consumer core

    private func beginPlayback(from start: Int) async {
        stopProducer()
        await lookahead.reset(to: prefetchDepth)
        nextToSynthesize = start
        accumulatedAudio = 0

        // Prepare audio session + engine (model may download here).
        status = .preparing
        do {
            try nowPlaying.activateSession()
            try await engine.prepare()
            scheduler.setSpeed(speed)
            try scheduler.start()
        } catch {
            status = .failed((error as? ReaderError)?.errorDescription ?? error.localizedDescription)
            return
        }

        status = .buffering
        scheduler.flush()  // clear anything left from a previous position

        producer = Task { [weak self] in
            await self?.produceLoop()
        }
    }

    /// Synthesizes sentences sequentially, bounded to `prefetchDepth` in flight.
    /// The very first iteration synthesizes sentence `start` alone → fast start.
    private func produceLoop() async {
        while !Task.isCancelled {
            let index = nextToSynthesize
            guard index < sentences.count else { break }
            let sentence = sentences[index]

            // Free-tier gate: stop BEFORE synthesizing the sentence that crosses
            // the cap. The paywall is presented when the last allowed sentence
            // finishes playing (see didFinishSentence).
            if gate.limitReached(before: sentence,
                                 accumulatedAudio: accumulatedAudio,
                                 isUnlocked: isUnlocked()) {
                pendingFreeLimit = true
                break
            }

            await lookahead.wait()
            if Task.isCancelled { break }

            do {
                let audio = try await engine.synthesize(
                    text: sentence.text, voice: voice, speed: speed)
                if Task.isCancelled { break }
                accumulatedAudio += audio.duration
                nextToSynthesize += 1
                scheduler.schedule(audio, sentenceID: index)
                if status == .buffering { status = .playing; refreshNowPlaying() }
            } catch {
                status = .failed((error as? ReaderError)?.errorDescription ?? error.localizedDescription)
                break
            }
        }
    }

    private var pendingFreeLimit = false

    /// Called when a scheduled sentence finishes rendering. Advances progress,
    /// frees a prefetch slot, persists resume, and handles end-of-document /
    /// free-limit transitions.
    private func didFinishSentence(_ id: Int) {
        currentIndex = id + 1
        persistResume()
        refreshNowPlaying()
        Task { await lookahead.signal() }

        if currentIndex >= sentences.count {
            status = .finished
            // Reset resume to the start so re-opening replays from the top.
            if let docID = documentID { library.updateResume(documentID: docID, sentenceIndex: 0) }
            return
        }
        // If the gate stopped the producer and we've now played everything that
        // was allowed, surface the paywall.
        if pendingFreeLimit && currentIndex >= nextToSynthesize {
            status = .reachedFreeLimit
            scheduler.pause()
        }
    }

    private func persistResume() {
        guard let id = documentID else { return }
        library.updateResume(documentID: id, sentenceIndex: currentIndex)
    }

    private func stopProducer() {
        producer?.cancel()
        producer = nil
        pendingFreeLimit = false
    }

    // MARK: Now Playing / remote

    private func wireRemoteCommands() {
        nowPlaying.wireRemoteCommands(.init(
            play: { [weak self] in self?.resume() },
            pause: { [weak self] in self?.pause() },
            toggle: { [weak self] in self?.toggle() },
            skipForward: { [weak self] in self?.skip(by: 1) },
            skipBackward: { [weak self] in self?.skip(by: -1) }
        ))
    }

    private func refreshNowPlaying() {
        let rate: Float = (status == .playing) ? speed : 0
        nowPlaying.update(
            title: title,
            detail: voice.displayName,
            rate: rate,
            elapsed: Double(currentIndex),       // sentence-based timeline
            duration: Double(max(sentenceCount, 1))
        )
    }
}
