import Foundation

/// Identifiers shared between the host app and the Share Extension.
///
/// The Share Extension cannot run synthesis (tight ~120MB budget — see brief
/// §4), so it only writes extracted text into the App Group container and
/// deep-links the host app, which picks the document up and runs the pipeline.
public enum AppGroup {

    /// Keep this in sync with both targets' `.entitlements` App Group value and
    /// the App Group capability in the Apple Developer portal.
    public static let identifier = "group.au.com.flysky.outloud"

    /// Custom URL scheme the extension uses to launch the host app.
    /// Registered under CFBundleURLTypes in the host app Info.plist.
    public static let urlScheme = "outloud"

    /// Shared container root. Inbox documents handed off by the extension live
    /// under `Inbox/`.
    public static var containerURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }

    public static var inboxURL: URL? {
        guard let base = containerURL else { return nil }
        let inbox = base.appendingPathComponent("Inbox", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: inbox, withIntermediateDirectories: true)
        return inbox
    }

    /// Builds the deep link the extension opens, e.g. `outloud://open?doc=<id>`.
    public static func openURL(documentID: String) -> URL? {
        var components = URLComponents()
        components.scheme = urlScheme
        components.host = "open"
        components.queryItems = [URLQueryItem(name: "doc", value: documentID)]
        return components.url
    }

    /// Parses a deep link back into a document id. Returns nil if it isn't ours.
    public static func documentID(from url: URL) -> String? {
        guard url.scheme == urlScheme, url.host == "open" else { return nil }
        return URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "doc" })?.value
    }
}
