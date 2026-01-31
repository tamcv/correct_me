import XCTest
@testable import CorrectMe

final class HotkeyParsingTests: XCTestCase {
    func testParseHotkeyCmdShiftE() {
        let result = CorrectMeApp.parseHotkey("cmd+shift+e")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.keyCode, 14)
        XCTAssertEqual(result?.displayName, "⌘⇧E")
    }

    func testParseHotkeyCtrlOpt1() {
        let result = CorrectMeApp.parseHotkey("ctrl+opt+1")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.keyCode, 18)
        XCTAssertEqual(result?.displayName, "⌃⌥1")
    }

    func testParseHotkeyIgnoresWhitespaceAndCase() {
        let result = CorrectMeApp.parseHotkey("  Cmd + SHIFT + v ")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.keyCode, 9)
        XCTAssertEqual(result?.displayName, "⌘⇧V")
    }

    func testParseHotkeyInvalidReturnsNil() {
        XCTAssertNil(CorrectMeApp.parseHotkey(""))
        XCTAssertNil(CorrectMeApp.parseHotkey("cmd+shift"))
        XCTAssertNil(CorrectMeApp.parseHotkey("unknown+key"))
    }
}
