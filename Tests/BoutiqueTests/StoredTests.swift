@testable import Boutique
import Combine
import XCTest

extension Store where Item == BoutiqueItem {
    static let boutiqueItemsStore = Store<BoutiqueItem>(
        storage: SQLiteStorageEngine.default(appendingPath: "StoredTests")
    )
}

final class StoredTests: XCTestCase {
    @Stored(in: .boutiqueItemsStore) private var items

    private var cancellables: Set<AnyCancellable> = []

    override func setUp() async throws {
        try await $items.removeAll()
    }

    override func tearDown() {
        cancellables.removeAll()
    }

    func testInsertingItem() async throws {
        try await $items.insert(.coat)
        XCTAssertTrue(items.contains(.coat))

        try await $items.insert(.belt)
        XCTAssertTrue(items.contains(.belt))
        XCTAssertEqual(items.count, 2)
    }

    func testInsertingItems() async throws {
        try await $items.insert([.coat, .sweater, .sweater, .purse])
        XCTAssertTrue(items.contains(.coat))
        XCTAssertTrue(items.contains(.sweater))
        XCTAssertTrue(items.contains(.purse))
    }

    func testInsertingDuplicateItems() async throws {
        XCTAssertTrue(items.isEmpty)
        try await $items.insert(.allItems)
        XCTAssertEqual(items.count, 4)
    }

    func testReadingItems() async throws {
        try await $items.insert(.allItems)

        XCTAssertEqual(items[0], .coat)
        XCTAssertEqual(items[1], .sweater)
        XCTAssertEqual(items[2], .purse)
        XCTAssertEqual(items[3], .belt)

        XCTAssertEqual(items.count, 4)
    }

    func testReadingPersistedItems() async throws {
        try await $items.insert(.allItems)

        // The new store has to fetch items from disk.
        let newStore = try await Store<BoutiqueItem>(
            storage: SQLiteStorageEngine.default(appendingPath: "StoredTests"),
            cacheIdentifier: \.merchantID
        )

        XCTAssertEqual(newStore.items.count, 4)

        XCTAssertEqual(newStore.items[0], .coat)
        XCTAssertEqual(newStore.items[1], .sweater)
        XCTAssertEqual(newStore.items[2], .purse)
        XCTAssertEqual(newStore.items[3], .belt)
    }

    func testRemovingItems() async throws {
        try await $items.insert(.allItems)
        try await $items.remove(.coat)

        XCTAssertFalse(items.contains(.coat))

        XCTAssertTrue(items.contains(.sweater))
        XCTAssertTrue(items.contains(.purse))

        try await $items.remove([.sweater, .purse])
        XCTAssertFalse(items.contains(.sweater))
        XCTAssertFalse(items.contains(.purse))
    }

    func testRemoveAll() async throws {
        try await $items.insert(.coat)
        XCTAssertEqual(items.count, 1)
        try await $items.removeAll()

        try await $items.insert(.uniqueItems)
        XCTAssertEqual(items.count, 4)
        try await $items.removeAll()
        XCTAssertTrue(items.isEmpty)
    }

