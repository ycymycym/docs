import Foundation
import StoreKit

/// StoreKit 2 wrapper: loads products, runs purchases, listens for transaction
/// updates, and exposes a single `isUnlocked` entitlement that removes the
/// free-tier length cap.
///
/// No server receipt validation: the only entitlement is a non-consumable (and
/// a subscription anchor), so the on-device `Transaction.currentEntitlements`
/// is authoritative — Apple signs them (brief §3/§5).
@MainActor
public final class StoreManager: ObservableObject {

    @Published public private(set) var products: [Product] = []
    @Published public private(set) var isUnlocked = false
    @Published public private(set) var isLoading = false
    @Published public var lastError: String?

    private var updatesTask: Task<Void, Never>?

    public init() {
        // Listen for transactions that arrive outside an explicit purchase
        // (Ask-to-Buy approvals, restores, purchases on another device).
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                await self?.handle(verification: update)
            }
        }
    }

    deinit { updatesTask?.cancel() }

    // MARK: Lifecycle

    public func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let loaded = try await Product.products(for: ProductID.all)
            // Sort so lifetime (primary) renders first.
            products = loaded.sorted { lhs, _ in lhs.id == ProductID.lifetime }
            await refreshEntitlements()
        } catch {
            lastError = error.localizedDescription
            Log.paywall.error("Product load failed: \(error.localizedDescription)")
        }
    }

    public func product(id: String) -> Product? {
        products.first(where: { $0.id == id })
    }

    // MARK: Purchase / restore

    public func purchase(_ product: Product) async {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                await handle(verification: verification)
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            lastError = error.localizedDescription
            Log.paywall.error("Purchase failed: \(error.localizedDescription)")
        }
    }

    /// Restore Purchases button. `currentEntitlements` already reflects the
    /// account; `AppStore.sync()` forces a refresh on a fresh install.
    public func restore() async {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: Entitlement evaluation

    private func refreshEntitlements() async {
        var unlocked = false
        for await entitlement in Transaction.currentEntitlements {
            if case .verified(let transaction) = entitlement,
               ProductID.all.contains(transaction.productID),
               transaction.revocationDate == nil {
                unlocked = true
            }
        }
        isUnlocked = unlocked
        Log.paywall.info("Entitlement refreshed: unlocked=\(unlocked)")
    }

    private func handle(verification: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = verification else {
            lastError = "This purchase couldn't be verified."
            return
        }
        await transaction.finish()
        await refreshEntitlements()
    }
}
