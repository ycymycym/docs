import Foundation

/// Product identifiers, kept in one place and mirrored in the `.storekit` file
/// and App Store Connect. Pricing per brief §5.
public enum ProductID {
    /// Primary CTA — lifetime non-consumable. "Pay once. No subscription, ever."
    public static let lifetime = "au.com.flysky.outloud.lifetime"
    /// Anchor only — auto-renewable monthly, shown crossed-out against lifetime.
    public static let monthly = "au.com.flysky.outloud.monthly"

    public static let all: [String] = [lifetime, monthly]
}
