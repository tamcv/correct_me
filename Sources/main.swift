import AppKit
import Foundation

@main
struct CorrectMeApp {
    static var config = Config.load()
    static var hotkeyManager: HotkeyManager?
    static var aiProvider: AIProvider?
    static var statusBar: StatusBarController?
    static var isProcessing = false
    
    static func main() {
        let args = CommandLine.arguments
        
        if args.count > 1 {
            handleCommand(args)
            return
        }
        
        // Run as daemon
        runDaemon()
    }
    
    static func handleCommand(_ args: [String]) {
        let command = args[1]
        
        switch command {
        case "help", "--help", "-h":
            printHelp()
            
        case "config":
            if args.count > 2 {
                configureOption(args)
            } else {
                showConfig()
            }
            
        case "test":
            testCorrection()
            
        case "run", "start":
            runDaemon()
            
        default:
            print("Unknown command: \(command)")
            print("Use 'correctme help' for usage information.")
            exit(1)
        }
    }
    
    static func printHelp() {
        print("""
        
        CorrectMe - AI-powered text correction for macOS
        
        USAGE:
            correctme                     Run as background daemon
            correctme run                 Run as background daemon
            correctme config              Show current configuration
            correctme config provider <claude-code|claude|gemini>
            correctme config claude-key <API_KEY>
            correctme config gemini-key <API_KEY>
            correctme config hotkey       Show hotkey configuration instructions
            correctme test                Test AI correction with sample text
            correctme help                Show this help message
        
        SETUP:
            1. Grant Accessibility permissions:
               System Settings → Privacy & Security → Accessibility → Add Terminal/iTerm
            
            2. Configure AI provider:
               # Option A: Use Claude Code (if you have it installed)
               correctme config provider claude-code
               
               # Option B: Use Claude API
               correctme config provider claude
               correctme config claude-key sk-ant-xxxxx
               
               # Option C: Use Gemini API
               correctme config provider gemini
               correctme config gemini-key AIzaSyxxxxx
            
            3. Run the daemon:
               correctme run
            
            4. Select text anywhere and press ⌘⇧E to correct it!
        
        DEFAULT HOTKEY: ⌘⇧E (Cmd + Shift + E)
        
        CONFIG FILE: ~/.correctme/config.json
        
        """)
    }
    
    static func showConfig() {
        print("""
        
        Current Configuration:
        ─────────────────────
        Provider:     \(config.aiProvider.rawValue)
        Claude Key:   \(config.anthropicAPIKey?.prefix(10).description ?? "not set")...
        Gemini Key:   \(config.geminiAPIKey?.prefix(10).description ?? "not set")...
        Hotkey:       \(config.hotkey.displayName)
        Config Path:  \(Config.configPath.path)
        
        """)
    }
    
    static func configureOption(_ args: [String]) {
        guard args.count >= 3 else {
            print("Usage: correctme config <option> <value>")
            return
        }
        
        let option = args[2]
        
        switch option {
        case "provider":
            guard args.count >= 4 else {
                print("Usage: correctme config provider <claude-code|claude|gemini>")
                return
            }
            guard let provider = Config.AIProvider(rawValue: args[3]) else {
                print("Invalid provider. Use: claude-code, claude, or gemini")
                return
            }
            config.aiProvider = provider
            saveConfig()
            print("✓ Provider set to: \(provider.rawValue)")
            
        case "claude-key":
            guard args.count >= 4 else {
                print("Usage: correctme config claude-key <API_KEY>")
                return
            }
            config.anthropicAPIKey = args[3]
            saveConfig()
            print("✓ Claude API key saved")
            
        case "gemini-key":
            guard args.count >= 4 else {
                print("Usage: correctme config gemini-key <API_KEY>")
                return
            }
            config.geminiAPIKey = args[3]
            saveConfig()
            print("✓ Gemini API key saved")
            
        case "hotkey":
            print("""
            
            Hotkey Configuration:
            ────────────────────
            Currently set to: \(config.hotkey.displayName)
            
            To change the hotkey, edit ~/.correctme/config.json manually:
            
            {
              "hotkey": {
                "keyCode": 14,      // 14 = E key (see key codes below)
                "modifiers": 1310720, // Command + Shift
                "displayName": "⌘⇧E"
              }
            }
            
            Common Key Codes:
            - E: 14, C: 8, V: 9, S: 1, D: 2
            - 1-0: 18-29
            
            Modifier Values (add together):
            - Command: 1048576
            - Shift: 131072
            - Control: 262144
            - Option: 524288
            
            Example: Command + Shift = 1048576 + 131072 = 1179648
            
            """)
            
        default:
            print("Unknown option: \(option)")
        }
    }
    
