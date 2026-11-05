import SwiftUI

struct PaywallScreen: View {
    @ObservedObject var plan: PlanModel
    var request: PaywallRequest

    var body: some View {
        CipherScreen {
            if plan.offline {
                offline
            } else {
                offer
            }
        }
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .alert("Purchases", isPresented: Binding(
            get: { plan.message != nil },
            set: { if !$0 { plan.message = nil } }
        )) {
            Button("OK", role: .cancel) { plan.message = nil }
        } message: {
            Text(plan.message ?? "")
        }
    }

    private var offer: some View {
        let header = PaywallCopy.header(
            trigger: request.trigger,
            trialEligible: plan.trialEligible,
            limitKind: request.limitKind,
            itemCount: request.itemCount
        )
        return ScrollView {
            VStack(spacing: CipherSpace.s8) {
                    HStack {
                        Spacer()
                        closeButton(.x)
                    }
                    hero
                    if let badge = header.badge {
                        Text(badge)
                            .font(CipherFont.caption)
                            .foregroundStyle(CipherColor.ink)
                            .padding(.horizontal, 12)
                            .frame(minHeight: 32)
                            .background(CipherColor.tint, in: Capsule())
                    }
                    Text(header.title)
                        .font(CipherFont.titleSmall)
                        .foregroundStyle(CipherColor.ink)
                        .multilineTextAlignment(.center)
                    Text(header.subtitle)
                        .font(CipherFont.body)
                        .foregroundStyle(CipherColor.sub)
                        .multilineTextAlignment(.center)
                    VStack(alignment: .leading, spacing: CipherSpace.s8) {
                        feature(CipherIcon.image.image, PaywallCopy.features[0])
                        feature(CipherIcon.lock.image, PaywallCopy.features[1])
                        feature(CipherIcon.shield.image, PaywallCopy.features[2])
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    ForEach(PaidPlan.displayOrder) { paid in
                        planCard(paid)
                    }
                }
                .padding(CipherSpace.s20)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: CipherSpace.s8) {
                Button(PaywallCopy.buttonTitle(plan.selected, trialEligible: plan.trialEligible)) {
                    Task { await plan.buy() }
                }
                .buttonStyle(CipherGoldButtonStyle())
                Text(PaywallCopy.legal(plan.selected, prices: plan.prices, trialEligible: plan.trialEligible))
                    .font(CipherFont.caption)
                    .foregroundStyle(CipherColor.sub)
                    .multilineTextAlignment(.center)
                Button(PaywallCopy.dismissTitle(request.trigger)) {
                    plan.close(PaywallCopy.dismiss(request.trigger))
                }
                .font(CipherFont.button)
                .foregroundStyle(CipherColor.ink)
                .frame(minHeight: 36)
                links
            }
            .padding(.horizontal, CipherSpace.s20)
            .padding(.top, CipherSpace.s8)
            .padding(.bottom, CipherSpace.s12)
            .background(CipherColor.bg)
        }
    }

    private var offline: some View {
        VStack(spacing: CipherSpace.s16) {
            HStack {
                Spacer()
                closeButton(.x)
            }
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(CipherColor.amber)
                .frame(width: 72, height: 72)
                .background(CipherColor.amberBg, in: Circle())
            Text("Cannot load plans")
                .font(CipherFont.title)
                .foregroundStyle(CipherColor.ink)
            Text("Check your internet connection and try again.\nYour vault still works offline.")
                .font(CipherFont.body)
                .foregroundStyle(CipherColor.sub)
                .multilineTextAlignment(.center)
            Spacer()
            Button("Try again") {
                Task { await plan.refresh() }
            }
            .buttonStyle(CipherGoldButtonStyle())
            Button("Continue with Free") { plan.close(.continueFree) }
                .font(CipherFont.button)
                .foregroundStyle(CipherColor.link)
                .frame(minHeight: 44)
        }
        .padding(CipherSpace.s24)
    }

    private var hero: some View {
        CipherIcon.lock.image
            .foregroundStyle(CipherColor.gold)
            .frame(width: 28, height: 28)
            .frame(width: 52, height: 52)
            .background(CipherColor.hero, in: RoundedRectangle(cornerRadius: 16))
            .accessibilityHidden(true)
    }

    private func feature(_ image: Image, _ title: String) -> some View {
        HStack(spacing: CipherSpace.s12) {
            image
                .resizable()
                .scaledToFit()
                .frame(width: 18, height: 18)
                .foregroundStyle(CipherColor.tintInk)
                .frame(width: 32, height: 32)
                .background(CipherColor.tint, in: RoundedRectangle(cornerRadius: 8))
            Text(title).font(CipherFont.body).foregroundStyle(CipherColor.ink)
        }
    }

