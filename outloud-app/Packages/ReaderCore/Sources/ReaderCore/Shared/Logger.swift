import Foundation
import os

/// Thin wrapper over `os.Logger` with category-scoped subsystems so signposts
/// for the synthesis/playback hot path are easy to filter in Instruments.
public enum Log {
    private static let subsystem = "au.com.flysky.outloud"

    public static let engine = Logger(subsystem: subsystem, category: "engine")
    public static let playback = Logger(subsystem: subsystem, category: "playback")
    public static let extraction = Logger(subsystem: subsystem, category: "extraction")
    public static let paywall = Logger(subsystem: subsystem, category: "paywall")
    public static let model = Logger(subsystem: subsystem, category: "model")
}
