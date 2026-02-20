import Foundation

enum DaemonManager {
    static var pidFilePath: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".correctme/correctme.pid")
    }

    static var logFilePath: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".correctme/correctme.log")
    }

    static var errorLogFilePath: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".correctme/correctme.error.log")
    }

    static var launchAgentPlistPath: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent("Library/LaunchAgents/com.correctme.daemon.plist")
    }

    static var isLaunchAgentInstalled: Bool {
        FileManager.default.fileExists(atPath: launchAgentPlistPath.path)
    }

    @discardableResult
    static func runLaunchctl(_ args: [String]) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = args
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        try? process.run()
        process.waitUntilExit()
        return process.terminationStatus
    }

    // MARK: - PID Management

    static func writePID(_ pid: Int32) throws {
        let dir = pidFilePath.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        // Write PID with timestamp for additional validation
        let timestamp = Int(Date().timeIntervalSince1970)
        let content = "\(pid)\n\(timestamp)"
        try content.write(to: pidFilePath, atomically: true, encoding: .utf8)
    }

    static func readPID() -> Int32? {
        guard FileManager.default.fileExists(atPath: pidFilePath.path),
              let content = try? String(contentsOf: pidFilePath, encoding: .utf8) else {
            return nil
        }

        let lines = content.components(separatedBy: .newlines)
        guard let firstLine = lines.first,
              let pid = Int32(firstLine.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return nil
        }

        return pid
    }

    static func getPIDFileAge() -> TimeInterval? {
        guard FileManager.default.fileExists(atPath: pidFilePath.path),
              let content = try? String(contentsOf: pidFilePath, encoding: .utf8) else {
            return nil
        }

        let lines = content.components(separatedBy: .newlines)
        guard lines.count >= 2,
              let timestamp = Int(lines[1].trimmingCharacters(in: .whitespacesAndNewlines)) else {
            // Old format without timestamp - use file modification time
            if let attrs = try? FileManager.default.attributesOfItem(atPath: pidFilePath.path),
               let modDate = attrs[.modificationDate] as? Date {
                return Date().timeIntervalSince(modDate)
            }
            return nil
        }

        let pidStartTime = Date(timeIntervalSince1970: TimeInterval(timestamp))
        return Date().timeIntervalSince(pidStartTime)
    }

    static func removePIDFile() {
        try? FileManager.default.removeItem(at: pidFilePath)
    }

    // MARK: - Process Management

    static func isProcessRunning(_ pid: Int32) -> Bool {
        return kill(pid, 0) == 0
    }

    static func getProcessName(_ pid: Int32) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-p", "\(pid)", "-o", "comm="]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            return output
        } catch {
            return nil
        }
    }

    static func isCorrectMeProcess(_ pid: Int32) -> Bool {
        guard let processName = getProcessName(pid) else {
            return false
        }
        // Check if process name contains "CorrectMe" or "correctme"
        return processName.lowercased().contains("correctme")
    }

    static func getDaemonPID() -> Int32? {
        guard let pid = readPID() else {
            // No PID file
            return nil
        }

        // Check if process is running
        guard isProcessRunning(pid) else {
            // Process not running - clean up stale PID file
            print("⚠️  Found stale PID file (process \(pid) not running), cleaning up...")
            removePIDFile()
            return nil
        }

        // Check if it's actually a CorrectMe process
        guard isCorrectMeProcess(pid) else {
            print("⚠️  Found PID file but process \(pid) is not CorrectMe, cleaning up...")
            removePIDFile()
            return nil
        }

        return pid
    }

    static func stopDaemon() -> Bool {
        guard let pid = getDaemonPID() else {
            print("No daemon process is running.")
            return false
        }

        print("Stopping daemon (PID: \(pid))...")

        // Send SIGTERM for graceful shutdown
        if kill(pid, SIGTERM) == 0 {
            // Wait up to 5 seconds for graceful shutdown
            for _ in 0..<50 {
                if !isProcessRunning(pid) {
                    removePIDFile()
                    print("✓ Daemon stopped successfully")
                    return true
                }
                usleep(100_000) // 100ms
            }

            // Force kill if still running
            print("Daemon not responding, forcing shutdown...")
            if kill(pid, SIGKILL) == 0 {
                removePIDFile()
                print("✓ Daemon force stopped")
                return true
            }
        }

        print("❌ Failed to stop daemon")
        return false
    }

    static func checkStatus() {
        if let pid = getDaemonPID() {
            var statusText = """

            CorrectMe Status:
            ─────────────────
            Status:    Running ✓
            Version:   \(AppVersion.fullVersion)
            PID:       \(pid)
            """

            // Add uptime if available
            if let age = getPIDFileAge() {
                let hours = Int(age) / 3600
                let minutes = (Int(age) % 3600) / 60
                let seconds = Int(age) % 60

                if hours > 0 {
                    statusText += "\nUptime:    \(hours)h \(minutes)m \(seconds)s"
                } else if minutes > 0 {
                    statusText += "\nUptime:    \(minutes)m \(seconds)s"
                } else {
                    statusText += "\nUptime:    \(seconds)s"
                }
            }

            statusText += """

            Config:    \(Config.configPath.path)
            PID File:  \(pidFilePath.path)
            Log:       \(logFilePath.path)
            Error Log: \(errorLogFilePath.path)

            """

            print(statusText)
        } else {
            print("""

            CorrectMe Status:
            ─────────────────
            Status:    Not running ✗

            Run 'correctme start' to start the daemon.

            """)
        }
    }

    // MARK: - Daemon Startup

    static func startDaemon(background: Bool) -> Never {
        // Check if already running
        if let existingPID = getDaemonPID() {
            print("❌ Daemon is already running (PID: \(existingPID))")
            print("   Use 'correctme stop' to stop it first, or 'correctme restart' to restart.")
            exit(1)
        }

        if background {
            startInBackground()
        } else {
            startInForeground()
        }
    }

    private static func startInForeground() -> Never {
        // Write PID file
        do {
            try writePID(getpid())
        } catch {
            print("❌ Failed to write PID file: \(error)")
            exit(1)
        }

        // Setup cleanup on exit
        setupCleanupHandlers()

        // Run the daemon
        CorrectMeApp.runDaemon()

        // This should never be reached
        exit(0)
    }

    private static func startInBackground() -> Never {
        print("Starting daemon in background...")

        // Create log directory
        let logDir = logFilePath.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: logDir, withIntermediateDirectories: true)

        // Get path to executable
        guard let executablePath = ProcessInfo.processInfo.arguments.first else {
            print("❌ Failed to determine executable path")
            exit(1)
        }

        // Spawn new process with special flag; propagate --verbose if set
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        var daemonArgs = ["__daemon_start"]
        if isVerboseLogging { daemonArgs.append("--verbose") }
        process.arguments = daemonArgs

        // Redirect stdout/stderr to log files (append mode)
        let outFile: FileHandle = {
            if !FileManager.default.fileExists(atPath: logFilePath.path) {
                FileManager.default.createFile(atPath: logFilePath.path, contents: nil)
            }
            let handle = FileHandle(forWritingAtPath: logFilePath.path)!
            handle.seekToEndOfFile()  // Append mode
            return handle
        }()

        let errFile: FileHandle = {
            if !FileManager.default.fileExists(atPath: errorLogFilePath.path) {
                FileManager.default.createFile(atPath: errorLogFilePath.path, contents: nil)
            }
            let handle = FileHandle(forWritingAtPath: errorLogFilePath.path)!
            handle.seekToEndOfFile()  // Append mode
            return handle
        }()

        process.standardOutput = outFile
        process.standardError = errFile
        process.standardInput = nil

        do {
            try process.run()
            // Give the process time to write PID file
            usleep(200_000) // 200ms

            // Read PID from file
            if let pid = readPID() {
                print("✓ Daemon started (PID: \(pid))")
                print("  Log: \(logFilePath.path)")
                print("  Use 'correctme status' to check status")
                print("  Use 'correctme stop' to stop the daemon")
            } else {
                print("✓ Daemon started")
                print("  Log: \(logFilePath.path)")
            }

            exit(0)
        } catch {
            print("❌ Failed to start daemon: \(error)")
            exit(1)
        }
    }

    // MARK: - launchd-based Lifecycle (used when LaunchAgent plist is installed)

    static func startViaLaunchAgent() -> Never {
        if let existingPID = getDaemonPID() {
            print("❌ Daemon is already running (PID: \(existingPID))")
            print("   Use 'correctme stop' to stop it first, or 'correctme restart' to restart.")
            exit(1)
        }

        print("Starting daemon via launchd...")
        let result = runLaunchctl(["start", "com.correctme.daemon"])
        usleep(400_000) // Wait for daemon to write PID file

        if let pid = readPID() {
            print("✓ Daemon started (PID: \(pid))")
        } else if result == 0 {
            print("✓ Daemon started")
        } else {
            print("❌ Failed to start daemon via launchd")
        }
        print("  Log: \(logFilePath.path)")
        exit(result == 0 ? 0 : 1)
    }

    @discardableResult
    static func stopViaLaunchAgent() -> Bool {
        print("Stopping daemon...")
        runLaunchctl(["stop", "com.correctme.daemon"])
        usleep(700_000) // Give process time to terminate
        // Clean up stale PID file if process is gone
        if let pid = readPID(), !isProcessRunning(pid) {
            removePIDFile()
        }
        print("✓ Daemon stopped")
        return true
    }

    static func restartViaLaunchAgent() -> Never {
        print("Restarting daemon...")
        runLaunchctl(["stop", "com.correctme.daemon"])
        sleep(1)
        let result = runLaunchctl(["start", "com.correctme.daemon"])
        usleep(400_000) // Wait for daemon to write PID file

        if let pid = readPID() {
            print("✓ Daemon restarted (PID: \(pid))")
        } else if result == 0 {
            print("✓ Daemon restarted")
        } else {
            print("❌ Failed to restart daemon")
        }
        print("  Log: \(logFilePath.path)")
        exit(result == 0 ? 0 : 1)
    }

    static func setupCleanupHandlers() {
        // Clean up PID file on exit
        atexit {
            DaemonManager.removePIDFile()
        }

        // Handle termination signals
        signal(SIGTERM) { _ in
            print("\n👋 Daemon received SIGTERM, shutting down...")
            fflush(stdout)
            DaemonManager.removePIDFile()
            exit(0)
        }

        signal(SIGINT) { _ in
            print("\n👋 Daemon received SIGINT, shutting down...")
            fflush(stdout)
            DaemonManager.removePIDFile()
            exit(0)
        }
    }
}
