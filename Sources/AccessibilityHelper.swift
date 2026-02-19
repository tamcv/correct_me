import AppKit
import ApplicationServices
import Carbon

class AccessibilityHelper {
    
    /// Get currently selected text - tries multiple methods
    static func getSelectedText() -> String? {
        // Method 1: Try Accessibility API first
        if let text = getSelectedTextViaAccessibility() {
            return text
        }
        
        // Method 2: Clipboard fallback (works for most apps)
        return getSelectedTextViaCopy()
    }
    
    /// Get selected text using Accessibility API
    private static func getSelectedTextViaAccessibility() -> String? {
        guard let focusedApp = NSWorkspace.shared.frontmostApplication else {
            return nil
        }
        
        let appElement = AXUIElementCreateApplication(focusedApp.processIdentifier)
        
        var focusedElement: CFTypeRef?
        let focusedResult = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )
        
        guard focusedResult == .success, focusedElement != nil else {
            return nil
        }
        
        var selectedText: CFTypeRef?
        let textResult = AXUIElementCopyAttributeValue(
            focusedElement as! AXUIElement,
            kAXSelectedTextAttribute as CFString,
            &selectedText
        )
        
        if textResult == .success, let text = selectedText as? String, !text.isEmpty {
            return text
        }
        
        return nil
    }
    
    /// Fallback: Get selected text by simulating Cmd+C
    private static func getSelectedTextViaCopy() -> String? {
        let pasteboard = NSPasteboard.general
        
        // Save current clipboard contents
        let oldChangeCount = pasteboard.changeCount
        let oldContents = pasteboard.string(forType: .string)
        
        // Clear clipboard
        pasteboard.clearContents()
        
        // Simulate Cmd+C using CGEvent
        let source = CGEventSource(stateID: .combinedSessionState)
        source?.localEventsSuppressionInterval = 0.0
        
        // Key down
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 8, keyDown: true) else {
            return nil
        }
        keyDown.flags = .maskCommand
        keyDown.post(tap: .cgAnnotatedSessionEventTap)
        
        // Key up
        guard let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 8, keyDown: false) else {
            return nil
        }
        keyUp.flags = .maskCommand
        keyUp.post(tap: .cgAnnotatedSessionEventTap)
        
        // Wait for clipboard to update - try multiple times
        var selectedText: String? = nil
        for _ in 0..<10 {
            Thread.sleep(forTimeInterval: 0.05)
            if pasteboard.changeCount != oldChangeCount {
                selectedText = pasteboard.string(forType: .string)
                break
            }
        }
        
        // If we got text, keep it. Otherwise restore old clipboard
        if selectedText == nil || selectedText?.isEmpty == true {
            if let old = oldContents {
                pasteboard.clearContents()
                pasteboard.setString(old, forType: .string)
            }
            return nil
        }
        
        return selectedText
    }
    
    /// Replace selected text by pasting from clipboard
    /// - Parameters:
    ///   - newText: The text to paste
    ///   - targetApp: Optional - the app to paste into (will activate if not frontmost)
    ///   - originalClipboard: Clipboard content to restore after paste (should be captured before
    ///     any Cmd+C fallback that may have replaced it). Defaults to whatever is in clipboard now.
    /// - Returns: true if paste was successful, false if user needs to paste manually
    @discardableResult
    static func replaceSelectedText(with newText: String, targetApp: NSRunningApplication? = nil, originalClipboard: String? = nil) -> Bool {
        let pasteboard = NSPasteboard.general
        let oldContents = pasteboard.string(forType: .string)
        // Use caller-supplied original if available (captures state before Cmd+C fallback),
        // otherwise fall back to whatever is currently in the clipboard.
        let contentToRestore = originalClipboard ?? oldContents
        
        // Set new text to clipboard
        pasteboard.clearContents()
        pasteboard.setString(newText, forType: .string)
        
        // If target app is specified and not frontmost, try to activate it
        if let target = targetApp {
            let currentApp = NSWorkspace.shared.frontmostApplication
            if currentApp?.processIdentifier != target.processIdentifier {
                // Try to activate target app
                let activated = target.activate(options: [])
                if !activated || target.isTerminated {
                    // App couldn't be activated (maybe closed) - leave text in clipboard
                    return false
                }
                // Wait for app to come to front
                Thread.sleep(forTimeInterval: 0.15)
            }
        }
        
        // Small delay to ensure clipboard is ready
        Thread.sleep(forTimeInterval: 0.05)
        
        // Simulate Cmd+V using CGEvent
        let source = CGEventSource(stateID: .combinedSessionState)
        source?.localEventsSuppressionInterval = 0.0
        
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true) else {
            return false
        }
        keyDown.flags = .maskCommand
        keyDown.post(tap: .cgAnnotatedSessionEventTap)
        
        guard let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false) else {
            return false
        }
        keyUp.flags = .maskCommand
        keyUp.post(tap: .cgAnnotatedSessionEventTap)
        
        // Wait for the paste to be processed by the target app, then restore the clipboard.
        // 1.0s gives slow apps enough time to complete the paste before we swap out the content.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if let content = contentToRestore {
                pasteboard.clearContents()
                pasteboard.setString(content, forType: .string)
            }
        }
        
        return true
    }
    
    /// Check if app has accessibility permissions
    static func checkAccessibilityPermissions() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
    
    /// Get the screen position of the selected text
    /// Returns the bounds (position and size) of the selected text, or nil if not available
    static func getSelectedTextBounds() -> NSRect? {
        guard let focusedApp = NSWorkspace.shared.frontmostApplication else {
            return nil
        }
        
        let appElement = AXUIElementCreateApplication(focusedApp.processIdentifier)
        
        var focusedElement: CFTypeRef?
        let focusedResult = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )
        
        guard focusedResult == .success, focusedElement != nil else {
            return nil
        }
        
        let element = focusedElement as! AXUIElement
        
        // Try to get selected text range first
        var selectedRangeValue: CFTypeRef?
        let rangeResult = AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            &selectedRangeValue
        )
        
        guard rangeResult == .success, selectedRangeValue != nil else {
            return nil
        }
        
        // Get bounds for the selected text range
        var boundsValue: CFTypeRef?
        let boundsResult = AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXBoundsForRangeParameterizedAttribute as CFString,
            selectedRangeValue!,
            &boundsValue
        )
        
        guard boundsResult == .success, boundsValue != nil else {
            return nil
        }
        
        // Convert AXValue to CGRect
        var bounds = CGRect.zero
        if AXValueGetValue(boundsValue as! AXValue, .cgRect, &bounds) {
            // Convert from screen coordinates (origin at top-left) to Cocoa coordinates (origin at bottom-left)
            if let screen = NSScreen.main {
                let screenHeight = screen.frame.height
                let convertedY = screenHeight - bounds.origin.y - bounds.height
                return NSRect(x: bounds.origin.x, y: convertedY, width: bounds.width, height: bounds.height)
            }
            return NSRect(origin: CGPoint(x: bounds.origin.x, y: bounds.origin.y), size: bounds.size)
        }
        
        return nil
    }
}
