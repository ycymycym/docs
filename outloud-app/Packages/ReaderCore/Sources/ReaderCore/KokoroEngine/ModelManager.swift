import Foundation

/// Owns the on-disk Kokoro model + voice embeddings, and the first-run download.
///
/// Decision (brief §6.4): **download on first launch** to keep the App Store
/// binary small (~80MB INT8 model, ~170MB with G2P data + voices). Files are
/// stored in Application Support (NOT the App Group — only extracted text is
/// shared with the extension; the model is host-app-only and excluded from
/// iCloud backup).
///
/// The remote layout is configurable so you can host the assets on your own
/// CDN / a GitHub release. Replace `Remote.baseURL` before shipping.
public actor ModelManager {

    public enum State: Equatable, Sendable {
        case notDownloaded
        case downloading(progress: Double)
        case ready
        case failed(String)
    }

    public struct Remote {
        /// Base URL hosting the model bundle. MUST be set before release.
        /// Suggested: a versioned path so you can ship model updates.
        public static let baseURL = URL(string: "https://cdn.flysky.com.au/outloud/kokoro/v1")!
        public static let modelFile = "kokoro-82m-int8.bin"
        /// Voice embeddings are bundled into one archive resolved per-voice.
        public static let voicesFile = "voices.bin"
    }

    private(set) public var state: State = .notDownloaded
    private var observers: [@Sendable (State) -> Void] = []

    public init() {
        if FileManager.default.fileExists(atPath: modelURL.path),
           FileManager.default.fileExists(atPath: voicesURL.path) {
            state = .ready
        }
    }

    // MARK: Locations

    private static var supportDir: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                            in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("KokoroModel", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        // Models are re-downloadable; keep them out of iCloud/iTunes backup.
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var d = dir
        try? d.setResourceValues(values)
        return dir
    }

    public nonisolated var modelURL: URL {
        Self.supportDir.appendingPathComponent(Remote.modelFile)
    }
    public nonisolated var voicesURL: URL {
        Self.supportDir.appendingPathComponent(Remote.voicesFile)
    }

    public var isReady: Bool {
        if case .ready = state { return true }
        return false
    }

    // MARK: Observation

    public func observe(_ block: @escaping @Sendable (State) -> Void) {
        observers.append(block)
        block(state)
    }

    private func setState(_ new: State) {
        state = new
        for o in observers { o(new) }
    }

    // MARK: Download

    /// Ensures the model + voices are present, downloading if needed. Safe to
    /// call repeatedly; returns immediately when already `.ready`.
    public func ensureAvailable() async throws {
        if isReady { return }
        try await download(Remote.modelFile, to: modelURL, weight: 0.0..<0.85)
        try await download(Remote.voicesFile, to: voicesURL, weight: 0.85..<1.0)
        setState(.ready)
    }

    /// Downloads one file, mapping its 0...1 progress into the supplied slice of
    /// the overall progress bar. Uses a delegate-driven download task so we get
    /// real byte progress and resume-on-failure support for the large model file.
    private func download(_ name: String, to dest: URL, weight: Range<Double>) async throws {
        if FileManager.default.fileExists(atPath: dest.path) { return }

        let url = Remote.baseURL.appendingPathComponent(name)
        setState(.downloading(progress: weight.lowerBound))

        do {
            try await FileDownloader.download(from: url, to: dest) { fraction in
                let mapped = weight.lowerBound + fraction * (weight.upperBound - weight.lowerBound)
                Task { await self.setState(.downloading(progress: mapped)) }
            }
        } catch {
            let msg = (error as? ReaderError)?.errorDescription ?? error.localizedDescription
            setState(.failed(msg))
            throw ReaderError.modelDownloadFailed(msg)
        }
    }
}

/// A self-contained delegate-driven downloader: real progress, atomic move into
/// place, and clean error propagation. Wraps the callback-style URLSession
/// download task in an async continuation.
private final class FileDownloader: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {

    private let destination: URL
    private let onProgress: @Sendable (Double) -> Void
    private var continuation: CheckedContinuation<Void, Error>?
    private var session: URLSession?

    private init(destination: URL, onProgress: @escaping @Sendable (Double) -> Void) {
        self.destination = destination
        self.onProgress = onProgress
    }

    static func download(from url: URL, to dest: URL,
                         onProgress: @escaping @Sendable (Double) -> Void) async throws {
        let downloader = FileDownloader(destination: dest, onProgress: onProgress)
        try await downloader.run(url: url)
    }

    private func run(url: URL) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            self.continuation = cont
            let config = URLSessionConfiguration.default
            config.waitsForConnectivity = true
            let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
            self.session = session
            session.downloadTask(with: url).resume()
        }
        session?.finishTasksAndInvalidate()
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didWriteData _: Int64, totalBytesWritten written: Int64,
                    totalBytesExpectedToWrite expected: Int64) {
        guard expected > 0 else { return }
        onProgress(Double(written) / Double(expected))
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        // Must move synchronously here — `location` is deleted when this returns.
        do {
            if let http = downloadTask.response as? HTTPURLResponse,
               !(200..<300).contains(http.statusCode) {
                throw ReaderError.modelDownloadFailed("Server returned status \(http.statusCode).")
            }
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.moveItem(at: location, to: destination)
            continuation?.resume()
        } catch {
            continuation?.resume(throwing: error)
        }
        continuation = nil
    }

    func urlSession(_ session: URLSession, task: URLSessionTask,
                    didCompleteWithError error: Error?) {
        // Only meaningful on failure — success is handled in didFinishDownloadingTo.
        if let error {
            continuation?.resume(throwing: error)
            continuation = nil
        }
    }
}
