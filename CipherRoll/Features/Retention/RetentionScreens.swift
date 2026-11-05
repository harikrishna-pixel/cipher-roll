import StoreKit
import SwiftUI
import UIKit
import UserNotifications

struct NotificationPrimerScreen: View {
    var onAllow: () -> Void
    var onNotNow: () -> Void
    var onSamples: () -> Void

    var body: some View {
        CipherScreen {
            ScrollView {
            VStack(spacing: CipherSpace.s16) {
                HStack { CipherBackButton(action: onNotNow); Spacer() }
                Image(systemName: "bell.fill")
                    .foregroundStyle(CipherColor.gold)
                    .frame(width: 72, height: 72)
                    .background(CipherColor.hero, in: RoundedRectangle(cornerRadius: 18))
                    .accessibilityHidden(true)
                Text("Stay in the loop, quietly")
                    .font(CipherFont.title)
                    .foregroundStyle(CipherColor.ink)
                    .multilineTextAlignment(.center)
                Text("Only useful messages. No ads, no streak pressure.")
                    .font(CipherFont.body)
                    .foregroundStyle(CipherColor.sub)
                VStack(spacing: 0) {
                    point("Import finished", "When a large import is done")
                    Divider()
                    point("Trial reminder", "Before a trial ends")
                    Divider()
                    point("Weekly summary", "What stayed private this week")
                }
                .background(CipherColor.card, in: RoundedRectangle(cornerRadius: CipherRadius.card))
                Text("Messages never show what is in your vault. You can turn them off any time.")
                    .font(CipherFont.caption)
                    .foregroundStyle(CipherColor.sub)
                    .multilineTextAlignment(.center)
                Button("Allow notifications", action: onAllow).buttonStyle(CipherGoldButtonStyle())
                Button("See sample messages", action: onSamples)
                    .font(CipherFont.button)
                    .foregroundStyle(CipherColor.link)
                    .frame(minHeight: 44)
                Button("Not now", action: onNotNow)
                    .font(CipherFont.button)
                    .foregroundStyle(CipherColor.sub)
                    .frame(minHeight: CipherA11y.minimumTarget)
            }
            .padding(CipherSpace.s20)
            }
        }
    }

    private func point(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(CipherFont.button).foregroundStyle(CipherColor.ink)
            Text(detail).font(CipherFont.caption).foregroundStyle(CipherColor.sub)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(CipherSpace.s16)
    }
}

struct NotificationSamplesScreen: View {
    var onBack: () -> Void

    private let samples = [
        "CipherRoll is ready. Review your recent import when you like.",
        "Your free trial ends tomorrow. Nothing is deleted, and one vault stays free.",
        "Still here. Your vault is ready when you are.",
        "Your weekly summary is ready. Tap to see your week."
    ]

    var body: some View {
        CipherScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: CipherSpace.s12) {
                    CipherBackButton(action: onBack)
                    Text("Sample messages").font(CipherFont.h2).foregroundStyle(CipherColor.ink)
                    ForEach(samples, id: \.self) { sample in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("CipherRoll").font(CipherFont.button).foregroundStyle(CipherColor.ink)
                            Text(sample).font(CipherFont.body).foregroundStyle(CipherColor.sub)
                        }
                        .padding(CipherSpace.s16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(CipherColor.card, in: RoundedRectangle(cornerRadius: CipherRadius.card))
                    }
                    Text("Each shows once, never shows file names, and can be turned off.")
                        .font(CipherFont.caption)
                        .foregroundStyle(CipherColor.sub)
                }
                .padding(CipherSpace.s20)
            }
        }
    }
}

