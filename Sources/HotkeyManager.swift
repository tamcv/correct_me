import AppKit
import Carbon

/// Registers a global hotkey using Carbon's RegisterEventHotKey API.
/// This requires NO accessibility / TCC permissions — unlike CGEvent.tapCreate.
class HotkeyManager {
    private var hotKeyRef: EventHotKeyRef?
    private let config: Config
    private let onTrigger: () -> Void
    private let hotKeyID: UInt32

    // Shared Carbon event handler installed once for all HotkeyManager instances.
    private static var eventHandlerRef: EventHandlerRef?
    // Maps hot-key ID → trigger callback.
    private static var registry: [UInt32: () -> Void] = [:]
    private static var nextID: UInt32 = 1

    init(config: Config, onTrigger: @escaping () -> Void) {
        self.config = config
        self.onTrigger = onTrigger
        hotKeyID = HotkeyManager.nextID
        HotkeyManager.nextID += 1
    }

    deinit { stop() }

    func start() -> Bool {
        HotkeyManager.installSharedHandlerIfNeeded()

        var id = EventHotKeyID()
        id.signature = 0x434D544B  // 'CMTK' — arbitrary 4-char app tag
        id.id = hotKeyID

        let err = RegisterEventHotKey(
            UInt32(config.hotkey.keyCode),
            HotkeyManager.toCarbonModifiers(config.hotkey.modifiers),
            id,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        guard err == noErr else {
            ErrorLog.shared.log(
                "Failed to register hotkey (Carbon err \(err))",
                category: .systemError
            )
            return false
        }

        HotkeyManager.registry[hotKeyID] = onTrigger
        return true
    }

    func stop() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        HotkeyManager.registry.removeValue(forKey: hotKeyID)
    }

    // MARK: - Private helpers

    private static func toCarbonModifiers(_ cgFlags: UInt64) -> UInt32 {
        var mods: UInt32 = 0
        if (cgFlags & CGEventFlags.maskCommand.rawValue)  != 0 { mods |= UInt32(cmdKey) }
        if (cgFlags & CGEventFlags.maskShift.rawValue)    != 0 { mods |= UInt32(shiftKey) }
        if (cgFlags & CGEventFlags.maskControl.rawValue)  != 0 { mods |= UInt32(controlKey) }
        if (cgFlags & CGEventFlags.maskAlternate.rawValue) != 0 { mods |= UInt32(optionKey) }
        return mods
    }

    /// Install a single Carbon event handler shared by all instances.
    /// @convention(c) closures may only reference static/global state — no captures.
    private static func installSharedHandlerIfNeeded() {
        guard eventHandlerRef == nil else { return }

        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind:  UInt32(kEventHotKeyPressed)
        )

        let handler: EventHandlerUPP = { _, event, _ -> OSStatus in
            guard let event else { return OSStatus(eventNotHandledErr) }
            var hkID = EventHotKeyID()
            GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hkID
            )
            if let callback = HotkeyManager.registry[hkID.id] {
                DispatchQueue.main.async { callback() }
                return noErr
            }
            return OSStatus(eventNotHandledErr)
        }

        InstallEventHandler(
            GetApplicationEventTarget(),
            handler,
            1,
            &spec,
            nil,
            &eventHandlerRef
        )
    }
}

// MARK: - Key code helpers
extension UInt16 {
    static let keyCodeE: UInt16 = 14
    static let keyCodeC: UInt16 = 8
    static let keyCodeV: UInt16 = 9
}
