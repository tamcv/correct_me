import AppKit
import Carbon

class HotkeyManager {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let config: Config
    private let onTrigger: () -> Void
    
    init(config: Config, onTrigger: @escaping () -> Void) {
        self.config = config
        self.onTrigger = onTrigger
    }
    
    func start() -> Bool {
        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue)
        
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { proxy, type, event, refcon in
                let manager = Unmanaged<HotkeyManager>.fromOpaque(refcon!).takeUnretainedValue()
                return manager.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            print("❌ Failed to create event tap. Make sure accessibility permissions are granted.")
            return false
        }
        
        self.eventTap = tap
        self.runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        
        return true
    }
    
    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }
    
    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        guard type == .keyDown else {
            return Unmanaged.passUnretained(event)
        }
        
        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags
        
        // Check if hotkey matches
        let targetKeyCode = config.hotkey.keyCode
        let targetModifiers = config.hotkey.modifiers
        
        let hasCommand = flags.contains(.maskCommand)
        let hasShift = flags.contains(.maskShift)
        let hasControl = flags.contains(.maskControl)
        let hasOption = flags.contains(.maskAlternate)
        
        let targetHasCommand = (targetModifiers & CGEventFlags.maskCommand.rawValue) != 0
        let targetHasShift = (targetModifiers & CGEventFlags.maskShift.rawValue) != 0
        let targetHasControl = (targetModifiers & CGEventFlags.maskControl.rawValue) != 0
        let targetHasOption = (targetModifiers & CGEventFlags.maskAlternate.rawValue) != 0
        
        if keyCode == targetKeyCode &&
           hasCommand == targetHasCommand &&
           hasShift == targetHasShift &&
           hasControl == targetHasControl &&
           hasOption == targetHasOption {
            
            // Trigger correction on main thread
            DispatchQueue.main.async {
                self.onTrigger()
            }
            
            // Consume the event
            return nil
        }
        
        return Unmanaged.passUnretained(event)
    }
}

// MARK: - Key code helpers
extension UInt16 {
    static let keyCodeE: UInt16 = 14
    static let keyCodeC: UInt16 = 8
    static let keyCodeV: UInt16 = 9
}
