import XCTest
@testable import CorrectMe

final class ErrorLogTests: XCTestCase {
    override func setUp() {
        super.setUp()
        ErrorLog.shared.clearErrors()
        // Small delay to ensure clear completes
        Thread.sleep(forTimeInterval: 0.05)
    }

    func testLogAddsEntry() {
        ErrorLog.shared.log("Test error", category: .aiError)
        Thread.sleep(forTimeInterval: 0.05)
        let errors = ErrorLog.shared.getErrors()
        XCTAssertFalse(errors.isEmpty, "Log should have at least one entry")
        XCTAssertEqual(errors.first?.message, "Test error")
        XCTAssertEqual(errors.first?.category, .aiError)
    }

    func testLogKeepsNewestFirst() {
        ErrorLog.shared.log("First", category: .systemError)
        ErrorLog.shared.log("Second", category: .systemError)
        Thread.sleep(forTimeInterval: 0.05)
        let errors = ErrorLog.shared.getErrors()
        XCTAssertEqual(errors.first?.message, "Second", "Newest entry should be first")
    }

    func testClearRemovesAllEntries() {
        ErrorLog.shared.log("To be cleared", category: .userError)
        Thread.sleep(forTimeInterval: 0.05)
        ErrorLog.shared.clearErrors()
        Thread.sleep(forTimeInterval: 0.05)
        XCTAssertTrue(ErrorLog.shared.getErrors().isEmpty)
    }

    func testMaxEntriesEnforced() {
        for i in 0..<15 {
            ErrorLog.shared.log("Entry \(i)", category: .systemError)
        }
        Thread.sleep(forTimeInterval: 0.1)
        let errors = ErrorLog.shared.getErrors()
        XCTAssertLessThanOrEqual(errors.count, 10, "Should keep at most 10 errors")
    }

    func testThreadSafetyConcurrentWrites() {
        let expectation = XCTestExpectation(description: "Concurrent writes complete")
        expectation.expectedFulfillmentCount = 20

        for i in 0..<20 {
            DispatchQueue.global().async {
                ErrorLog.shared.log("Concurrent \(i)", category: .systemError)
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 5.0)
        // Give async dispatch a moment to settle
        Thread.sleep(forTimeInterval: 0.1)

        // Should not crash and count should be bounded
        let errors = ErrorLog.shared.getErrors()
        XCTAssertLessThanOrEqual(errors.count, 10)
    }

    func testTimeAgoFormatting() {
        ErrorLog.shared.log("timed entry", category: .networkError)
        Thread.sleep(forTimeInterval: 0.05)
        let entry = ErrorLog.shared.getErrors().first
        XCTAssertNotNil(entry)
        // Just created, so timeAgo should end in "s ago"
        XCTAssertTrue(entry!.timeAgo.hasSuffix("s ago"), "Recent entry should show seconds: \(entry!.timeAgo)")
    }
}
