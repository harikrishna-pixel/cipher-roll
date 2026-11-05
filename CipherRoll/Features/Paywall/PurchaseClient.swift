import Foundation
import StoreKit

struct PlanOffer: Equatable {
    var plan: PaidPlan
    var displayPrice: String
    var price: Decimal
}

struct PurchaseCatalog: Equatable {
    var offers: [PaidPlan: PlanOffer]
    var trialEligible: Bool
    var offline: Bool

    static let offline = PurchaseCatalog(offers: [:], trialEligible: false, offline: true)

    var prices: PlanPrices {
        guard !offline,
              let weekly = offers[.weekly],
              let yearly = offers[.yearly],
              let lifetime = offers[.lifetime] else {
            return .catalog
        }
        return PlanPrices(
            weekly: weekly.price,
            yearly: yearly.price,
            lifetime: lifetime.price,
            weeklyText: weekly.displayPrice,
            yearlyText: yearly.displayPrice,
            lifetimeText: lifetime.displayPrice
        )
    }
}

enum PurchaseOutcome: Equatable {
    case success(PlanTier)
    case cancelled
    case pending
    case failed(code: String)
    case offline
}

enum RestoreOutcome: Equatable {
    case restored(PlanTier)
    case none
    case failed(code: String)
}

protocol PurchaseClient {
    func loadCatalog() async -> PurchaseCatalog
    func purchase(_ plan: PaidPlan) async -> PurchaseOutcome
    func restore() async -> RestoreOutcome
    func currentTier() async -> PlanTier
}

struct StoreKitPurchaseClient: PurchaseClient {
    func loadCatalog() async -> PurchaseCatalog {
        do {
            let products = try await Product.products(for: PaidPlan.allCases.map(\.productID))
            var offers: [PaidPlan: PlanOffer] = [:]
            for product in products {
                guard let plan = PaidPlan.from(productID: product.id) else { continue }
                offers[plan] = PlanOffer(plan: plan, displayPrice: product.displayPrice, price: product.price)
            }
            guard offers.count == PaidPlan.allCases.count else { return .offline }
            let yearly = products.first { $0.id == PaidPlan.yearly.productID }
            let eligible = await yearly?.subscription?.isEligibleForIntroOffer ?? false
            return PurchaseCatalog(offers: offers, trialEligible: eligible, offline: false)
        } catch {
            return .offline
        }
    }

    func purchase(_ plan: PaidPlan) async -> PurchaseOutcome {
        do {
            let products = try await Product.products(for: [plan.productID])
            guard let product = products.first else { return .offline }
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else { return .failed(code: "unverified") }
                let tier = Self.tier(for: transaction)
                await transaction.finish()
                return .success(tier)
            case .userCancelled:
                return .cancelled
            case .pending:
                return .pending
            @unknown default:
                return .failed(code: "unknown")
            }
        } catch is CancellationError {
            return .cancelled
        } catch let error as StoreKitError {
            switch error {
            case .networkError:
                return .offline
            case .userCancelled:
                return .cancelled
            default:
                return .failed(code: "store")
            }
        } catch let error as URLError where error.code == .notConnectedToInternet || error.code == .networkConnectionLost {
            return .offline
        } catch {
            return .failed(code: "store")
        }
    }

    func restore() async -> RestoreOutcome {
        do {
            try await AppStore.sync()
            let tier = await currentTier()
            return tier == .free ? .none : .restored(tier)
        } catch {
            return .failed(code: "restore")
        }
    }

    func currentTier() async -> PlanTier {
        var tier = PlanTier.free
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if let expiration = transaction.expirationDate, expiration < Date() { continue }
            tier = PlanTier.prefer(tier, Self.tier(for: transaction))
        }
        return tier
    }

    static func tier(for transaction: Transaction) -> PlanTier {
        guard let plan = PaidPlan.from(productID: transaction.productID) else { return .free }
        if plan == .yearly, transaction.offerType == .introductory {
            return .trial
        }
        switch plan {
        case .weekly: return .weekly
        case .yearly: return .yearly
        case .lifetime: return .lifetime
        }
    }
}

enum PurchaseClientFactory {
    /// RevenueCat starts only when a public SDK key is present. Otherwise StoreKit 2 is the purchase path.
    static func make() -> any PurchaseClient {
        if RevenueCatConfig.isConfigured {
            return RevenueCatPurchaseClient()
        }
        return StoreKitPurchaseClient()
    }
}
