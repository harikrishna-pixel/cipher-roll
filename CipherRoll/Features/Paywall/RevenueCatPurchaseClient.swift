import Foundation
import RevenueCat

enum RevenueCatConfig {
    static let entitlement = "pro"
    static let infoKey = "RevenueCatAPIKey"

    static var apiKey: String {
        let value = Bundle.main.object(forInfoDictionaryKey: infoKey) as? String ?? ""
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static var isConfigured: Bool { !apiKey.isEmpty }
}

/// StoreKit 2 through RevenueCat. Used only when `RevenueCatAPIKey` is set.
struct RevenueCatPurchaseClient: PurchaseClient {
    private let storeKit = StoreKitPurchaseClient()

    init() {
        guard RevenueCatConfig.isConfigured else { return }
        if !Purchases.isConfigured {
            Purchases.configure(withAPIKey: RevenueCatConfig.apiKey)
        }
    }

    func loadCatalog() async -> PurchaseCatalog {
        guard RevenueCatConfig.isConfigured else { return await storeKit.loadCatalog() }
        do {
            let offerings = try await Purchases.shared.offerings()
            guard let offering = offerings.current else { return await storeKit.loadCatalog() }
            var offers: [PaidPlan: PlanOffer] = [:]
            for package in offering.availablePackages {
                guard let plan = PaidPlan.from(productID: package.storeProduct.productIdentifier) else { continue }
                offers[plan] = PlanOffer(
                    plan: plan,
                    displayPrice: package.storeProduct.localizedPriceString,
                    price: package.storeProduct.price as Decimal
                )
            }
            guard offers.count == PaidPlan.allCases.count else { return await storeKit.loadCatalog() }
            let eligible = await storeKit.loadCatalog().trialEligible
            return PurchaseCatalog(offers: offers, trialEligible: eligible, offline: false)
        } catch {
            return .offline
        }
    }

    func purchase(_ plan: PaidPlan) async -> PurchaseOutcome {
        guard RevenueCatConfig.isConfigured else { return await storeKit.purchase(plan) }
        do {
            let offerings = try await Purchases.shared.offerings()
            guard let package = offerings.current?.availablePackages.first(where: {
                PaidPlan.from(productID: $0.storeProduct.productIdentifier) == plan
            }) else {
                return await storeKit.purchase(plan)
            }
            let result = try await Purchases.shared.purchase(package: package)
            let tier = Self.tier(from: result.customerInfo, productID: plan.productID)
            return .success(tier)
        } catch let error as ErrorCode {
            switch error {
            case .purchaseCancelledError: return .cancelled
            case .paymentPendingError: return .pending
            case .networkError, .offlineConnectionError: return .offline
            default: return .failed(code: "store")
            }
        } catch {
            return .failed(code: "store")
        }
    }

    func restore() async -> RestoreOutcome {
        guard RevenueCatConfig.isConfigured else { return await storeKit.restore() }
        do {
            let info = try await Purchases.shared.restorePurchases()
            let tier = Self.tier(from: info, productID: nil)
            return tier == .free ? .none : .restored(tier)
        } catch {
            return .failed(code: "restore")
        }
    }

    func currentTier() async -> PlanTier {
        guard RevenueCatConfig.isConfigured else { return await storeKit.currentTier() }
        do {
            let info = try await Purchases.shared.customerInfo()
            return Self.tier(from: info, productID: nil)
        } catch {
            return await storeKit.currentTier()
        }
    }

    static func tier(from info: CustomerInfo, productID: String?) -> PlanTier {
        guard info.entitlements[RevenueCatConfig.entitlement]?.isActive == true else { return .free }
        let identifier = productID ?? info.entitlements[RevenueCatConfig.entitlement]?.productIdentifier
        guard let identifier, let plan = PaidPlan.from(productID: identifier) else { return .yearly }
        let period = info.entitlements[RevenueCatConfig.entitlement]?.periodType
        if plan == .yearly, period == .trial { return .trial }
        switch plan {
        case .weekly: return .weekly
        case .yearly: return .yearly
        case .lifetime: return .lifetime
        }
    }
}
