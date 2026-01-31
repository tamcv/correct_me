import XCTest
@testable import CorrectMe

final class HotkeyDisplayTests: XCTestCase {
    func testModifiersDisplayNameOrder() {
        var flags: CGEventFlags = []
        flags.insert(.maskCommand)
        flags.insert(.maskShift)
        flags.insert(.maskControl)
        flags.insert(.maskAlternate)
        XCTAssertEqual(CorrectMeApp.modifiersDisplayName(flags), "⌘⇧⌃⌥")
    }

    func testKeyNameForCodeKnown() {
        XCTAssertEqual(CorrectMeApp.keyNameForCode(14), "E")
        XCTAssertEqual(CorrectMeApp.keyNameForCode(8), "C")
        XCTAssertEqual(CorrectMeApp.keyNameForCode(18), "1")
    }
}