    private func planCard(_ paid: PaidPlan) -> some View {
        let on = plan.selected == paid
        return Button {
            plan.select(paid)
        } label: {
            HStack(alignment: .center, spacing: CipherSpace.s12) {
                Circle()
                    .stroke(CipherColor.ink, lineWidth: 1.5)
                    .background(Circle().fill(on ? CipherColor.ink : Color.clear).padding(5))
                    .frame(width: 22, height: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text(paid.rawValue.capitalized).font(CipherFont.button).foregroundStyle(CipherColor.ink)
                    Text(PaywallCopy.cardDetail(paid, prices: plan.prices, trialEligible: plan.trialEligible))
                        .font(CipherFont.caption)
                        .foregroundStyle(CipherColor.sub)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    if let badge = PaywallCopy.badge(paid, prices: plan.prices, trialEligible: plan.trialEligible) {
                        Text(badge)
                            .font(CipherFont.caption)
                            .foregroundStyle(CipherColor.onGold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(CipherColor.gold, in: Capsule())
                    }
                    Text(PaywallCopy.cardPrice(paid, prices: plan.prices))
                        .font(CipherFont.button)
                        .foregroundStyle(CipherColor.ink)
                }
            }
            .padding(.horizontal, CipherSpace.s12)
            .padding(.vertical, 6)
            .background(on ? CipherColor.amberBg : CipherColor.card, in: RoundedRectangle(cornerRadius: CipherRadius.card))
            .overlay(RoundedRectangle(cornerRadius: CipherRadius.card).stroke(on ? CipherColor.ink : CipherColor.line, lineWidth: on ? 1.5 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(paid.rawValue.capitalized), \(PaywallCopy.cardPrice(paid, prices: plan.prices))")
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private var links: some View {
        HStack(spacing: CipherSpace.s16) {
            Button("Restore") { Task { await plan.restore() } }
                .frame(minHeight: CipherA11y.minimumTarget)
            Button("Terms") { plan.message = PaywallCopy.valueLine }
                .frame(minHeight: CipherA11y.minimumTarget)
            Button("Privacy") { plan.message = "Vault contents stay on this iPhone. Apple handles the purchase. CipherRoll does not send vault contents." }
                .frame(minHeight: CipherA11y.minimumTarget)
        }
        .font(CipherFont.caption)
        .foregroundStyle(CipherColor.sub)
    }

    private func closeButton(_ dismiss: PaywallDismiss) -> some View {
        Button {
            plan.close(dismiss)
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(CipherColor.sub)
                .frame(width: 44, height: 44)
        }
        .accessibilityLabel("Close")
    }
}

struct TrialEndedScreen: View {
    @ObservedObject var plan: PlanModel
    @State private var chosen: String = "personal"

    var body: some View {
        CipherScreen {
            ScrollView {
                VStack(spacing: CipherSpace.s16) {
                    CipherIcon.shield.image
                        .foregroundStyle(CipherColor.gold)
                        .frame(width: 36, height: 36)
                        .frame(width: 72, height: 72)
                        .background(CipherColor.hero, in: RoundedRectangle(cornerRadius: 20))
                    Text("Thanks for trying CipherRoll!")
                        .font(CipherFont.title)
                        .foregroundStyle(CipherColor.ink)
                        .multilineTextAlignment(.center)
                    Text("Nothing was deleted. Choose the vault you would like to keep editing on the Free plan.")
                        .font(CipherFont.body)
                        .foregroundStyle(CipherColor.sub)
                        .multilineTextAlignment(.center)
                    ForEach(plan.endedVaults) { vault in
                        vaultCard(vault)
                    }
                    Text("Nothing is deleted. You can add more to any vault whenever you choose unlimited.")
                        .font(CipherFont.caption)
                        .foregroundStyle(CipherColor.sub)
                        .multilineTextAlignment(.center)
                    Button("Keep \(selectedName) free") { plan.keepEditing(chosen) }
                        .buttonStyle(CipherGoldButtonStyle())
                    Button("See unlimited plans") { plan.openPlansFromTrialEnded() }
                        .font(CipherFont.button)
                        .foregroundStyle(CipherColor.link)
                        .frame(minHeight: 44)
                }
                .padding(CipherSpace.s24)
                .frame(maxWidth: 560)
            }
        }
        .onAppear {
            chosen = plan.endedVaults.first(where: \.editable)?.id ?? plan.endedVaults.first?.id ?? "personal"
        }
    }

    private var selectedName: String {
        plan.endedVaults.first { $0.id == chosen }?.name ?? "Personal"
    }

    private func vaultCard(_ vault: EndedVault) -> some View {
        let on = chosen == vault.id
        return Button {
            chosen = vault.id
        } label: {
            VStack(alignment: .leading, spacing: CipherSpace.s8) {
                HStack {
                    CipherIcon.lock.image
                        .foregroundStyle(CipherColor.tintInk)
                        .frame(width: 36, height: 36)
                        .background(CipherColor.tint, in: RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading) {
                        Text(vault.name).font(CipherFont.button).foregroundStyle(CipherColor.ink)
                        Text(vault.summary).font(CipherFont.caption).foregroundStyle(CipherColor.sub)
                    }
                    Spacer()
                    Circle()
                        .stroke(CipherColor.ink, lineWidth: 1.5)
                        .background(Circle().fill(on ? CipherColor.ink : Color.clear).padding(5))
                        .frame(width: 22, height: 22)
                }
                Text(on ? "Stays free and editable" : "Open, view and export any time")
                    .font(CipherFont.caption)
                    .foregroundStyle(on ? CipherColor.onGold : CipherColor.sub)
                    .padding(.horizontal, 10)
                    .frame(minHeight: 28)
                    .background(on ? CipherColor.gold : CipherColor.tint, in: Capsule())
            }
            .padding(CipherSpace.s12)
            .background(on ? CipherColor.amberBg : CipherColor.card, in: RoundedRectangle(cornerRadius: CipherRadius.card))
            .overlay(RoundedRectangle(cornerRadius: CipherRadius.card).stroke(on ? CipherColor.ink : CipherColor.line, lineWidth: on ? 1.5 : 1))
        }
        .buttonStyle(.plain)
    }
}

@MainActor
struct PaywallScreenshot: View {
    var name: String
    @StateObject private var plan: PlanModel

    init(name: String) {
        self.name = name
        let eligible = name != "paywallTrialUsed"
        let offline = name == "paywallOffline"
        let selected: PaidPlan = name == "paywallWeekly" ? .weekly : (name == "paywallLifetime" ? .lifetime : .yearly)
        let vaults = [
            EndedVault(id: "personal", name: "Personal", summary: "85 photos · 3 videos · 2 files · 5 notes", editable: true),
            EndedVault(id: "work", name: "Work", summary: "12 photos · 4 files", editable: false)
        ]
        _plan = StateObject(wrappedValue: PaywallPreview.model(
            eligible: eligible,
            offline: offline,
            selected: selected,
            vaults: name == "trialEnded" ? vaults : []
        ))
    }

    var body: some View {
        if name == "trialEnded" {
            TrialEndedScreen(plan: plan)
        } else {
            PaywallScreen(plan: plan, request: PaywallRequest(
                trigger: trigger,
                limitKind: name == "paywallLimit" ? .video : nil,
                itemCount: name == "paywallValue" ? 52 : 0
            ))
        }
    }

    private var trigger: PaywallTrigger {
        switch name {
        case "paywallExit": .exit
        case "paywallLimit": .limitVideos
        case "paywallValue": .valueFraming
        default: .onboarding
        }
    }
}

/// Screenshot stand-in. It does not talk to the store.
@MainActor
enum PaywallPreview {
    static func model(eligible: Bool, offline: Bool, selected: PaidPlan, vaults: [EndedVault] = []) -> PlanModel {
        let model = PlanModel(client: PreviewPurchaseClient(eligible: eligible, offline: offline), defaults: UserDefaults(suiteName: "app.cipherroll.paywall.preview.\(UUID().uuidString)") ?? .standard)
        model.trialEligible = eligible
        model.offline = offline
        model.selected = selected
        model.prices = .catalog
        model.endedVaults = vaults
        return model
    }
}

private struct PreviewPurchaseClient: PurchaseClient {
    var eligible: Bool
    var offline: Bool

    func loadCatalog() async -> PurchaseCatalog {
        if offline { return .offline }
        var offers: [PaidPlan: PlanOffer] = [:]
        let prices = PlanPrices.catalog
        for plan in PaidPlan.allCases {
            offers[plan] = PlanOffer(plan: plan, displayPrice: prices.text(plan), price: prices.amount(plan))
        }
        return PurchaseCatalog(offers: offers, trialEligible: eligible, offline: false)
    }

    func purchase(_ plan: PaidPlan) async -> PurchaseOutcome { .cancelled }
    func restore() async -> RestoreOutcome { .none }
    func currentTier() async -> PlanTier { .free }
}
