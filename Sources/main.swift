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
            
        case "version", "--version", "-v":
            print("CorrectMe \(AppVersion.current)")
            
        case "update":
            runUpdate()
            
        case "setup":
            setupWizard()
            
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
            correctme setup               Interactive setup (choose provider + keys)
            correctme config              Show current configuration
            correctme version             Show version
            correctme update              Update to the latest release
            correctme config provider <claude-code|codex-code|claude|gemini|codex>
            correctme config claude-key <API_KEY>
            correctme config gemini-key <API_KEY>
            correctme config openai-key <API_KEY>
            correctme config model <MODEL_NAME>
            correctme config hotkey       Show hotkey configuration instructions
            correctme test                Test AI correction with sample text
            correctme help                Show this help message
        
        SETUP:
            1. Grant Accessibility permissions:
               System Settings → Privacy & Security → Accessibility → Add Terminal/iTerm
            
            2. Configure AI provider:
               # Option A: Use Claude Code (if you have it installed)
               correctme config provider claude-code
               
               # Option B: Use Codex Code (if you have it installed)
               correctme config provider codex-code
               correctme config model gpt-5.1-codex-mini
               
               # Option C: Use Claude API
               correctme config provider claude
               correctme config claude-key sk-ant-xxxxx
               
               # Option D: Use Gemini API
               correctme config provider gemini
               correctme config gemini-key AIzaSyxxxxx

               # Option E: Use OpenAI API (Codex via API)
               correctme config provider codex
               correctme config openai-key sk-xxxxx
               correctme config model gpt-5.1-codex-mini
            
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
        OpenAI Key:   \(config.openaiAPIKey?.prefix(10).description ?? "not set")...
        Hotkey:       \(config.hotkey.displayName)
        Model:        \(config.model ?? "default (low-cost)")
        Config Path:  \(Config.configPath.path)
        
        """)
    }
    
    static func setupWizard() {
        print("Checking CLI availability...")
        let claudeStatus = checkClaudeCLI()
        let codexStatus = checkCodexCLI()
        
        print("""
        
        Setup - Choose AI provider:
        1) Claude Code (local CLI) \(cliStatusLabel(claudeStatus))
        2) Codex Code (local CLI) \(cliStatusLabel(codexStatus))
        3) OpenAI API (key required)
        4) Gemini (API key required)
        5) Claude API (API key required)
        6) Cancel
        
        """)
        
        guard let choice = readLine(), let option = Int(choice.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            print("Invalid selection.")
            return
        }
        
        switch option {
        case 1:
            if case .ready = claudeStatus {
                // ok
            } else {
                print("⚠️  Claude CLI not ready. Install Claude Code and ensure you can run it.")
                return
            }
            config.aiProvider = .claudeCode
            promptAndSetModel(defaultModel: Config.DefaultModels.anthropic)
            saveConfig()
            print("✓ Provider set to: claude-code")
            
        case 2:
            if case .ready = codexStatus {
                // ok
            } else {
                print("⚠️  Codex CLI not ready. Install Codex and ensure you can run it.")
                return
            }
            config.aiProvider = .codexCode
            promptAndSetModel(defaultModel: Config.DefaultModels.openaiCodex)
            saveConfig()
            print("✓ Provider set to: codex-code")
            
        case 3:
            config.aiProvider = .codex
            if !promptAndSetKey(label: "OpenAI API key", envVar: "OPENAI_API_KEY", setter: { config.openaiAPIKey = $0 }) {
                return
            }
            promptAndSetModelFromAPI(
                defaultModel: Config.DefaultModels.openaiCodex,
                fetcher: fetchOpenAIModels
            )
            saveConfig()
            print("✓ Provider set to: codex")
            
        case 4:
            config.aiProvider = .gemini
            if !promptAndSetKey(label: "Gemini API key", envVar: "GEMINI_API_KEY", setter: { config.geminiAPIKey = $0 }) {
                return
            }
            promptAndSetModelFromAPI(
                defaultModel: Config.DefaultModels.gemini,
                fetcher: fetchGeminiModels
            )
            saveConfig()
            print("✓ Provider set to: gemini")
            
        case 5:
            config.aiProvider = .claude
            if !promptAndSetKey(label: "Claude API key", envVar: "ANTHROPIC_API_KEY", setter: { config.anthropicAPIKey = $0 }) {
                return
            }
            promptAndSetModelFromAPI(
                defaultModel: Config.DefaultModels.anthropic,
                fetcher: fetchAnthropicModels
            )
            saveConfig()
            print("✓ Provider set to: claude")
            
        default:
            print("Setup canceled.")
        }
    }
    
    static func promptAndSetKey(label: String, envVar: String, setter: (String) -> Void) -> Bool {
        print("\(label) (press Enter to use \(envVar)): ", terminator: "")
        let input = readLine() ?? ""
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            setter(trimmed)
            return true
        }
        if let env = ProcessInfo.processInfo.environment[envVar], !env.isEmpty {
            setter(env)
            return true
        }
        print("Key is required. Set \(envVar) or paste the key.")
        return false
    }
    
    static func promptAndSetModel(defaultModel: String) {
        print("Model (press Enter for default low-cost: \(defaultModel)): ", terminator: "")
        let input = readLine() ?? ""
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        config.model = trimmed.isEmpty ? defaultModel : trimmed
    }

    static func promptAndSetModelFromAPI(defaultModel: String, fetcher: (String) -> [String]?) {
        let apiKey: String?
        switch config.aiProvider {
        case .claude:
            apiKey = config.anthropicAPIKey
        case .gemini:
            apiKey = config.geminiAPIKey
        case .codex:
            apiKey = config.openaiAPIKey
        default:
            apiKey = nil
        }

        guard let key = apiKey, let models = fetcher(key), !models.isEmpty else {
            print("⚠️  Could not fetch models. Enter a model name manually.")
            promptAndSetModel(defaultModel: defaultModel)
            return
        }

        let sorted = models.sorted()
        let defaultChoice = sorted.firstIndex(of: defaultModel).map { $0 + 1 } ?? 0

        print("\nAvailable models:")
        for (idx, name) in sorted.enumerated() {
            let marker = (name == defaultModel) ? " (default)" : ""
            print("\(idx + 1)) \(name)\(marker)")
        }
        print("\nChoose a model by number (or press Enter for default \(defaultModel)):", terminator: " ")

        let input = (readLine() ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if input.isEmpty {
            config.model = defaultModel
            return
        }
        if let index = Int(input), index >= 1, index <= sorted.count {
            config.model = sorted[index - 1]
            return
        }
        config.model = input
        if defaultChoice == 0 {
            print("Note: default model not found in API list. Using custom entry.")
        }
    }
    
    static func commandExists(_ name: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["which", name]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    private enum CLIStatus {
        case ready
        case notFound
        case failed(String)
    }

    private static func cliStatusLabel(_ status: CLIStatus) -> String {
        switch status {
        case .ready:
            return "[ready]"
        case .notFound:
            return "[not found]"
        case .failed:
            return "[not ready]"
        }
    }

    private static func checkClaudeCLI() -> CLIStatus {
        guard commandExists("claude") else { return .notFound }
        let prompt = "Respond with OK only."
        let result = runProcess(
            command: "/usr/bin/env",
            args: ["claude", "-p", prompt],
            stdin: nil
        )
        if result.exitCode == 0, !result.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .ready
        }
        return .failed(result.stderr)
    }

    private static func checkCodexCLI() -> CLIStatus {
        guard commandExists("codex") else { return .notFound }
        let tempDir = FileManager.default.temporaryDirectory
        let outputURL = tempDir.appendingPathComponent("correctme_codex_check_\(UUID().uuidString).txt")
        let prompt = "Respond with OK only."
        let result = runProcess(
            command: "/usr/bin/env",
            args: ["codex", "exec", "--output-last-message", outputURL.path, "-"],
            stdin: prompt
        )
        let fileData = (try? Data(contentsOf: outputURL)) ?? Data()
        let output = String(data: fileData, encoding: .utf8) ?? ""
        try? FileManager.default.removeItem(at: outputURL)
        if result.exitCode == 0, !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .ready
        }
        return .failed(result.stderr)
    }

    private static func runProcess(command: String, args: [String], stdin: String?) -> (exitCode: Int32, stdout: String, stderr: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = args

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        if let stdin {
            let inPipe = Pipe()
            process.standardInput = inPipe
            do {
                try process.run()
                if let data = stdin.data(using: .utf8) {
                    inPipe.fileHandleForWriting.write(data)
                }
                inPipe.fileHandleForWriting.closeFile()
            } catch {
                return (1, "", "\(error)")
            }
        } else {
            do {
                try process.run()
            } catch {
                return (1, "", "\(error)")
            }
        }

        process.waitUntilExit()

        let stdoutData = outPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = errPipe.fileHandleForReading.readDataToEndOfFile()
        let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""
        return (process.terminationStatus, stdout, stderr)
    }

    static func fetchOpenAIModels(apiKey: String) -> [String]? {
        let url = URL(string: "https://api.openai.com/v1/models")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let semaphore = DispatchSemaphore(value: 0)
        var result: [String]? = nil

        URLSession.shared.dataTask(with: request) { data, response, _ in
            defer { semaphore.signal() }
            guard let data, let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return
            }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let dataArray = json["data"] as? [[String: Any]] else {
                return
            }
            result = dataArray.compactMap { $0["id"] as? String }
        }.resume()

        semaphore.wait()
        return result
    }

    static func fetchAnthropicModels(apiKey: String) -> [String]? {
        let url = URL(string: "https://api.anthropic.com/v1/models")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let semaphore = DispatchSemaphore(value: 0)
        var result: [String]? = nil

        URLSession.shared.dataTask(with: request) { data, response, _ in
            defer { semaphore.signal() }
            guard let data, let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return
            }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let dataArray = json["data"] as? [[String: Any]] else {
                return
            }
            result = dataArray.compactMap { $0["id"] as? String }
        }.resume()

        semaphore.wait()
        return result
    }

    static func fetchGeminiModels(apiKey: String) -> [String]? {
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models?key=\(apiKey)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let semaphore = DispatchSemaphore(value: 0)
        var result: [String]? = nil

        URLSession.shared.dataTask(with: request) { data, response, _ in
            defer { semaphore.signal() }
            guard let data, let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return
            }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let modelsArray = json["models"] as? [[String: Any]] else {
                return
            }
            result = modelsArray.compactMap { model in
                if let name = model["name"] as? String {
                    return name.hasPrefix("models/") ? String(name.dropFirst("models/".count)) : name
                }
                return nil
            }
        }.resume()

        semaphore.wait()
        return result
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
                print("Usage: correctme config provider <claude-code|codex-code|claude|gemini|codex>")
                return
            }
            guard let provider = Config.AIProvider(rawValue: args[3]) else {
                print("Invalid provider. Use: claude-code, codex-code, claude, gemini, or codex")
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

        case "openai-key":
            guard args.count >= 4 else {
                print("Usage: correctme config openai-key <API_KEY>")
                return
            }
            config.openaiAPIKey = args[3]
            saveConfig()
            print("✓ OpenAI API key saved")

        case "model":
            guard args.count >= 4 else {
                print("Usage: correctme config model <MODEL_NAME>")
                return
            }
            config.model = args[3]
            saveConfig()
            print("✓ Model set to: \(args[3])")
            
        case "hotkey":
            configureHotkey()
            
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

    static func configureHotkey() {
        print("""
        
        Hotkey Configuration:
        ────────────────────
        Currently set to: \(config.hotkey.displayName)
        
        Choose a preset or press a custom hotkey:
        1) ⌘⇧E (default)
        2) ⌘⇧C
        3) ⌘⇧V
        4) ⌘⇧S
        5) ⌘⇧D
        6) Custom (press hotkey now)
        7) Cancel
        
        """)

        guard let choice = readLine(), let option = Int(choice.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            print("Invalid selection.")
            return
        }

        let presets: [HotkeyPreset] = [
            HotkeyPreset(keyCode: 14, modifiers: CGEventFlags.maskCommand.rawValue | CGEventFlags.maskShift.rawValue, displayName: "⌘⇧E"),
            HotkeyPreset(keyCode: 8, modifiers: CGEventFlags.maskCommand.rawValue | CGEventFlags.maskShift.rawValue, displayName: "⌘⇧C"),
            HotkeyPreset(keyCode: 9, modifiers: CGEventFlags.maskCommand.rawValue | CGEventFlags.maskShift.rawValue, displayName: "⌘⇧V"),
            HotkeyPreset(keyCode: 1, modifiers: CGEventFlags.maskCommand.rawValue | CGEventFlags.maskShift.rawValue, displayName: "⌘⇧S"),
            HotkeyPreset(keyCode: 2, modifiers: CGEventFlags.maskCommand.rawValue | CGEventFlags.maskShift.rawValue, displayName: "⌘⇧D")
        ]

        switch option {
        case 1...5:
            let preset = presets[option - 1]
            config.hotkey = Config.HotkeyConfig(
                keyCode: preset.keyCode,
                modifiers: preset.modifiers,
                displayName: preset.displayName
            )
            saveConfig()
            restartDaemonIfRunning()
            print("✓ Hotkey set to: \(preset.displayName)")

        case 6:
            if let captured = captureHotkey() {
                print("Detected: \(captured.displayName). Save? [Y/n] ", terminator: "")
                let input = (readLine() ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                if input.isEmpty || input.lowercased() == "y" {
                    config.hotkey = Config.HotkeyConfig(
                        keyCode: captured.keyCode,
                        modifiers: captured.modifiers,
                        displayName: captured.displayName
                    )
                    saveConfig()
                    restartDaemonIfRunning()
                    print("✓ Hotkey set to: \(captured.displayName)")
                } else {
                    print("Hotkey not changed.")
                }
            } else {
                print("Hotkey capture canceled.")
            }

        case 7:
            print("Canceled.")
        default:
            print("Invalid selection.")
        }
    }

    struct HotkeyPreset {
        let keyCode: UInt16
        let modifiers: UInt64
        let displayName: String
    }

    static func parseHotkey(_ input: String) -> HotkeyPreset? {
        if input.isEmpty { return nil }
        let tokens = input
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .split(separator: "+")
            .map { String($0) }

        if tokens.isEmpty { return nil }

        var modifiers: CGEventFlags = []
        var keyToken: String? = nil

        for token in tokens {
            switch token {
            case "cmd", "command", "⌘":
                modifiers.insert(.maskCommand)
            case "shift", "⇧":
                modifiers.insert(.maskShift)
            case "ctrl", "control", "⌃":
                modifiers.insert(.maskControl)
            case "opt", "option", "alt", "⌥":
                modifiers.insert(.maskAlternate)
            default:
                keyToken = token
            }
        }

        guard let key = keyToken, let keyCode = keyCodeForToken(key) else {
            return nil
        }

        let displayName = modifiersDisplayName(modifiers) + key.uppercased()
        return HotkeyPreset(keyCode: keyCode, modifiers: modifiers.rawValue, displayName: displayName)
    }

    static func keyCodeForToken(_ token: String) -> UInt16? {
        let map: [String: UInt16] = [
            "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5,
            "z": 6, "x": 7, "c": 8, "v": 9, "b": 11,
            "q": 12, "w": 13, "e": 14, "r": 15, "y": 16, "t": 17,
            "1": 18, "2": 19, "3": 20, "4": 21, "6": 22, "5": 23,
            "=": 24, "9": 25, "7": 26, "-": 27, "8": 28, "0": 29,
            "u": 32, "i": 34, "o": 31, "p": 35, "l": 37, "j": 38,
            "k": 40, "m": 46, "n": 45
        ]
        return map[token]
    }

    static func modifiersDisplayName(_ modifiers: CGEventFlags) -> String {
        var parts = ""
        if modifiers.contains(.maskCommand) { parts += "⌘" }
        if modifiers.contains(.maskShift) { parts += "⇧" }
        if modifiers.contains(.maskControl) { parts += "⌃" }
        if modifiers.contains(.maskAlternate) { parts += "⌥" }
        return parts
    }

    static func restartDaemonIfRunning() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", "if pgrep -f \"/usr/local/bin/correctme run\" >/dev/null 2>&1; then pkill -f \"/usr/local/bin/correctme run\" >/dev/null 2>&1 || true; nohup /usr/local/bin/correctme run >/tmp/correctme.log 2>/tmp/correctme.error.log & fi"]
        do {
            try process.run()
        } catch {
            // Best-effort restart; ignore failures.
        }
    }

    static func captureHotkey() -> HotkeyPreset? {
        print("Press your hotkey now (Esc to cancel)...")

        let context = HotkeyCaptureContext()
        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: hotkeyCaptureCallback,
            userInfo: Unmanaged.passUnretained(context).toOpaque()
        ) else {
            print("❌ Failed to capture hotkey (accessibility permission required).")
            return nil
        }

        context.runLoop = CFRunLoopGetCurrent()

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(context.runLoop, source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        CFRunLoopRun()

        CGEvent.tapEnable(tap: tap, enable: false)
        CFRunLoopRemoveSource(context.runLoop, source, .commonModes)

        return context.captured
    }

    private final class HotkeyCaptureContext {
        var runLoop: CFRunLoop?
        var captured: HotkeyPreset?
    }

    private static let hotkeyCaptureCallback: CGEventTapCallBack = { _, type, event, refcon in
        guard type == .keyDown else { return Unmanaged.passUnretained(event) }
        guard let refcon else { return Unmanaged.passUnretained(event) }
        let context = Unmanaged<HotkeyCaptureContext>.fromOpaque(refcon).takeUnretainedValue()
        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        // Esc to cancel
        if keyCode == 53 {
            if let loop = context.runLoop {
                CFRunLoopStop(loop)
            }
            return nil
        }

        let flags = event.flags
        let relevant: CGEventFlags = [
            .maskCommand,
            .maskShift,
            .maskControl,
            .maskAlternate
        ]
        let modifiers = flags.intersection(relevant)
        let displayName = modifiersDisplayName(modifiers) + keyNameForCode(keyCode)

        context.captured = HotkeyPreset(
            keyCode: keyCode,
            modifiers: modifiers.rawValue,
            displayName: displayName
        )
        if let loop = context.runLoop {
            CFRunLoopStop(loop)
        }
        return nil
    }

    static func keyNameForCode(_ keyCode: UInt16) -> String {
        let map: [UInt16: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G",
            6: "Z", 7: "X", 8: "C", 9: "V", 11: "B",
            12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T",
            18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5",
            24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            31: "O", 32: "U", 34: "I", 35: "P",
            37: "L", 38: "J", 40: "K", 45: "N", 46: "M"
        ]
        return map[keyCode] ?? "KeyCode\(keyCode)"
    }
    
    static func testCorrection() {
        print("\n🧪 Testing AI correction...\n")
        
        do {
            aiProvider = try createAIProvider(from: config)
        } catch {
            print("❌ \(error.localizedDescription)")
            print("Configure a provider first: correctme config provider <claude-code|codex-code|claude|gemini|codex>")
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

    static func runUpdate() {
        print("Checking for updates...")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = [
            "-c",
            "curl -fsSL https://raw.githubusercontent.com/tamcv/correct_me/main/scripts/install.sh | sh"
        ]
        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                restartDaemonIfRunning()
                print("✅ Update complete.")
            } else {
                print("❌ Update failed. Could not download installer or install release.")
            }
        } catch {
            print("❌ Update failed: \(error)")
        }
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
