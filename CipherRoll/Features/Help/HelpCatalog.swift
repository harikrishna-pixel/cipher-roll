import Foundation

struct HelpArticle: Identifiable, Equatable {
    var slug: String
    var section: String
    var question: String
    var answer: String
    var id: String { slug }
}

enum HelpCatalog {
    static let articles: [HelpArticle] = [
        article("what-is", "Getting started", "What is CipherRoll?", "A private vault on your iPhone for photos, videos, files and notes. It unlocks with {biometry}, a PIN, a pattern or a password."),
        article("need-account", "Getting started", "Do I need an account?", "No. The vault works without an account. An account is used for the invite feature."),
        article("add-items", "Getting started", "How do I add things?", "Tap Add, choose Photos, Videos, Files or Notes, then pick what to import. You can also use Share in other apps."),
        article("photo-access", "Getting started", "Does CipherRoll need access to all my photos?", "No. You choose the photos to add. Access is asked if you want CipherRoll to offer deleting the originals afterwards. Choose Selected Photos if you prefer."),
        article("originals", "Getting started", "Are my originals deleted when I import?", "No. After import we ask if you want to delete the originals from Photos. You decide. Deleted photos stay in Recently Deleted in Photos for about 30 days. With iCloud Photos on, they are removed on your other devices too."),
        article("hide-from-photos", "Getting started", "Why do my photos still show in the Photos app?", "The originals stay there until you delete them. Use Review and delete after importing."),
        article("vaults", "Getting started", "What is a vault?", "A separate space with its own lock, for example Personal and Work. The Free plan has 1 vault."),
        article("lock-types", "Locking and unlocking", "How can I lock a vault?", "PIN (at least 6 digits), pattern, password, custom phrase (8 or more characters), or a calculator-style PIN. {biometry} can be added as a shortcut."),
        article("face-id", "Locking and unlocking", "Is {biometry} the only lock?", "No. Face ID or Touch ID is a shortcut. If it fails, you use your PIN, pattern or password."),
        article("lock-first", "Locking and unlocking", "What do I see when I open the app?", "The unlock method you chose for that vault, right away. If you use {biometry}, it starts at once, and your PIN is there as a backup."),
        article("lock-timing", "Locking and unlocking", "When does the app lock?", "When you come back to it. In Settings you can choose Immediately, after 1 minute or after 5 minutes. The app switcher preview is hidden."),
        article("change-lock", "Locking and unlocking", "Can I change my lock later?", "The lock is chosen when you create the vault. Calculator-style lock can be turned on in Settings, then Privacy and lock, when your lock is a PIN."),
        article("calc-pin", "Locking and unlocking", "What is the calculator-style PIN?", "An optional unlock screen that looks like a simple calculator. You type your PIN and press =. It helps when someone glances at your screen. It is a privacy option in a vault app, not a real calculator. Turn it on in Settings, then Privacy and lock."),
        article("break-in", "Locking and unlocking", "What is the break-in selfie?", "An optional setting, off until you turn it on. If someone enters a wrong PIN several times, the front camera takes a photo. The photo stays on this iPhone and is not uploaded. It needs camera permission."),
        article("decoy-what", "Decoy vault", "What is a decoy vault?", "A second vault with its own PIN. If someone makes you unlock your iPhone, the decoy PIN opens a different vault with different items."),
        article("decoy-separate", "Decoy vault", "Is the decoy stored separately?", "Yes. It has its own PIN, keys and items. Nothing is copied from your real vault."),
        article("decoy-forgot", "Decoy vault", "What if I forget the decoy PIN?", "Its items cannot be recovered. The recovery key does not cover the decoy. Keep harmless items there."),
        article("decoy-limits", "Decoy vault", "Will it fool everyone?", "It helps in a casual check. It is not a guarantee against a determined person. We say this so you can decide."),
        article("recovery-key", "Forgot your PIN", "What is the recovery key?", "A code made on your iPhone when you set up. It opens your vaults if you forget your PIN. We cannot see it or reset your PIN for you. It does not recover deleted items, and it cannot restore files if this iPhone is replaced."),
        article("pin-length", "Forgot your PIN", "Why do I need at least 6 digits?", "Short PINs are easy to guess. You can choose more digits, or a longer passcode with letters, for more strength."),
        article("lost-key", "Forgot your PIN", "I lost both my PIN and my recovery key.", "We cannot open your vault for you. Your items stay locked. This is why we ask you to test and save the key during setup."),
        article("key-where", "Forgot your PIN", "Where should I keep my recovery key?", "Somewhere safe that is not Photos: a password manager, a printed copy or Files."),
        article("where-stored", "Your data and privacy", "Where are my items stored?", "On this iPhone, inside the app. Vault contents stay on this iPhone. CipherRoll does not upload your vault items. Your vault is protected by your lock and by iOS file protection."),
        article("encryption", "Your data and privacy", "How is my vault protected?", "Your vault is protected by your lock and by iOS file protection."),
        article("search", "Your data and privacy", "Does search send my data anywhere?", "No. Search runs on this iPhone."),
        article("new-iphone", "Your data and privacy", "What happens when I get a new iPhone?", "Vault items do not move by themselves. Settings, Export a backup, then Restore from backup on the new iPhone. The file is protected by the password you choose. A forgotten password cannot be reset."),
        article("delete-app", "Your data and privacy", "What if I delete the app?", "Your vault items are deleted with the app. Export a backup first if you want a copy. The file is protected by the password you choose."),
        article("replaced-iphone", "Your data and privacy", "What if this iPhone is replaced?", "Your vault stays on this iPhone. If the iPhone is replaced, the items stay on the old one, even if you still have the recovery key. Export a backup first. The file is protected by the password you choose."),
        article("ipad", "Your data and privacy", "Does CipherRoll work on iPad?", "Yes. One app works on iPhone, iPad and iPhone Duo. Each device keeps its own vault. Items do not sync between devices. Use Export all items to move a copy."),
        article("backup-what", "Your data and privacy", "How do I keep a copy of my vault?", "Settings, Export a backup. Choose a password of at least 10 characters. It is not your PIN. Keep the file and the password in different places. A forgotten password cannot be reset."),
        article("backup-forgot", "Your data and privacy", "I forgot my backup password.", "A forgotten backup password cannot be reset, and the file cannot be opened without it."),
        article("backup-restore", "Your data and privacy", "How do I restore a backup?", "Settings, Restore from backup. Choose the file and type the password. Items are added as a new vault. Nothing already here is overwritten. Set a PIN for that vault on this iPhone."),
        article("backup-pin", "Your data and privacy", "Is the backup password my PIN?", "No. The backup password is separate from your PIN. The restored vault uses a PIN you set on this iPhone."),
        article("app-icon", "Your data and privacy", "Can I change the CipherRoll icon?", "Yes. Settings, Privacy and lock, App icon. Choose CR lock, Calculator, Notes, Weather or Utility. iOS shows a short message when the icon changes. The name under the icon stays CipherRoll."),
        article("video-temp", "Your data and privacy", "Does CipherRoll leave copies when I play a video?", "To play a video, a protected temporary copy may be made on this iPhone. It is removed when you close the video and when the app starts. We cannot promise it is erased beyond recovery."),
        article("backup", "Your data and privacy", "Is there a backup?", "Settings, Export a backup makes a file protected by the password you choose. Security and storage still shows Not backed up, because the vault itself stays on this iPhone."),
        article("analytics", "Your data and privacy", "Do you collect usage data?", "If you allow it. On first launch we ask if CipherRoll may count anonymous app events to improve the app. You can change this in Settings, then Privacy and lock. We never send file names, photos, notes, PINs or search words."),
        article("ads", "Your data and privacy", "Are there ads?", "No."),
        article("free-plan", "Plans and payments", "What do I get for free?", "1 vault, up to 100 photos, 10 videos, 10 files and 10 notes. Saving from other apps with Share also works on Free."),
        article("pro", "Plans and payments", "What does Pro add?", "Unlimited vaults and items, the decoy vault, and future updates to these features. Weekly, yearly and lifetime plans are available."),
        article("trial", "Plans and payments", "How does the free trial work?", "If you are eligible, the yearly plan starts with 7 days free. We remind you before it ends. You can cancel any time in iPhone Settings, then your name, then Subscriptions. If you already used a trial, the screen shows the price with no trial."),
        article("renew", "Plans and payments", "Do plans renew automatically?", "Weekly ($1.99) and yearly ($19.99) plans renew automatically until you cancel. Lifetime ($39.99) is one payment with no renewal. Prices can differ by country."),
        article("cancel", "Plans and payments", "How do I cancel?", "iPhone Settings, your name, Subscriptions, CipherRoll, Cancel. Or tap Manage subscription in CipherRoll."),
        article("after-trial", "Plans and payments", "What happens when my trial or plan ends?", "Nothing was deleted. 1 vault stays free and editable. Other vaults become read-only. Items above the free limit stay visible and exportable. You cannot add more until you have room."),
        article("restore", "Plans and payments", "I paid before. How do I restore?", "Settings, Restore purchases. Use the same Apple ID. This also works on a new iPhone."),
        article("refund", "Plans and payments", "How do I get a refund?", "Apple handles refunds. Go to reportaproblem.apple.com."),
        article("lifetime", "Plans and payments", "What does Lifetime include?", "One payment, Pro on your Apple ID. Updates to the Pro features are included. Separate future products are not promised."),
        article("invite", "Invite and rewards", "How do invites work?", "Share your link. When a friend joins and the invite is confirmed, you each get 7 days of Pro. Up to 10 rewards a year. Rewards are confirmed before they start. This part can use a free sign-in."),
        article("share-ext", "Sharing into CipherRoll", "Can I save things from other apps?", "Yes, on the Free plan too. Tap Share in Photos, Files, Safari or other apps and choose CipherRoll. You unlock, pick a vault and save."),
        article("share-originals", "Sharing into CipherRoll", "Does sharing remove the original?", "No. The original stays in the source app. Saving here does not remove it."),
        article("import-failed", "Problems", "An import failed.", "Try fewer items at once and check iPhone storage. Your originals are untouched."),
        article("storage-full", "Problems", "Not enough storage.", "Vault items use iPhone storage. Free some space or export and remove items."),
        article("video-wont-play", "Problems", "A video will not play.", "Some formats are not supported by iOS. Export it and try another player."),
        article("contact", "Problems", "How do I contact support?", "Settings, Help, Contact us. Do not include your PIN or recovery key in any message.")
    ]

    static var sections: [String] {
        var seen: [String] = []
        for article in articles where !seen.contains(article.section) {
            seen.append(article.section)
        }
        return seen
    }

    static func matches(_ article: HelpArticle, query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        return article.question.localizedCaseInsensitiveContains(trimmed)
            || article.answer.localizedCaseInsensitiveContains(trimmed)
    }

    static func showing(_ article: HelpArticle, biometry: String) -> HelpArticle {
        var copy = article
        copy.question = article.question.replacingOccurrences(of: "{biometry}", with: biometry)
        copy.answer = article.answer.replacingOccurrences(of: "{biometry}", with: biometry)
        return copy
    }

    static var scanned: String {
        articles.map { $0.question + "\n" + $0.answer }.joined(separator: "\n")
    }

    private static func article(_ slug: String, _ section: String, _ question: String, _ answer: String) -> HelpArticle {
        HelpArticle(slug: slug, section: section, question: question, answer: answer)
    }
}
