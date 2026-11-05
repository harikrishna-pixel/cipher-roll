import CryptoKit
import XCTest
@testable import CipherRoll

final class Phase6RulesTests: XCTestCase {
    private var root: URL!
    private var service: VaultService!

    override func setUp() {
        super.setUp()
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        service = VaultService(
            root: root,
            keys: Phase6KeyStore(),
            sealer: Phase6Sealer(),
            passcode: Phase6Passcode(),
            derivation: PBKDF2KeyDerivation(),
            iterations: 1_000,
            clock: SystemClock(),
            originals: NoOriginalsDeleting()
        )
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: root)
        super.tearDown()
    }

    func testShareImportLeavesTheOriginalAndRoundTrips() throws {
        let marker = Data("SHARE-PLAINTEXT-MARKER".utf8)
        var body = Data(repeating: 0xAB, count: ChunkedItemFile.chunkBytes + 64)
        body.append(marker)
        let source = root.appendingPathComponent("clip.mov")
        try body.write(to: source)
        let created = try service.createVault(secret: .pin("135790"), role: .real)
        let session = try service.unlock(activeVault: created.id, secret: .pin("135790"))
        let id = try session.addItem(from: source, kind: .video, displayName: "clip.mov")
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
        XCTAssertTrue(ShareRules.leavesOriginal)
        let stored = try Data(contentsOf: try session.fileURL(for: id))
        XCTAssertNil(stored.range(of: marker))
        XCTAssertEqual(try session.readItem(id), body)
    }

    func testDecoyIsNotAShareTargetUntilThatVaultIsUnlocked() {
        let real = UUID()
        let decoy = UUID()
        let entries: [(id: UUID, role: VaultRole)] = [(real, .real), (decoy, .decoy)]
        let fromReal = ShareRules.targets(entries: entries, unlocked: .real)
        XCTAssertEqual(fromReal.map(\.id), [real])
        let fromDecoy = ShareRules.targets(entries: entries, unlocked: .decoy)
        XCTAssertEqual(fromDecoy.map(\.id), [decoy])
        XCTAssertFalse(ShareRules.namesADecoy(fromReal + fromDecoy))
        XCTAssertEqual(ShareRules.savedDetail(count: 3, kind: .photo), "3 photos are now saved in CipherRoll.")
        XCTAssertTrue(ShareRules.originalStays.contains("does not remove it"))
    }

    func testReferralStaysUngrantedWithoutAServer() {
        XCTAssertEqual(ReferralRules.rewardDays, 7)
        XCTAssertEqual(ReferralRules.maxPerYear, 10)
        XCTAssertFalse(ReferralRules.canReward(already: 10))
        let decision = ReferralRules.apply(server: UnavailableReferralServer().redeem(code: "PRB7"), already: 0)
        XCTAssertFalse(decision.granted)
        XCTAssertEqual(decision.days, 0)
        XCTAssertEqual(ReferralRules.code(stored: "PRB7"), "PRB7")
    }

    func testWelcomeAndReviewRules() {
        let now = Date()
        XCTAssertNil(WelcomeRules.variant(lastOpen: nil, now: now, alreadyShownDay: ""))
        XCTAssertEqual(
            WelcomeRules.variant(lastOpen: now.addingTimeInterval(-86_400), now: now, alreadyShownDay: ""),
            .daily
        )
        XCTAssertEqual(
            WelcomeRules.variant(lastOpen: now.addingTimeInterval(-9 * 86_400), now: now, alreadyShownDay: ""),
            .away
        )
        XCTAssertNil(WelcomeRules.variant(lastOpen: now.addingTimeInterval(-86_400), now: now, alreadyShownDay: WelcomeRules.dayKey(now)))
        XCTAssertFalse(ReviewPrompt.shouldRequest(moment: "import_done", alreadyRequested: false, session: 1))
        XCTAssertTrue(ReviewPrompt.shouldRequest(moment: "import_done", alreadyRequested: false, session: 2))
        XCTAssertFalse(ReviewPrompt.shouldRequest(moment: "import_done", alreadyRequested: true, session: 2))
        XCTAssertFalse(RecapRules.shouldShow(last: nil, now: now, itemCount: 4))
        XCTAssertTrue(RecapRules.shouldShow(last: now.addingTimeInterval(-8 * 86_400), now: now, itemCount: 4))
    }

    func testHelpSlugsAndCopy() {
        let slugs = Set(HelpCatalog.articles.map(\.slug))
        for required in ["share-ext", "share-originals", "backup", "calc-pin", "invite", "encryption", "what-is"] {
            XCTAssertTrue(slugs.contains(required), required)
        }
        XCTAssertTrue(HelpCatalog.articles.first { $0.slug == "backup" }?.answer.contains("protected by the password you choose") == true)
        XCTAssertTrue(HelpCatalog.articles.first { $0.slug == "calc-pin" }?.answer.contains("not a real calculator") == true)
        let text = (HelpCatalog.scanned + "\n" + ShareRules.scanned + "\n" + ReferralRules.unavailable).lowercased()
        for banned in ["encrypted", "military", "unhackable", "nobody can see", "monthly", "last chance", "expires", "locked out"] {
            XCTAssertFalse(text.contains(banned), banned)
        }
    }
}

private final class Phase6KeyStore: KeyStoring {
    private var values: [String: Data] = [:]
    func set(_ data: Data, service: String, account: String) throws { values["\(service)\n\(account)"] = data }
    func data(service: String, account: String) throws -> Data? { values["\(service)\n\(account)"] }
    func delete(service: String, account: String) throws { values.removeValue(forKey: "\(service)\n\(account)") }
}

private struct Phase6Passcode: PasscodeChecking {
    func deviceHasPasscode() -> Bool { true }
}

private struct Phase6Sealer: BundleSealing {
    private let key = SymmetricKey(size: .bits256)
    func seal(_ plaintext: Data) throws -> Data {
        try AESGCMBox.seal(plaintext, using: key, authenticating: Data("bundle-v1".utf8))
    }
    func open(_ sealed: Data) throws -> Data {
        try AESGCMBox.open(sealed, using: key, authenticating: Data("bundle-v1".utf8))
    }
}
