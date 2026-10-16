import Foundation
import Observation
import StoreKit

/// StoreKit 2 wrapper for the one-time "Botcamp Pro" unlock (non-consumable).
/// Product ID is a PLACEHOLDER until it's created in App Store Connect. Local testing uses Botcamp.storekit.
@Observable
@MainActor
final class ProStore {
    static let proProductID = "com.pak209.botcamp.pro"   // placeholder, ~$4.99
    private(set) var product: Product?
    private(set) var hasPro = false
    private(set) var isBusy = false
    var errorMessage: String?
    private var updates: Task<Void, Never>?

    func start() async {
        updates?.cancel()
        updates = Task { [weak self] in
            for await result in Transaction.updates { await self?.handle(result) }
        }
        do { product = try await Product.products(for: [Self.proProductID]).first }
        catch { errorMessage = "Store unavailable right now." }
        await refreshEntitlements()
    }

    func refreshEntitlements() async {
        var owned = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let t) = result, t.productID == Self.proProductID, t.revocationDate == nil { owned = true }
        }
        hasPro = owned
    }

    func purchase() async {
        guard let product else { errorMessage = "Pro isn't available yet."; return }
        isBusy = true; defer { isBusy = false }
        do {
            switch try await product.purchase() {
            case .success(let result): await handle(result)
            case .pending, .userCancelled: break
            @unknown default: break
            }
        } catch { errorMessage = error.localizedDescription }
    }

    /// Required by App Review: a visible Restore Purchases action.
    func restore() async {
        isBusy = true; defer { isBusy = false }
        try? await AppStore.sync()
        await refreshEntitlements()
    }

    private func handle(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let t) = result else { return }
        if t.productID == Self.proProductID { hasPro = t.revocationDate == nil }
        await t.finish()
    }
}
