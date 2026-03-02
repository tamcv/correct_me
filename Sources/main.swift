import AppKit
import ApplicationServices
import Foundation

// MARK: - Logging Helpers

/// Global verbose logging flag — set by `--verbose` CLI flag.
var isVerboseLogging = false

/// Print with automatic flush to ensure immediate log writing
func logPrint(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    let message = items.map { "\($0)" }.joined(separator: separator)
    print(message, terminator: terminator)
    fflush(stdout)
}

/// Write debug-only messages to stderr (only when --verbose is active).
func debugLog(_ items: Any..., separator: String = " ") {
    guard isVerboseLogging else { return }
    let message = items.map { "\($0)" }.joined(separator: separator)
    let stderr = FileHandle.standardError
    let line = "[DEBUG] \(message)\n"
    stderr.write(Data(line.utf8))
}

@main
struct CorrectMeApp {
    static var config = Config.load()
    static var hotkeyManager: HotkeyManager?
    static var aiProvider: AIProvider?
    static var hud: HUDWindow?
    static var diffPreview = DiffPreviewWindow.shared
    static var isProcessing = false
    /// Original text of the most recently accepted correction (for undo)
    static var lastOriginalText: String?
    /// The app that received the most recently accepted correction
    static var lastCorrectionSourceApp: NSRunningApplication?
    static var undoHotkeyManager: HotkeyManager?
    /// Timer that retries starting hotkey listeners when accessibility permissions are not yet available
    static var hotkeyRetryTimer: Timer?
    /// Number of times we've attempted to start the hotkey listener since last failure
    static var hotkeyRetryCount = 0
    
