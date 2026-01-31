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
    static func replaceSelectedText(with newText: String) {
        let pasteboard = NSPasteboard.general
        let oldContents = pasteboard.string(forType: .string)
        
        // Set new text to clipboard
        pasteboard.clearContents()
        pasteboard.setString(newText, forType: .string)
        
        // Small delay to ensure clipboard is ready
        Thread.sleep(forTimeInterval: 0.05)
        
        // Simulate Cmd+V using CGEvent
        let source = CGEventSource(stateID: .combinedSessionState)
        source?.localEventsSuppressionInterval = 0.0
        
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true) else {
            return
        }
        keyDown.flags = .maskCommand
        keyDown.post(tap: .cgAnnotatedSessionEventTap)
        
        guard let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false) else {
            return
        }
        keyUp.flags = .maskCommand
        keyUp.post(tap: .cgAnnotatedSessionEventTap)
        
        // Wait then restore clipboard
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if let old = oldContents {
                pasteboard.clearContents()
                pasteboard.setString(old, forType: .string)
            }
        }
    }
    
    /// Check if app has accessibility permissions
    static func checkAccessibilityPermissions() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
}