    func testChainingInsertOperations() async throws {
        try await $items.insert(.uniqueItems)

        try await $items
            .remove(.coat)
            .insert(.belt)
            .insert(.belt)
            .run()

        XCTAssertEqual(items.count, 3)
        XCTAssertTrue(items.contains(.sweater))
        XCTAssertTrue(items.contains(.purse))
        XCTAssertTrue(items.contains(.belt))
        XCTAssertFalse(items.contains(.coat))

        try await $items.removeAll()

        try await $items
            .insert(.belt)
            .insert(.coat)
            .remove([.belt])
            .insert(.sweater)
            .run()

        XCTAssertEqual(items.count, 2)
        XCTAssertTrue(items.contains(.coat))
        XCTAssertTrue(items.contains(.sweater))
        XCTAssertFalse(items.contains(.belt))

        try await $items.removeAll()

        try await $items
            .insert(.belt)
            .insert(.coat)
            .insert(.purse)
            .remove([.belt, .coat])
            .insert([.sweater])
            .run()

        XCTAssertEqual(items.count, 2)
        XCTAssertTrue(items.contains(.sweater))
        XCTAssertTrue(items.contains(.purse))
        XCTAssertFalse(items.contains(.coat))
        XCTAssertFalse(items.contains(.belt))

        try await $items.removeAll()

        try await $items
            .insert(.belt)
            .insert(.coat)
            .insert(.purse)
            .remove(.belt)
            .remove(.coat)
            .insert(.sweater)
            .run()

        XCTAssertEqual(items.count, 2)
        XCTAssertTrue(items.contains(.sweater))
        XCTAssertTrue(items.contains(.purse))
        XCTAssertFalse(items.contains(.coat))
        XCTAssertFalse(items.contains(.belt))

        try await $items.removeAll()

        try await $items
            .insert(.coat)
            .insert([.purse, .belt])
            .run()

        XCTAssertEqual(items.count, 3)
        XCTAssertTrue(items.contains(.purse))
        XCTAssertTrue(items.contains(.belt))
        XCTAssertTrue(items.contains(.coat))

        try await $items.removeAll()

        try await $items
            .insert(.coat)
            .insert([.purse, .belt])
            .remove(.purse)
            .run()

        XCTAssertEqual(items.count, 2)
        XCTAssertFalse(items.contains(.purse))
        XCTAssertTrue(items.contains(.belt))
        XCTAssertTrue(items.contains(.coat))

        try await $items.removeAll()

        try await $items
            .insert([.coat])
            .remove(.coat)
            .insert([.purse, .belt])
            .remove(.purse)
            .run()

        XCTAssertEqual(items.count, 1)
        XCTAssertFalse(items.contains(.purse))
        XCTAssertTrue(items.contains(.belt))
        XCTAssertFalse(items.contains(.coat))

        try await $items.removeAll()

        try await $items
            .insert([.coat])
            .remove(.coat)
            .insert([.purse, .belt])
            .removeAll()
            .run()

        XCTAssertEqual(items.count, 0)
        XCTAssertFalse(items.contains(.purse))
        XCTAssertFalse(items.contains(.belt))
        XCTAssertFalse(items.contains(.coat))

        try await $items
            .insert([.coat])
            .removeAll()
            .insert([.purse, .belt])
            .run()

        XCTAssertEqual(items.count, 2)
        XCTAssertTrue(items.contains(.purse))
        XCTAssertTrue(items.contains(.belt))
        XCTAssertFalse(items.contains(.coat))
    }

    func testChainingRemoveOperations() async throws {
        try await $items
            .insert(.uniqueItems)
            .remove(.belt)
            .remove(.purse)
            .run()

        XCTAssertEqual(items.count, 2)
        XCTAssertTrue(items.contains(.sweater))
        XCTAssertTrue(items.contains(.coat))

        try await $items.insert(.uniqueItems)
        XCTAssertEqual(items.count, 4)

        try await $items
            .remove([.sweater, .coat])
            .remove(.belt)
            .run()

        XCTAssertEqual(items.count, 1)
        XCTAssertTrue(items.contains(.purse))

        try await $items
            .removeAll()
            .insert(.belt)
            .run()

        XCTAssertEqual(items.count, 1)
        XCTAssertTrue(items.contains(.belt))

        try await $items
            .removeAll()
            .remove(.belt)
            .insert(.belt)
            .run()

        XCTAssertEqual(items.count, 1)
        XCTAssertTrue(items.contains(.belt))
    }

    func testChainingOperationsDontExecuteUnlessRun() async throws {
        let operation = try await $items
            .insert(.coat)
            .insert([.purse, .belt])

        XCTAssertEqual(items.count, 0)
        XCTAssertFalse(items.contains(.purse))
        XCTAssertFalse(items.contains(.belt))
        XCTAssertFalse(items.contains(.coat))

        // Adding this line to get rid of the error about
        // `operation` being unused, given that's the point of the test.
        _ = operation
    }

    func testObservableSubscriptionInsertingItems() async throws {
        let uniqueItems = [BoutiqueItem].uniqueItems
        let expectation = XCTestExpectation(description: "uniqueItems is published and read")

        withObservationTracking({
            _ = self.items
        }, onChange: {
            Task { @MainActor in
                XCTAssertEqual(self.items, uniqueItems)
                expectation.fulfill()
            }
        })

        XCTAssertTrue(items.isEmpty)

        // Sets items under the hood
        try await $items.insert(uniqueItems)
        await fulfillment(of: [expectation], timeout: 1.0)
    }
}