    static func main() {
        let args = CommandLine.arguments

        // Detect --verbose flag (may appear anywhere in args)
        if args.contains("--verbose") {
            isVerboseLogging = true
            debugLog("Verbose logging enabled")
        }

        // Handle internal daemon start flag
        if args.count > 1 && args[1] == "__daemon_start" {
            // This is the actual daemon process
            do {
                try DaemonManager.writePID(getpid())
            } catch {
                print("❌ Failed to write PID file: \(error)")
                exit(1)
            }
            DaemonManager.setupCleanupHandlers()
            runDaemon()
            exit(0)
        }

        if args.count > 1 {
            handleCommand(args)
            return
        }

        // No arguments — launched from Finder (double-click) or bare CLI invocation.
        // If launched via LaunchServices (Finder), start the daemon directly.
        // If launched from a terminal, show help as before.
        if ProcessInfo.processInfo.environment["__CFBundleIdentifier"] != nil
            || ProcessInfo.processInfo.environment["TERM"] == nil {
            // Launched from Finder / LaunchServices — start daemon
            if let existingPID = DaemonManager.getDaemonPID() {
                // Already running — just bring menu bar to front and exit
                debugLog("Daemon already running (PID: \(existingPID)), exiting duplicate launch")
                exit(0)
            }
            do {
                try DaemonManager.writePID(getpid())
            } catch {
                print("❌ Failed to write PID file: \(error)")
                exit(1)
            }
            DaemonManager.setupCleanupHandlers()
            runDaemon()
            exit(0)
        }

        // Launched from terminal with no args — show help
        printHelp()
        exit(0)
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

        case "start":
            if !DaemonManager.isLaunchAgentInstalled {
                // Create and load the LaunchAgent plist first
                print("🔧 Auto-start is not enabled. Enabling it now...")
                enableAutoStart()
                print("")
                // enableAutoStart loaded the plist; daemon is starting via RunAtLoad
                usleep(500_000)
                if let pid = DaemonManager.readPID() {
                    print("✓ Daemon started (PID: \(pid))")
                }
                exit(0)
            } else {
                // Plist already installed - use launchctl to start
                DaemonManager.startViaLaunchAgent()
            }

        case "stop":
            if DaemonManager.isLaunchAgentInstalled {
                DaemonManager.stopViaLaunchAgent()
            } else {
                _ = DaemonManager.stopDaemon()
            }
            exit(0)

        case "status":
            DaemonManager.checkStatus()
            exit(0)

        case "restart":
            if DaemonManager.isLaunchAgentInstalled {
                DaemonManager.restartViaLaunchAgent()
            } else {
                if DaemonManager.getDaemonPID() != nil {
                    _ = DaemonManager.stopDaemon()
                    sleep(1)
                }
                DaemonManager.startDaemon(background: true)
            }

        case "run":
            // Legacy command - run in foreground
            print("Note: 'correctme run' is deprecated. Use 'correctme start' instead.")
            if args.contains("--verbose") { isVerboseLogging = true }
            DaemonManager.startDaemon(background: false)

        case "enable":
            enableAutoStart()
            exit(0)

        case "disable":
            disableAutoStart()
            exit(0)

        case "uninstall":
            uninstallCorrectMe()

        case "doctor":
            runDoctor()
            exit(0)

        default:
            print("Unknown command: \(command)")
            print("Use 'correctme help' for usage information.")
            exit(1)
        }
    }
    
    static func runDoctor() {
        print("""

        CorrectMe Doctor — Checking dependencies
        ─────────────────────────────────────────
        """)

        var allGood = true

        // ── 1. Config file
        let cfgExists = FileManager.default.fileExists(atPath: Config.configPath.path)
        printCheck(cfgExists, "Config file found at \(Config.configPath.path)")
        if !cfgExists {
            print("    → Run 'correctme setup' to create a configuration")
            allGood = false
        }

        // ── 2. AI provider / API key
        let cfg = config
        let provider = cfg.aiProvider

        switch provider {
        case .claudeCode:
            let found = findExecutable("claude") != nil
            printCheck(found, "Claude CLI (claude) found in PATH")
            if !found {
                print("    → Install Claude Code: https://claude.ai/code")
                allGood = false
            }
        case .codexCode:
            let found = findExecutable("codex") != nil
            printCheck(found, "Codex CLI (codex) found in PATH")
            if !found {
                print("    → Install Codex and ensure it is in your PATH")
                allGood = false
            }
        case .copilot:
            let ghFound = findExecutable("gh") != nil
            printCheck(ghFound, "GitHub CLI (gh) found in PATH")
            if !ghFound {
                print("    → Install with: brew install gh")
                print("    → Then: gh extension install github/gh-copilot")
                allGood = false
            }
        case .claude:
            let hasKey = !(cfg.anthropicAPIKey ?? "").isEmpty
            printCheck(hasKey, "Anthropic API key configured")
            if !hasKey {
                print("    → Run: correctme config claude-key <YOUR_KEY>")
                allGood = false
            }
        case .gemini:
            let hasKey = !(cfg.geminiAPIKey ?? "").isEmpty
            printCheck(hasKey, "Gemini API key configured")
            if !hasKey {
                print("    → Run: correctme config gemini-key <YOUR_KEY>")
                allGood = false
            }
        case .codex:
            let hasKey = !(cfg.openaiAPIKey ?? "").isEmpty
            printCheck(hasKey, "OpenAI API key configured")
            if !hasKey {
                print("    → Run: correctme config openai-key <YOUR_KEY>")
                allGood = false
            }
        }

        // ── 3. Hotkey
        let hotkey = cfg.hotkey.displayName
        printCheck(true, "Hotkey configured: \(hotkey)")

        // ── 4. Accessibility permissions
        let options: [String: Any] = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        let hasAccessibility = AXIsProcessTrustedWithOptions(options as CFDictionary)
        printCheck(hasAccessibility, "Accessibility permissions granted")
        if !hasAccessibility {
            print("    → System Settings → Privacy & Security → Accessibility")
            print("    → Add and enable your terminal app")
            allGood = false
        }

        // ── 5. Daemon status
        let daemonRunning = DaemonManager.getDaemonPID() != nil
        printCheck(daemonRunning, "Daemon is running")
        if !daemonRunning {
            print("    → Start with: correctme start")
        }

        print("")
        if allGood {
            print("✅ All checks passed — CorrectMe is ready!")
        } else {
            print("⚠️  Some checks failed. Fix the issues above and try again.")
        }
        print("")
    }

    private static func printCheck(_ ok: Bool, _ message: String) {
        print("  \(ok ? "✓" : "✗") \(message)")
    }

    static func printHelp() {
        print("""

        CorrectMe - AI-powered text correction for macOS

        USAGE:
            correctme start               Start daemon (auto-enables at login)
            correctme stop                Stop the daemon
            correctme restart             Restart the daemon
            correctme status              Check daemon status
            correctme enable              Enable auto-start at login
            correctme disable             Disable auto-start at login
            correctme setup               Interactive setup (choose provider + keys)
            correctme config              Show current configuration
            correctme test                Test AI correction with sample text
            correctme version             Show version
            correctme update              Update to the latest release
            correctme doctor              Check dependencies and configuration
            correctme uninstall           Uninstall CorrectMe
            correctme help                Show this help message

        DAEMON MANAGEMENT:
            start                         Start daemon (runs in background, auto-enables at login)
            stop                          Stop the running daemon
            restart                       Restart the daemon
            status                        Show daemon status and uptime
            enable                        Enable auto-start at login (via LaunchAgent)
            disable                       Disable auto-start at login

        CONFIGURATION:
            config                        Show current configuration
            config provider <name>        Set AI provider
                                          (claude-code|codex-code|claude|gemini|codex)
            config claude-key <key>       Set Claude API key
            config gemini-key <key>       Set Gemini API key
            config openai-key <key>       Set OpenAI API key
            config model <name>           Set model name
            config hotkey                 Configure hotkey

        SETUP GUIDE:
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

            3. Start the daemon:
               correctme start

            4. Select text anywhere and press ⌘⇧E to correct it!

        DEFAULT HOTKEY: ⌘⇧E (Cmd + Shift + E)

        FILES:
            Config:       ~/.correctme/config.json
            PID:          ~/.correctme/correctme.pid
            LaunchAgent:  ~/Library/LaunchAgents/com.correctme.daemon.plist
            Logs:         /tmp/correctme.log
                          /tmp/correctme.error.log

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
        let copilotStatus = checkCopilotCLI()
        
        // Show current configuration
        let currentProvider = config.aiProvider.rawValue
        let currentModel = config.model ?? "default"
        print("""
        
        Current configuration:
          Provider: \(currentProvider)
          Model: \(currentModel)
        
        Setup - Choose AI provider:
        1) Claude Code (local CLI) \(cliStatusLabel(claudeStatus))
        2) Codex Code (local CLI) \(cliStatusLabel(codexStatus))
        3) GitHub Copilot (local CLI) \(cliStatusLabel(copilotStatus))
        4) OpenAI API (key required)
        5) Gemini (API key required)
        6) Claude API (API key required)
        7) Cancel
        
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
            promptAndSetModel(defaultModel: Config.DefaultModels.claudeCode)
            saveConfig()
            print("✓ Provider set to: claude-code")
            promptRestartDaemon()
            
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
            promptRestartDaemon()
            
        case 3:
            if case .ready = copilotStatus {
                // ok
            } else {
                print("⚠️  GitHub Copilot CLI not ready. Install with: gh extension install github/gh-copilot")
                return
            }
            config.aiProvider = .copilot
            promptAndSetModel(defaultModel: Config.DefaultModels.copilot)
            saveConfig()
            print("✓ Provider set to: copilot")
            promptRestartDaemon()
            
        case 4:
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
            promptRestartDaemon()
            
        case 5:
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
            promptRestartDaemon()
            
        case 6:
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
            promptRestartDaemon()
            
        default:
            print("Setup canceled.")
        }
    }
    
    static func promptRestartDaemon() {
        // Check if daemon is currently running
        let isRunning = DaemonManager.getDaemonPID() != nil

        if !isRunning {
            print("\n💡 Daemon is not running. Start it with: correctme start")
            return
        }

        print("\n🔄 Restart CorrectMe daemon to apply changes? [Y/n]: ", terminator: "")
        let input = (readLine() ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // Default is yes (empty input or 'y')
        if input.isEmpty || input == "y" || input == "yes" {
            print("Restarting daemon...")
            if DaemonManager.isLaunchAgentInstalled {
                DaemonManager.runLaunchctl(["stop", "com.correctme.daemon"])
                sleep(1)
                DaemonManager.runLaunchctl(["start", "com.correctme.daemon"])
                print("✓ Daemon restarted")
            } else {
                _ = DaemonManager.stopDaemon()
                sleep(1)
                DaemonManager.startDaemon(background: true)
            }
        } else {
            print("Skipped restart. Run 'correctme restart' manually when ready.")
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
        return .ready
    }

    private static func checkCodexCLI() -> CLIStatus {
        guard commandExists("codex") else { return .notFound }
        return .ready
    }

    private static func checkCopilotCLI() -> CLIStatus {
        guard commandExists("gh") else { return .notFound }
        return .ready
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
        guard DaemonManager.getDaemonPID() != nil else { return }

        if DaemonManager.isLaunchAgentInstalled {
            DaemonManager.runLaunchctl(["stop", "com.correctme.daemon"])
            sleep(1)
            DaemonManager.runLaunchctl(["start", "com.correctme.daemon"])
        } else {
            _ = DaemonManager.stopDaemon()
            sleep(1)
            // Spawn __daemon_start directly (same as startInBackground)
            guard let execPath = ProcessInfo.processInfo.arguments.first else { return }
            let process = Process()
            process.executableURL = URL(fileURLWithPath: execPath)
            process.arguments = ["__daemon_start"]
            let logPath = DaemonManager.logFilePath
            let errPath = DaemonManager.errorLogFilePath
            if !FileManager.default.fileExists(atPath: logPath.path) {
                FileManager.default.createFile(atPath: logPath.path, contents: nil)
            }
            if !FileManager.default.fileExists(atPath: errPath.path) {
                FileManager.default.createFile(atPath: errPath.path, contents: nil)
            }
            if let out = FileHandle(forWritingAtPath: logPath.path) {
                out.seekToEndOfFile()
                process.standardOutput = out
            }
            if let err = FileHandle(forWritingAtPath: errPath.path) {
                err.seekToEndOfFile()
                process.standardError = err
            }
            try? process.run()
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

        // Show onboarding wizard on first launch (no config file present)
        if !FileManager.default.fileExists(atPath: Config.configPath.path) {
            debugLog("No config file found — launching onboarding wizard")
            // Temporarily show as regular app so the window is visible
            app.setActivationPolicy(.regular)
            OnboardingWindowController.shared.show { [self] in
                // Reload config after onboarding saves it
                config = Config.load()
                // Switch back to accessory (menu bar only)
                app.setActivationPolicy(.accessory)
                startDaemonServices()
            }
            app.run()
            return
        }

        startDaemonServices()
        app.run()
    }

    static func startDaemonServices() {
        logPrint("""

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
            logPrint("⚠️  Accessibility permission required!")
            logPrint("   Go to: System Settings → Privacy & Security → Accessibility")
            logPrint("   Add and enable Terminal (or your terminal app)")
            logPrint("")
        }

        // Initialize menu bar manager first (before checking permissions)
        _ = MenuBarManager.shared

        // Set initial status
        StatusManager.shared.setStatus(.idle)

        // Initialize AI provider
        do {
            aiProvider = try createAIProvider(from: config)
        } catch {
            logPrint("❌ \(error.localizedDescription)")
            logPrint("Configure a provider first: correctme config provider <provider>")
            ErrorLog.shared.log("AI provider not configured: \(error.localizedDescription)", category: .userError)
            // Don't exit - let menu bar work even without provider
        }

        // Set up HUD window
        hud = HUDWindow()

        // Set up correction hotkey
        hotkeyManager = HotkeyManager(config: config) {
            handleHotkey()
        }

        // Set up undo hotkey (⌘⌥Z — Cmd+Option+Z)
        let undoKeyCode: UInt16 = 6 // Z
        let undoModifiers = CGEventFlags.maskCommand.rawValue | CGEventFlags.maskAlternate.rawValue
        let undoConfig = Config(
            aiProvider: config.aiProvider,
            anthropicAPIKey: nil, geminiAPIKey: nil, openaiAPIKey: nil,
            hotkey: Config.HotkeyConfig(keyCode: undoKeyCode, modifiers: undoModifiers, displayName: "⌘⌥Z"),
            customPrompt: nil, model: nil, writingStyle: nil
        )
        undoHotkeyManager = HotkeyManager(config: undoConfig) {
            handleUndoHotkey()
        }

        startHotkeyListeners()

        logPrint("─────────────────────────\n")
    }

    /// Attempt to start both hotkey listeners. If accessibility permissions are not yet
    /// available (common on boot when LaunchAgent starts before TCC is ready), schedules
    /// a silent retry every 5 seconds. Only logs to ErrorLog after 6 failed attempts (~30s).
    static func startHotkeyListeners() {
        let mainStarted = hotkeyManager?.start() == true
        let undoStarted = undoHotkeyManager?.start() == true

        if mainStarted {
            logPrint("✓ Hotkey listener started")
            hotkeyRetryTimer?.invalidate()
            hotkeyRetryTimer = nil
            hotkeyRetryCount = 0
        }
        if undoStarted {
            logPrint("✓ Undo hotkey listener started (⌘⌥Z)")
        }

        if !mainStarted {
            logPrint("⚠️  Hotkey listener not ready — waiting for accessibility permissions...")
            scheduleHotkeyRetry()
        }
    }

    static func scheduleHotkeyRetry() {
        guard hotkeyRetryTimer == nil else { return }
        hotkeyRetryTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            let options: [String: Any] = [
                kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false
            ]
            guard AXIsProcessTrustedWithOptions(options as CFDictionary) else {
                hotkeyRetryCount += 1
                // Log to ErrorLog only after 6 silent retries (~30s) to avoid false alarms at boot
                if hotkeyRetryCount == 6 {
                    ErrorLog.shared.log(
                        "Failed to create event tap - accessibility permissions may be missing",
                        category: .systemError
                    )
                    ErrorLog.shared.log(
                        "Failed to start hotkey listener - accessibility permissions may be missing",
                        category: .systemError
                    )
                    logPrint("❌ Failed to start hotkey listener — grant accessibility permissions in")
                    logPrint("   System Settings → Privacy & Security → Accessibility")
                }
                return
            }
            // Permissions now available — attempt to start
            let mainOK = hotkeyManager?.start() == true
            let undoOK = undoHotkeyManager?.start() == true
            if mainOK {
                logPrint("✓ Hotkey listener started (accessibility permissions now available)")
                hotkeyRetryTimer?.invalidate()
                hotkeyRetryTimer = nil
                hotkeyRetryCount = 0
            }
            if undoOK { logPrint("✓ Undo hotkey listener started (⌘⌥Z)") }
        }
    }

    static func runUpdate() {
        print("Checking for updates...")
        let installerURLs = [
            "https://raw.githubusercontent.com/tamcv/correct_me/main/scripts/install.sh",
            "https://raw.githubusercontent.com/tamcv/correct_me/master/scripts/install.sh",
            "https://raw.githubusercontent.com/tamcv/correct_me/HEAD/scripts/install.sh"
        ]
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = [
            "-c",
            "set -e; " +
            "for url in " + installerURLs.map { "\"\($0)\"" }.joined(separator: " ") + "; do " +
            "echo \"Trying: $url\"; " +
            "if curl -fsSL \"$url\" | sh; then exit 0; fi; " +
            "done; exit 1"
        ]
        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                // Verify code signature of the installed app
                verifyInstalledSignature()
                restartDaemonIfRunning()
                print("✅ Update complete.")
            } else {
                print("❌ Update failed. Could not download installer or install release.")
            }
        } catch {
            print("❌ Update failed: \(error)")
        }
    }

    /// Verify that the installed .app has a valid code signature.
    static func verifyInstalledSignature() {
        let appPath = "/Applications/CorrectMe.app"
        guard FileManager.default.fileExists(atPath: appPath) else { return }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        process.arguments = ["--verify", "--deep", "--strict", appPath]
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                print("✅ Code signature verified")
            } else {
                print("⚠️  App is not code-signed (development build)")
            }
        } catch {
            debugLog("Signature verification failed: \(error)")
        }
    }
    
    /// Handle the undo hotkey (⌘⌥Z): restore the last correction's original text.
    /// Places the original text in the clipboard and shows a HUD so the user can ⌘V to paste.
    static func handleUndoHotkey() {
        guard let original = lastOriginalText else {
            logPrint("↩ Nothing to undo")
            hud?.showError()
            return
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(original, forType: .string)

        // Try to activate the source app and paste
        if let app = lastCorrectionSourceApp, !app.isTerminated {
            app.activate(options: [])
            Thread.sleep(forTimeInterval: 0.1)
            let source = CGEventSource(stateID: .combinedSessionState)
            source?.localEventsSuppressionInterval = 0.0
            if let down = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true) {
                down.flags = .maskCommand
                down.post(tap: .cgAnnotatedSessionEventTap)
            }
            if let up = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false) {
                up.flags = .maskCommand
                up.post(tap: .cgAnnotatedSessionEventTap)
            }
            logPrint("↩ Undone — original text pasted back")
        } else {
            logPrint("↩ Original text copied to clipboard — press ⌘V to paste")
        }

        hud?.showSuccess()
        // Clear after use so a double-undo does nothing
        lastOriginalText = nil
        lastCorrectionSourceApp = nil
    }

    static func handleHotkey() {
        guard !isProcessing else {
            logPrint("⏳ Already processing...")
            return
        }

        isProcessing = true
        debugLog("handleHotkey() triggered")

        // Remember the source app so we can paste back to it even if user switches apps
        let sourceApp = NSWorkspace.shared.frontmostApplication
        debugLog("Source app: \(sourceApp?.localizedName ?? "nil")")

        // Set bundle ID for per-app writing style resolution
        currentCorrectionBundleId = sourceApp?.bundleIdentifier

        // Show HUD immediately near mouse cursor — no AX call here so the main thread
        // stays free and the ⏳ icon updates right away.
        hud?.showLoading()

        // Brief delay to let the hotkey event fully clear before we simulate Cmd+C.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            // Snapshot clipboard BEFORE getSelectedText(), which may overwrite it
            // via the Cmd+C fallback.
            let clipboardBeforeCorrection = NSPasteboard.general.string(forType: .string)

            // Move text capture to a background thread so the main thread stays
            // responsive. getSelectedText() may call Thread.sleep() in its clipboard
            // fallback path, which would otherwise freeze the HUD animation and
            // prevent the menu-bar icon from updating.
            Task.detached {
                guard let selectedText = AccessibilityHelper.getSelectedText(), !selectedText.isEmpty else {
                    let errorMsg = "No text selected"
                    logPrint("⚠️  \(errorMsg)")
                    ErrorLog.shared.log(errorMsg, category: .userError)
                    await MainActor.run {
                        isProcessing = false
                        hud?.showError()
                    }
                    return
                }

                let preview = selectedText.prefix(50)
                logPrint("📝 Correcting: \"\(preview)\(selectedText.count > 50 ? "..." : "")\"")

                guard let provider = aiProvider else {
                    let errorMsg = "No AI provider configured"
                    logPrint("❌ \(errorMsg)")
                    ErrorLog.shared.log(errorMsg, category: .userError)
                    await MainActor.run {
                        isProcessing = false
                        hud?.showError()
                    }
                    return
                }

                do {
                    let correctedText = try await provider.correctText(selectedText)

                    await MainActor.run {
                        hud?.hide()

                        let applyCorrection = {
                            CorrectionHistory.shared.record(
                                original: selectedText,
                                corrected: correctedText
                            )
                            lastOriginalText = selectedText
                            lastCorrectionSourceApp = sourceApp
                            let pasteSuccess = AccessibilityHelper.replaceSelectedText(
                                with: correctedText,
                                targetApp: sourceApp,
                                originalClipboard: clipboardBeforeCorrection
                            )
                            if pasteSuccess {
                                logPrint("✅ Corrected!")
                                hud?.showSuccess()
                            } else {
                                logPrint("⚠️ Source app unavailable - corrected text copied to clipboard")
                                ErrorLog.shared.log("Text copied to clipboard (source app unavailable)", category: .userError)
                                hud?.showSuccess()
                            }
                            isProcessing = false
                        }

                        if Config.load().forceApply ?? false {
                            applyCorrection()
                            return
                        }

                        diffPreview.onAccept = applyCorrection

                        diffPreview.onReject = {
                            logPrint("↩ Correction discarded by user")
                            if let original = clipboardBeforeCorrection {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(original, forType: .string)
                            } else {
                                NSPasteboard.general.clearContents()
                            }
                            isProcessing = false
                        }

                        diffPreview.show(original: selectedText, corrected: correctedText)
                    }
                } catch {
                    await MainActor.run {
                        let errorMsg = error.localizedDescription
                        logPrint("❌ Error: \(errorMsg)")
                        ErrorLog.shared.log(errorMsg, category: .aiError)
                        isProcessing = false
                        hud?.showError()
                    }
                }
            }
        }
    }

    static func enableAutoStart() {
        let launchAgentsDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents")
        let targetPlist = launchAgentsDir.appendingPathComponent("com.correctme.daemon.plist")

        // Check if already enabled
        if FileManager.default.fileExists(atPath: targetPlist.path) {
            print("✓ Auto-start is already enabled")
            print("  LaunchAgent: \(targetPlist.path)")
            return
        }

        // Create LaunchAgents directory if needed
        if !FileManager.default.fileExists(atPath: launchAgentsDir.path) {
            do {
                try FileManager.default.createDirectory(at: launchAgentsDir, withIntermediateDirectories: true)
            } catch {
                print("❌ Failed to create LaunchAgents directory: \(error)")
                exit(1)
            }
        }

        // Create plist content
        // Use __daemon_start directly so launchd manages the process lifecycle.
        // This avoids the KeepAlive restart loop caused by the two-process model.
        let logDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".correctme")
        let plistContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>com.correctme.daemon</string>

            <key>ProgramArguments</key>
            <array>
                <string>/Applications/CorrectMe.app/Contents/MacOS/correctme</string>
                <string>__daemon_start</string>
            </array>

            <key>RunAtLoad</key>
            <true/>

            <key>KeepAlive</key>
            <dict>
                <key>SuccessfulExit</key>
                <false/>
            </dict>

            <key>StandardOutPath</key>
            <string>\(logDir.path)/correctme.log</string>

            <key>StandardErrorPath</key>
            <string>\(logDir.path)/correctme.error.log</string>
        </dict>
        </plist>
        """

        // Write plist file
        do {
            try plistContent.write(to: targetPlist, atomically: true, encoding: .utf8)
        } catch {
            print("❌ Failed to write LaunchAgent plist: \(error)")
            exit(1)
        }

        // Load the LaunchAgent
        let loadProcess = Process()
        loadProcess.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        loadProcess.arguments = ["load", targetPlist.path]

        do {
            try loadProcess.run()
            loadProcess.waitUntilExit()

            if loadProcess.terminationStatus == 0 {
                print("✅ Auto-start enabled!")
                print("  CorrectMe will now start automatically at login")
                print("  LaunchAgent: \(targetPlist.path)")
            } else {
                print("⚠️  LaunchAgent created but failed to load")
                print("  You may need to load it manually:")
                print("  launchctl load \(targetPlist.path)")
            }
        } catch {
            print("❌ Failed to load LaunchAgent: \(error)")
            print("  Plist created at: \(targetPlist.path)")
            print("  Load it manually with: launchctl load \(targetPlist.path)")
        }
    }

    static func disableAutoStart() {
        let launchAgentsDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents")
        let targetPlist = launchAgentsDir.appendingPathComponent("com.correctme.daemon.plist")

        // Check if LaunchAgent exists
        if !FileManager.default.fileExists(atPath: targetPlist.path) {
            print("✓ Auto-start is already disabled")
            return
        }

        // Unload the LaunchAgent
        let unloadProcess = Process()
        unloadProcess.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        unloadProcess.arguments = ["unload", targetPlist.path]

        do {
            try unloadProcess.run()
            unloadProcess.waitUntilExit()
        } catch {
            print("⚠️  Warning: Failed to unload LaunchAgent: \(error)")
        }

        // Remove the plist file
        do {
            try FileManager.default.removeItem(at: targetPlist)
            print("✅ Auto-start disabled!")
            print("  LaunchAgent removed from: \(targetPlist.path)")
        } catch {
            print("❌ Failed to remove LaunchAgent: \(error)")
            exit(1)
        }
    }

    static func uninstallCorrectMe() {
        print("""

        ╔══════════════════════════════════════════╗
        ║       Uninstall CorrectMe                ║
        ╚══════════════════════════════════════════╝

        This will remove:
          • App: /Applications/CorrectMe.app
          • CLI symlink: /usr/local/bin/correctme
          • Config: ~/.correctme/
          • Auto-start from ~/.zshrc
          • LaunchAgent (if installed)

        """)

        print("Are you sure you want to uninstall? [y/N] ", terminator: "")
        guard let response = readLine()?.lowercased(),
              response == "y" || response == "yes" else {
            print("Uninstall cancelled.")
            exit(0)
        }

        print("")
        var removedItems: [String] = []

        // 1. Stop daemon if running
        if DaemonManager.getDaemonPID() != nil {
            print("🛑 Stopping daemon...")
            _ = DaemonManager.stopDaemon()
            removedItems.append("Stopped daemon")
        }

        // 2. Remove LaunchAgent if present
        let launchAgentPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/com.correctme.daemon.plist")

        if FileManager.default.fileExists(atPath: launchAgentPath.path) {
            print("🗑  Removing LaunchAgent...")

            // Unload first
            let unloadProcess = Process()
            unloadProcess.executableURL = URL(fileURLWithPath: "/bin/launchctl")
            unloadProcess.arguments = ["unload", launchAgentPath.path]
            try? unloadProcess.run()
            unloadProcess.waitUntilExit()

            // Remove file
            try? FileManager.default.removeItem(at: launchAgentPath)
            removedItems.append("Removed LaunchAgent")
        }

        // 3. Remove auto-start from .zshrc
        let zshrcPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".zshrc")

        if FileManager.default.fileExists(atPath: zshrcPath.path) {
            do {
                let content = try String(contentsOf: zshrcPath, encoding: .utf8)
                let lines = content.components(separatedBy: .newlines)
                let filtered = lines.filter { line in
                    !line.contains("correctme-autostart.sh") &&
                    !line.contains("# CorrectMe auto-start")
                }

                if filtered.count != lines.count {
                    print("🗑  Removing auto-start from ~/.zshrc...")
                    try filtered.joined(separator: "\n").write(to: zshrcPath, atomically: true, encoding: .utf8)
                    removedItems.append("Removed auto-start from ~/.zshrc")
                }
            } catch {
                print("⚠️  Warning: Could not update ~/.zshrc")
            }
        }

        // 4. Remove config directory
        let configDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".correctme")

        if FileManager.default.fileExists(atPath: configDir.path) {
            print("🗑  Removing config directory...")
            try? FileManager.default.removeItem(at: configDir)
            removedItems.append("Removed ~/.correctme/")
        }

        // 5. Remove .app from Applications
        let appPath = "/Applications/CorrectMe.app"
        if FileManager.default.fileExists(atPath: appPath) {
            print("🗑  Removing CorrectMe.app...")
            try? FileManager.default.removeItem(atPath: appPath)
            removedItems.append("Removed /Applications/CorrectMe.app")
        }

        // 6. Remove CLI symlink (this will fail if not run with proper permissions)
        let binaryPath = "/usr/local/bin/correctme"
        if FileManager.default.fileExists(atPath: binaryPath) {
            print("""

            ⚠️  To remove the CLI symlink, run:
                sudo rm /usr/local/bin/correctme

            Or use the uninstall script:
                curl -fsSL https://raw.githubusercontent.com/tamcv/correct_me/main/scripts/uninstall.sh | sh

            """)
        }

        // Summary
        print("")
        print("✅ Uninstall complete!")
        print("")
        if !removedItems.isEmpty {
            print("Removed:")
            for item in removedItems {
                print("  ✓ \(item)")
            }
        }
        print("")
        print("👋 Thanks for using CorrectMe!")
        print("")
    }
}