    static func saveConfig() {
        do {
            try config.save()
        } catch {
            print("❌ Failed to save config: \(error)")
        }
    }
    
    static func testCorrection() {
        print("\n🧪 Testing AI correction...\n")
        
        do {
            aiProvider = try createAIProvider(from: config)
        } catch {
            print("❌ \(error.localizedDescription)")
            print("Configure a provider first: correctme config provider <claude-code|claude|gemini>")
            return
        }
        
        let testText = "Ths is a testt sentense with speling erors and grammer mistake."
        print("Original:  \(testText)")
        
        let semaphore = DispatchSemaphore(value: 0)
        
        Task {
            do {
                let result = try await aiProvider!.correctText(testText)
                print("Corrected: \(result)")
                print("\n✅ AI provider is working correctly!\n")
            } catch {
                print("❌ Error: \(error.localizedDescription)\n")
            }
            semaphore.signal()
        }
        
        semaphore.wait()
    }
    
    static func runDaemon() {
        // Ensure AppKit is initialized for status bar UI.
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        app.finishLaunching()

        print("""
        
        ╔═══════════════════════════════════════════╗
        ║         CorrectMe is running!             ║
        ╠═══════════════════════════════════════════╣
        ║  Hotkey: \(config.hotkey.displayName.padding(toLength: 32, withPad: " ", startingAt: 0)) ║
        ║  Provider: \(config.aiProvider.rawValue.padding(toLength: 30, withPad: " ", startingAt: 0)) ║
        ╚═══════════════════════════════════════════╝
        
        Select any text and press \(config.hotkey.displayName) to correct it.
        Press Ctrl+C to quit.
        
        """)
        
        // Check accessibility permissions
        if !AccessibilityHelper.checkAccessibilityPermissions() {
            print("⚠️  Accessibility permission required!")
            print("   Go to: System Settings → Privacy & Security → Accessibility")
            print("   Add and enable Terminal (or your terminal app)")
            print("")
        }
        
        // Initialize AI provider
        do {
            aiProvider = try createAIProvider(from: config)
        } catch {
            print("❌ \(error.localizedDescription)")
            print("Configure a provider first: correctme config provider <provider>")
            exit(1)
        }
        
        // Set up hotkey
        hotkeyManager = HotkeyManager(config: config) {
            handleHotkey()
        }
        
        guard hotkeyManager?.start() == true else {
            print("❌ Failed to start hotkey listener.")
            print("   Make sure accessibility permissions are granted.")
            exit(1)
        }
        
        print("✓ Hotkey listener started")
        print("─────────────────────────\n")

        // Set up menubar status
        statusBar = StatusBarController()
        statusBar?.setIdle()
        
        // Handle Ctrl+C
        signal(SIGINT) { _ in
            print("\n\n👋 CorrectMe stopped.\n")
            exit(0)
        }
        
        // Run the event loop
        RunLoop.current.run()
    }
    
    static func handleHotkey() {
        guard !isProcessing else {
            print("⏳ Already processing...")
            return
        }
        
        isProcessing = true
        statusBar?.setBusy()
        
        // Longer delay to let the hotkey event fully complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            guard let selectedText = AccessibilityHelper.getSelectedText(), !selectedText.isEmpty else {
                print("⚠️  No text selected")
                isProcessing = false
                statusBar?.setIdle()
                return
            }
            
            let preview = selectedText.prefix(50)
            print("📝 Correcting: \"\(preview)\(selectedText.count > 50 ? "..." : "")\"")
            
            Task {
                do {
                    let correctedText = try await aiProvider!.correctText(selectedText)
                    
                    await MainActor.run {
                        AccessibilityHelper.replaceSelectedText(with: correctedText)
                        print("✅ Corrected!")
                        isProcessing = false
                        statusBar?.setIdle()
                    }
                } catch {
                    await MainActor.run {
                        print("❌ Error: \(error.localizedDescription)")
                        isProcessing = false
                        statusBar?.setError()
                    }
                }
            }
        }
    }
}