struct WeeklyRecapSheet: View {
    var added: Int
    var blocked: Int
    var planLine: String
    var onDone: () -> Void
    var onUsage: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: CipherSpace.s16) {
            Text("YOUR WEEK IN CIPHERROLL").font(CipherFont.caption).foregroundStyle(CipherColor.sub)
            Text("Your private things stayed private.")
                .font(CipherFont.title)
                .foregroundStyle(CipherColor.ink)
            line("\(added) items added", "Photos, videos and files")
            line("\(blocked) wrong PIN attempts blocked", "Your vault stayed locked")
            line("0 items uploaded", "Vault contents stay on this iPhone")
            Text(planLine)
                .font(CipherFont.body)
                .foregroundStyle(CipherColor.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(CipherSpace.s12)
                .background(CipherColor.tint, in: RoundedRectangle(cornerRadius: 12))
            Button("Done", action: onDone).buttonStyle(CipherGoldButtonStyle())
            Button("View usage", action: onUsage)
                .font(CipherFont.button)
                .foregroundStyle(CipherColor.link)
                .frame(minHeight: 44)
                .frame(maxWidth: .infinity)
        }
        .padding(CipherSpace.s24)
        .presentationDetents([.medium, .large])
    }

    private func line(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(CipherFont.button).foregroundStyle(CipherColor.ink)
            Text(detail).font(CipherFont.caption).foregroundStyle(CipherColor.sub)
        }
    }
}

struct InviteFriendSheet: View {
    @State private var email: String
    @State private var code: String
    @State private var status: String?
    var onShare: (String) -> Void
    var onClose: () -> Void
    var onOpened: () -> Void

    init(email: String, code: String, onShare: @escaping (String) -> Void, onClose: @escaping () -> Void, onOpened: @escaping () -> Void) {
        _email = State(initialValue: email)
        _code = State(initialValue: code)
        self.onShare = onShare
        self.onClose = onClose
        self.onOpened = onOpened
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CipherSpace.s16) {
                Text("Give a friend 7 days of Pro")
                    .font(CipherFont.title)
                    .foregroundStyle(CipherColor.ink)
                Text("You get 7 days too when they join and the invite is confirmed. Up to 10 friends a year.")
                    .font(CipherFont.body)
                    .foregroundStyle(CipherColor.sub)
                Text("MESSAGE PREVIEW")
                    .font(CipherFont.caption)
                    .foregroundStyle(CipherColor.sub)
                Text(ReferralRules.message(code: code))
                    .font(CipherFont.body)
                    .foregroundStyle(CipherColor.ink)
                    .padding(CipherSpace.s12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(CipherColor.tint, in: RoundedRectangle(cornerRadius: 12))
                TextField("Email for invites (optional)", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .accessibilityLabel("Email for invites")
                HStack {
                    Text(code)
                        .font(CipherFont.button)
                        .foregroundStyle(CipherColor.ink)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .overlay(RoundedRectangle(cornerRadius: 22).stroke(CipherColor.line, style: StrokeStyle(lineWidth: 1, dash: [4])))
                    Button("Copy link") {
                        UIPasteboard.general.string = "cipherroll.app/i/\(code)"
                    }
                    .font(CipherFont.button)
                    .foregroundStyle(CipherColor.ink)
                    .frame(minHeight: 44)
                    .padding(.horizontal, CipherSpace.s12)
                    .overlay(Capsule().stroke(CipherColor.line, lineWidth: 1))
                }
                Button("Send a message") {
                    AppGroupDefaults.suite.set(email, forKey: RetentionKeys.inviteEmail)
                    onShare(ReferralRules.message(code: code))
                }
                .buttonStyle(CipherGoldButtonStyle())
                Button("I have a code") { redeem() }
                    .font(CipherFont.button)
                    .foregroundStyle(CipherColor.link)
                    .frame(minHeight: 44)
                if let status {
                    Text(status).font(CipherFont.caption).foregroundStyle(CipherColor.sub)
                }
                Button("Maybe later", action: onClose)
                    .font(CipherFont.button)
                    .foregroundStyle(CipherColor.link)
                    .frame(minHeight: 44)
            }
            .padding(CipherSpace.s24)
        }
        .onAppear(perform: onOpened)
        .presentationDetents([.large])
    }

    private func redeem() {
        let already = AppGroupDefaults.suite.integer(forKey: RetentionKeys.rewardsThisYear)
        let decision = ReferralRules.apply(server: UnavailableReferralServer().redeem(code: code), already: already)
        status = decision.granted ? "7 days of Pro are ready." : ReferralRules.unavailable
    }
}

