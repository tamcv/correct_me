import XCTest
@testable import CorrectMe

final class AccessibilityHelperTests: XCTestCase {
    func testCheckAccessibilityPermissionsReturnsBool() {
        // In the test runner context, accessibility is not granted.
        // We only verify the function returns without crashing.
        let result = AccessibilityHelper.checkAccessibilityPermissions()
        XCTAssertFalse(result, "Test runner should not have accessibility permissions")
    }

    func testGetSelectedTextReturnsNilWhenNoUIFocused() {
        // In the unit-test process there is no focused UI element,
        // so both AX and Cmd+C fallback should return nil.
        let text = AccessibilityHelper.getSelectedText()
        XCTAssertNil(text, "No text should be selected in a headless test environment")
    }

    func testGetSelectedTextBoundsReturnsNilWhenNoUIFocused() {
        let bounds = AccessibilityHelper.getSelectedTextBounds()
        XCTAssertNil(bounds)
    }

    func testReplaceSelectedTextWithNilTargetReturnsTrueAndSetsClipboard() {
        let testString = "Hello, accessibility test!"
        let result = AccessibilityHelper.replaceSelectedText(
            with: testString,
            targetApp: nil,
            originalClipboard: nil
        )
        // Should return true when no target app is specified
        XCTAssertTrue(result)
        // The text should be in the clipboard immediately after the call
        let clipboardContent = NSPasteboard.general.string(forType: .string)
        XCTAssertEqual(clipboardContent, testString)
    }
}
