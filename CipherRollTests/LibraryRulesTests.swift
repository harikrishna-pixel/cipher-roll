import XCTest
@testable import CipherRoll

final class LibraryRulesTests: XCTestCase {
    func testChipUsesTheLimitNearestToFull() {
        var counts = UsageCounts(photos: 43, videos: 8, files: 1, notes: 2)
        let nearest = FreePlanChip.nearest(counts)
        XCTAssertEqual(nearest.kind, .video)
        XCTAssertEqual(nearest.used, 8)
        XCTAssertEqual(nearest.limit, 10)
        XCTAssertEqual(FreePlanChip.title(kind: nearest.kind, used: nearest.used, limit: nearest.limit), "Free plan · 8 of 10 videos")

        counts = UsageCounts()
        XCTAssertEqual(FreePlanChip.nearest(counts).kind, .photo)
    }

    func testImportStopsAtTheFreeLimit() {
        XCTAssertEqual(ImportAllowance.importable(selected: 18, used: 85, limit: 100), 15)
        XCTAssertTrue(ImportAllowance.isOverLimit(selected: 18, used: 85, limit: 100))
        XCTAssertEqual(ImportAllowance.importable(selected: 3, used: 85, limit: 100), 3)
        XCTAssertFalse(ImportAllowance.isOverLimit(selected: 3, used: 85, limit: 100))
        XCTAssertEqual(ImportAllowance.remaining(used: 10, limit: 10), 0)
    }

    func testTrashKeepsAnItemForThirtyDays() {
        let deleted = Date(timeIntervalSince1970: 1_700_000_000)
        let soon = deleted.addingTimeInterval(60)
        XCTAssertEqual(TrashPolicy.daysRemaining(deletedAt: deleted, now: soon), 30)
        XCTAssertFalse(TrashPolicy.isExpired(deletedAt: deleted, now: soon))
        let later = deleted.addingTimeInterval(31 * 86_400)
        XCTAssertTrue(TrashPolicy.isExpired(deletedAt: deleted, now: later))
        XCTAssertEqual(TrashPolicy.daysRemaining(deletedAt: deleted, now: later), 0)
    }

    func testSearchStaysOnDisplayNameAndNoteText() {
        let photo = LibraryItem(id: UUID(), kind: .photo, displayName: "Passport photo.jpg", byteCount: 10, album: "Receipts", deletedAt: nil, createdAt: nil)
        let note = LibraryItem(id: UUID(), kind: .note, displayName: "Home and travel notes", byteCount: 4, album: nil, deletedAt: nil, createdAt: nil)
        let deleted = LibraryItem(id: UUID(), kind: .file, displayName: "Passport scan.pdf", byteCount: 4, album: nil, deletedAt: Date(), createdAt: nil)
        XCTAssertTrue(LibrarySearch.matches(item: photo, noteText: nil, query: "passport", kind: .photo))
        XCTAssertFalse(LibrarySearch.matches(item: photo, noteText: nil, query: "passport", kind: .file))
        XCTAssertTrue(LibrarySearch.matches(item: note, noteText: "Check passport expiry", query: "passport", kind: nil))
        XCTAssertFalse(LibrarySearch.matches(item: deleted, noteText: nil, query: "passport", kind: nil))
    }

    func testCountBucketDoesNotUseTheExactLargeNumber() {
        XCTAssertEqual(CountBucket.label(1), "1")
        XCTAssertEqual(CountBucket.label(40), "21+")
    }

    func testLowStorageRefusesAnotherFile() {
        XCTAssertFalse(StorageRoom.canFit(bytes: 50_000_000, available: 40_000_000))
        XCTAssertTrue(StorageRoom.canFit(bytes: 1_000, available: 80_000_000))
    }
}