struct MoreAppsScreen: View {
    var onBack: () -> Void
    var onOpen: () -> Void
    var onTap: (MarberxApp) -> Void

    var body: some View {
        CipherScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: CipherSpace.s16) {
                    HStack {
                        CipherBackButton(action: onBack)
                        Text("More from Marberx").font(CipherFont.h2).foregroundStyle(CipherColor.ink)
                        Spacer()
                    }
                    Text("Small, private apps made by the same team. They open in the App Store.")
                        .font(CipherFont.body)
                        .foregroundStyle(CipherColor.sub)
                    VStack(spacing: 0) {
                        ForEach(MarberxApp.allCases) { app in
                            HStack {
                                Text(app.letter)
                                    .font(CipherFont.button)
                                    .foregroundStyle(CipherColor.onGold)
                                    .frame(width: 44, height: 44)
                                    .background(CipherColor.hero, in: RoundedRectangle(cornerRadius: 12))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(app.title).font(CipherFont.button).foregroundStyle(CipherColor.ink)
                                    Text(app.detail).font(CipherFont.caption).foregroundStyle(CipherColor.sub)
                                }
                                Spacer()
                                Button("View") { onTap(app) }
                                    .font(CipherFont.button)
                                    .foregroundStyle(CipherColor.ink)
                                    .frame(minWidth: 64, minHeight: 44)
                                    .background(CipherColor.tint, in: Capsule())
                            }
                            .padding(CipherSpace.s12)
                        }
                    }
                    .background(CipherColor.card, in: RoundedRectangle(cornerRadius: CipherRadius.card))
                    Text("This page shows links. It never reads anything from your vault.")
                        .font(CipherFont.caption)
                        .foregroundStyle(CipherColor.sub)
                }
                .padding(CipherSpace.s20)
            }
        }
        .onAppear(perform: onOpen)
    }
}

struct HelpListScreen: View {
    var onBack: () -> Void
    var onOpen: (HelpArticle) -> Void
    var onContact: () -> Void
    @State private var query = ""
    private var biometryName: String { BiometryLabel.current() }

    var body: some View {
        CipherScreen {
            VStack(alignment: .leading, spacing: CipherSpace.s12) {
                HStack {
                    CipherBackButton(action: onBack)
                    Text("Help").font(CipherFont.h2).foregroundStyle(CipherColor.ink)
                    Spacer()
                }
                TextField("Search help", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Search help")
                ScrollView {
                    VStack(alignment: .leading, spacing: CipherSpace.s16) {
                        ForEach(HelpCatalog.sections, id: \.self) { section in
                            let articles = HelpCatalog.articles.filter { article in
                                article.section == section && HelpCatalog.matches(HelpCatalog.showing(article, biometry: biometryName), query: query)
                            }
                            if !articles.isEmpty {
                                Text(section.uppercased()).font(CipherFont.caption).foregroundStyle(CipherColor.sub)
                                VStack(spacing: 0) {
                                    ForEach(articles) { article in
                                        let shown = HelpCatalog.showing(article, biometry: biometryName)
                                        Button {
                                            onOpen(article)
                                        } label: {
                                            HStack {
                                                Text(shown.question)
                                                    .font(CipherFont.button)
                                                    .foregroundStyle(CipherColor.ink)
                                                    .multilineTextAlignment(.leading)
                                                Spacer()
                                                Image(systemName: "chevron.right").foregroundStyle(CipherColor.sub)
                                            }
                                            .padding(CipherSpace.s16)
                                            .frame(minHeight: 52)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .background(CipherColor.card, in: RoundedRectangle(cornerRadius: CipherRadius.card))
                            }
                        }
                        Button("Contact us", action: onContact)
                            .buttonStyle(CipherOutlineButtonStyle())
                    }
                }
            }
            .padding(CipherSpace.s20)
        }
    }
}

struct HelpArticleScreen: View {
    var article: HelpArticle
    var onBack: () -> Void
    private var shown: HelpArticle { HelpCatalog.showing(article, biometry: BiometryLabel.current()) }

    var body: some View {
        CipherScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: CipherSpace.s16) {
                    CipherBackButton(action: onBack)
                    Text(shown.question).font(CipherFont.title).foregroundStyle(CipherColor.ink)
                    Text(shown.answer).font(CipherFont.body).foregroundStyle(CipherColor.ink)
                }
                .padding(CipherSpace.s20)
            }
        }
    }
}

struct ContactSupportSheet: View {
    var onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: CipherSpace.s16) {
            Text("Contact us").font(CipherFont.h2).foregroundStyle(CipherColor.ink)
            Text("Do not include your PIN or recovery key in any message.")
                .font(CipherFont.body)
                .foregroundStyle(CipherColor.sub)
            Text("A support address is not set in this version.")
                .font(CipherFont.caption)
                .foregroundStyle(CipherColor.sub)
            Button("Close", action: onClose).buttonStyle(CipherGoldButtonStyle())
        }
        .padding(CipherSpace.s24)
        .presentationDetents([.medium])
    }
}

