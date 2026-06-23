import Foundation

/// A tiny async counting semaphore used to bound the synthesis look-ahead
/// (producer/consumer). `wait()` suspends instead of blocking a thread, so the
/// producer Task can park cheaply while N sentences are in flight.
actor AsyncSemaphore {
    private var value: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(value: Int) { self.value = value }

    func wait() async {
        if value > 0 {
            value -= 1
            return
        }
        await withCheckedContinuation { waiters.append($0) }
    }

    func signal() {
        if let next = waiters.first {
            waiters.removeFirst()
            next.resume()
        } else {
            value += 1
        }
    }

    /// Reset to a fresh capacity, releasing any parked waiters (used on skip/seek
    /// when we tear down and rebuild the prefetch window).
    func reset(to newValue: Int) {
        for w in waiters { w.resume() }
        waiters.removeAll()
        value = newValue
    }
}