struct ToastBanner: View {
    var toast: CipherToast
    var onAction: () -> Void

    var body: some View {
        HStack {
            Text(toast.title)
                .font(CipherFont.button)
                .foregroundStyle(.white)
            Spacer()
            if let action = toast.action {
                Button(action, action: onAction)
                    .font(CipherFont.button)
                    .foregroundStyle(CipherColor.gold)
                    .frame(minHeight: 44)
            }
        }
        .padding(.horizontal, CipherSpace.s16)
        .frame(minHeight: 52)
        .background(CipherColor.hero, in: Capsule())
        .padding(.horizontal, CipherSpace.s16)
        .accessibilityLabel(toast.title)
    }
}

enum QuietNotifications {
    static func ask(analytics: any AnalyticsClient) {
        analytics.track("permission_requested", properties: ["type": "notifications"])
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            DispatchQueue.main.async {
                analytics.track("permission_result", properties: [
                    "type": "notifications",
                    "result": granted ? "authorized" : "denied"
                ])
                if granted { scheduleWeekly() }
            }
        }
    }

    static func scheduleWeekly() {
        let content = UNMutableNotificationContent()
        content.title = "CipherRoll"
        content.body = "Your weekly summary is ready. Tap to see your week."
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 7 * 86_400, repeats: false)
        let request = UNNotificationRequest(identifier: "app.cipherroll.weekly.summary", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}

struct ToastGalleryScreen: View {
    private let rows: [CipherToast] = [
        CipherToast(kind: .success, title: "12 items imported safely", action: "View"),
        CipherToast(kind: .undo, title: "Moved to Recently Deleted", action: "Undo"),
        CipherToast(kind: .info, title: "Originals are still in Photos", action: "Review"),
        CipherToast(kind: .saved, title: "Recovery key copied", action: nil),
        CipherToast(kind: .offline, title: "Offline. Everything still works.", action: nil),
        CipherToast(kind: .error, title: "Could not import 1 item. Tap to try again", action: "Retry")
    ]

    var body: some View {
        CipherScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: CipherSpace.s12) {
                    Text("Toasts and messages").font(CipherFont.h2).foregroundStyle(CipherColor.ink)
                    ForEach(rows) { toast in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(toast.kind.rawValue.uppercased()).font(CipherFont.caption).foregroundStyle(CipherColor.sub)
                            ToastBanner(toast: toast, onAction: {})
                        }
                    }
                    Text(ToastRules.note).font(CipherFont.caption).foregroundStyle(CipherColor.sub)
                }
                .padding(CipherSpace.s20)
            }
        }
    }
}

enum ReviewRequester {
    static func request(moment: String, analytics: any AnalyticsClient) {
        guard ReviewPrompt.shouldRequest(
            moment: moment,
            alreadyRequested: AppGroupDefaults.suite.bool(forKey: RetentionKeys.reviewRequested),
            session: RetentionSession.current
        ) else { return }
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        SKStoreReviewController.requestReview(in: scene)
        AppGroupDefaults.suite.set(true, forKey: RetentionKeys.reviewRequested)
        analytics.track("rating_requested", properties: ["moment": moment])
    }
}
