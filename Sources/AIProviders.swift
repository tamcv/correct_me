import Foundation

protocol AIProvider {
    func correctText(_ text: String) async throws -> String
}

/// Bundle ID of the frontmost app when the hotkey was triggered.
/// Set by handleHotkey() before calling correctText(), read by buildCorrectionPrompt().
var currentCorrectionBundleId: String?

// MARK: - Helper Functions

/// Get environment variables that help prevent connection caching issues
private func getFreshConnectionEnvironment() -> [String: String] {
    var env = ProcessInfo.processInfo.environment
    // Disable connection pooling for curl-based CLIs
    env["CURL_DISABLE_KEEPALIVE"] = "1"
    // Force fresh DNS resolution
    env["RES_OPTIONS"] = "rotate"
    return env
}

/// Safely cleanup a Process and its pipes
private func cleanupProcess(_ process: Process, outputPipe: Pipe, errorPipe: Pipe) {
    if process.isRunning {
        process.terminate()
    }
    // Close file handles to release resources
    try? outputPipe.fileHandleForReading.close()
    try? errorPipe.fileHandleForReading.close()
}

/// Get a URLSession configured to avoid connection caching issues
private func getFreshURLSession() -> URLSession {
    let config = URLSessionConfiguration.ephemeral // Don't use any caches
    config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
    config.urlCache = nil
    config.httpShouldUsePipelining = false
    config.httpMaximumConnectionsPerHost = 1
    config.timeoutIntervalForRequest = 15.0
    config.timeoutIntervalForResource = 30.0
    // Force IPv4 first for better compatibility
    config.connectionProxyDictionary = [:]
    return URLSession(configuration: config)
}

func findExecutable(_ name: String) -> String? {
    // Common installation paths to check
    let searchPaths = [
        "/usr/local/bin/\(name)",
        "/opt/homebrew/bin/\(name)",
        "\(FileManager.default.homeDirectoryForCurrentUser.path)/.local/bin/\(name)",
        "/usr/bin/\(name)",
    ]

    for path in searchPaths {
        if FileManager.default.isExecutableFile(atPath: path) {
            return path
        }
    }

    // Fallback: try using 'which' command
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
    process.arguments = [name]

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = Pipe()

    do {
        try process.run()
        process.waitUntilExit()

        if process.terminationStatus == 0 {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !path.isEmpty {
                return path
            }
        }
    } catch {
        return nil
    }

    return nil
}

// MARK: - Claude Code (uses local claude command)
class ClaudeCodeProvider: AIProvider {
    private let model: String?

    init(model: String?) {
        self.model = model
    }

    func correctText(_ text: String) async throws -> String {
        // Find claude executable path
        guard let claudePath = findExecutable("claude") else {
            throw AIError.commandFailed("Claude CLI not found. Please ensure Claude Code is installed and accessible.")
        }

        let prompt = buildCorrectionPrompt(text: text)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: claudePath)
        process.currentDirectoryURL = FileManager.default.temporaryDirectory
        process.environment = getFreshConnectionEnvironment()
        var args = ["--no-session-persistence"]
        if let model {
            args += ["--model", model]
        }
        args += ["-p", prompt]
        process.arguments = args

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()

        // Add timeout mechanism - Claude CLI needs more time to start up
        let timeout: TimeInterval = 45.0 // 45 seconds
        let deadline = Date().addingTimeInterval(timeout)

        while process.isRunning && Date() < deadline {
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        }

        if process.isRunning {
            cleanupProcess(process, outputPipe: outputPipe, errorPipe: errorPipe)
            throw AIError.commandFailed("Claude CLI timed out after \(Int(timeout)) seconds")
        }

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        // Cleanup pipes after reading
        cleanupProcess(process, outputPipe: outputPipe, errorPipe: errorPipe)

        if process.terminationStatus != 0 {
            throw AIError.commandFailed("Claude CLI failed with exit code \(process.terminationStatus)")
        }

        return output
    }
}

// MARK: - Codex Code (uses local codex command)
class CodexCodeProvider: AIProvider {
    private let model: String?

    init(model: String?) {
        self.model = model
    }

    func correctText(_ text: String) async throws -> String {
        // Find codex executable path
        guard let codexPath = findExecutable("codex") else {
            throw AIError.commandFailed("Codex CLI not found. Please ensure Codex is installed and accessible.")
        }

        let prompt = buildCorrectionPrompt(
            text: text,
            context: "IMPORTANT: Do not scan, read, or index any files in the repository or workspace.\nDo not access any file system or project context.\n\n"
        )

        let tempDir = FileManager.default.temporaryDirectory
        let outputURL = tempDir.appendingPathComponent("correctme_codex_output_\(UUID().uuidString).txt")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: codexPath)
        process.currentDirectoryURL = FileManager.default.temporaryDirectory
        process.environment = getFreshConnectionEnvironment()
        var args: [String] = []
        if let model {
            args += ["exec", "--model", model]
        } else {
            args += ["exec"]
        }
        args += ["--output-last-message", outputURL.path, "-"]
        process.arguments = args

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        let inputPipe = Pipe()
        process.standardInput = inputPipe

        try process.run()
        if let inputData = prompt.data(using: .utf8) {
            inputPipe.fileHandleForWriting.write(inputData)
        }
        inputPipe.fileHandleForWriting.closeFile()

        // Add timeout mechanism - CLI tools need time to start up
        let timeout: TimeInterval = 45.0 // 45 seconds
        let deadline = Date().addingTimeInterval(timeout)

        while process.isRunning && Date() < deadline {
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        }

        if process.isRunning {
            cleanupProcess(process, outputPipe: outputPipe, errorPipe: errorPipe)
            try? FileManager.default.removeItem(at: outputURL)
            throw AIError.commandFailed("Codex CLI timed out after \(Int(timeout)) seconds")
        }

        // Read output before cleanup
        let fileData = (try? Data(contentsOf: outputURL)) ?? Data()
        let output = String(data: fileData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        
        // Cleanup
        cleanupProcess(process, outputPipe: outputPipe, errorPipe: errorPipe)
        try? FileManager.default.removeItem(at: outputURL)

        if process.terminationStatus != 0 {
            throw AIError.commandFailed("Codex CLI failed with exit code \(process.terminationStatus)")
        }

        if output.isEmpty {
            throw AIError.parseError
        }

        return output
    }
}

// MARK: - GitHub Copilot CLI
class CopilotProvider: AIProvider {
    private let model: String?

    init(model: String?) {
        self.model = model
    }

    func correctText(_ text: String) async throws -> String {
        // Find gh copilot executable path
        guard let ghPath = findExecutable("gh") else {
            throw AIError.commandFailed("GitHub CLI not found. Please install: brew install gh")
        }

        let prompt = buildCorrectionPrompt(
            text: text,
            context: "IMPORTANT: Do not scan, read, or index any files in the repository or workspace.\nDo not access any file system or project context.\nDo not try to understand project structure or read any code.\n\n"
        )

        let process = Process()
        process.executableURL = URL(fileURLWithPath: ghPath)
        process.currentDirectoryURL = FileManager.default.temporaryDirectory
        process.environment = getFreshConnectionEnvironment()
        var args = ["copilot"]
        if let model {
            args += ["--model", model]
        }
        args += ["-p", prompt]
        process.arguments = args

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()

        // Add timeout mechanism - CLI tools need time to start up
        let timeout: TimeInterval = 45.0 // 45 seconds
        let deadline = Date().addingTimeInterval(timeout)

        while process.isRunning && Date() < deadline {
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        }

        if process.isRunning {
            cleanupProcess(process, outputPipe: outputPipe, errorPipe: errorPipe)
            throw AIError.commandFailed("Copilot CLI timed out after \(Int(timeout)) seconds")
        }

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        // Cleanup
        cleanupProcess(process, outputPipe: outputPipe, errorPipe: errorPipe)

        if process.terminationStatus != 0 {
            throw AIError.commandFailed("Copilot CLI failed with exit code \(process.terminationStatus)")
        }

        if output.isEmpty {
            throw AIError.parseError
        }

        return output
    }
}

// MARK: - Claude API
class ClaudeAPIProvider: AIProvider {
    private let apiKey: String
    private let model: String
    
    init(apiKey: String, model: String) {
        self.apiKey = apiKey
        self.model = model
    }
    
    func correctText(_ text: String) async throws -> String {
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 15.0 // 15 seconds timeout
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("close", forHTTPHeaderField: "Connection") // Disable keep-alive
        
        let prompt = buildCorrectionPrompt(
            text: text,
            context: "IMPORTANT: Do not scan, read, or index any files in the repository or workspace.\nDo not access any file system or project context.\n\n"
        )

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 4096,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let session = getFreshURLSession()
        let (data, response) = try await session.data(for: request)
        session.invalidateAndCancel() // Clean up session immediately
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw AIError.apiError("Claude API request failed (\(status)): \(parseErrorMessage(from: data))")
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let content = json?["content"] as? [[String: Any]],
              let firstContent = content.first,
              let result = firstContent["text"] as? String else {
            throw AIError.parseError
        }
        
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Gemini API
class GeminiProvider: AIProvider {
    private let apiKey: String
    private let model: String
    
    init(apiKey: String, model: String) {
        self.apiKey = apiKey
        self.model = model
    }
    
    func correctText(_ text: String) async throws -> String {
        let url = URL(string: "https://generativelanguage.googleapis.com/v1/models/\(model):generateContent?key=\(apiKey)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 15.0 // 15 seconds timeout
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("close", forHTTPHeaderField: "Connection") // Disable keep-alive
        
        let prompt = buildCorrectionPrompt(
            text: text,
            context: "IMPORTANT: Do not scan, read, or index any files in the repository or workspace.\nDo not access any file system or project context.\n\n"
        )

        let body: [String: Any] = [
            "contents": [
                ["parts": [["text": prompt]]]
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let session = getFreshURLSession()
        let (data, response) = try await session.data(for: request)
        session.invalidateAndCancel() // Clean up session immediately
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw AIError.apiError("Gemini API request failed (\(status)): \(parseErrorMessage(from: data))")
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let candidates = json?["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let result = firstPart["text"] as? String else {
            throw AIError.parseError
        }
        
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - OpenAI Codex (Responses API)
class OpenAICodexProvider: AIProvider {
    private let apiKey: String
    private let model: String

    init(apiKey: String, model: String) {
        self.apiKey = apiKey
        self.model = model
    }

    func correctText(_ text: String) async throws -> String {
        let url = URL(string: "https://api.openai.com/v1/responses")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 15.0 // 15 seconds timeout
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("close", forHTTPHeaderField: "Connection") // Disable keep-alive

        let prompt = buildCorrectionPrompt(
            text: text,
            context: "IMPORTANT: Do not scan, read, or index any files in the repository or workspace.\nDo not access any file system or project context.\n\n"
        )

        let body: [String: Any] = [
            "model": model,
            "input": prompt
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let session = getFreshURLSession()
        let (data, response) = try await session.data(for: request)
        session.invalidateAndCancel() // Clean up session immediately
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw AIError.apiError("OpenAI API request failed (\(status)): \(parseErrorMessage(from: data))")
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let output = json?["output"] as? [[String: Any]] else {
            throw AIError.parseError
        }

        var texts: [String] = []
        for item in output {
            guard let type = item["type"] as? String, type == "message" else { continue }
            guard let content = item["content"] as? [[String: Any]] else { continue }
            for part in content {
                if let partType = part["type"] as? String, partType == "output_text",
                   let textValue = part["text"] as? String {
                    texts.append(textValue)
                }
            }
        }

        let result = texts.joined()
        guard !result.isEmpty else { throw AIError.parseError }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - OpenRouter (OpenAI-compatible Chat Completions API)
class OpenRouterProvider: AIProvider {
    private let apiKey: String
    private let model: String
    private let fallbackModels: [String]

    /// Track the model that was actually used for the last successful call.
    private(set) var lastUsedModel: String?

    init(apiKey: String, model: String, fallbackModels: [String] = []) {
        self.apiKey = apiKey
        self.model = model
        self.fallbackModels = fallbackModels
    }

    func correctText(_ text: String) async throws -> String {
        // Build the model chain: primary + fallbacks
        var modelsToTry = [model] + fallbackModels

        // De-duplicate while preserving order
        var seen = Set<String>()
        modelsToTry = modelsToTry.filter { seen.insert($0).inserted }

        let prompt = buildCorrectionPrompt(
            text: text,
            context: "IMPORTANT: Do not scan, read, or index any files in the repository or workspace.\nDo not access any file system or project context.\n\n"
        )

        var lastError: Error = AIError.noProviderConfigured

        for (index, currentModel) in modelsToTry.enumerated() {
            do {
                let result = try await callOpenRouter(model: currentModel, prompt: prompt)
                lastUsedModel = currentModel
                if index > 0 {
                    debugLog("OpenRouter: model \(model) unavailable, used fallback \(currentModel)")
                }
                return result
            } catch let error as AIError {
                lastError = error
                // Only retry on 429 (rate limit) or 503 (overloaded)
                if case .apiError(let msg) = error,
                   (msg.contains("(429)") || msg.contains("(503)")) {
                    debugLog("OpenRouter: \(currentModel) returned rate limit/overload, trying next model...")
                    continue
                }
                // Other errors (auth, parse, etc.) — don't retry
                throw error
            }
        }

        // All models exhausted
        throw lastError
    }

    /// Single API call to OpenRouter with a specific model.
    private func callOpenRouter(model: String, prompt: String) async throws -> String {
        let url = URL(string: "https://openrouter.ai/api/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 15.0
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("close", forHTTPHeaderField: "Connection")

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let session = getFreshURLSession()
        let (data, response) = try await session.data(for: request)
        session.invalidateAndCancel()

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw AIError.apiError("OpenRouter API request failed (\(status)): \(parseErrorMessage(from: data))")
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let choices = json?["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let result = message["content"] as? String else {
            throw AIError.parseError
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Static: discover and benchmark free models

    /// Known-good model families that typically produce quality text corrections.
    /// Used to pre-filter before expensive benchmarking.
    private static let preferredModelFamilies = [
        "llama", "mistral", "gemma", "qwen", "phi",
        "deepseek", "wizardlm", "openchat", "hermes",
        "zephyr", "nous", "yi", "command", "dbrx",
        "internlm", "glm", "nemotron", "aya",
    ]

    /// Maximum number of models to benchmark (each model = 2 API calls).
    private static let maxModelsToBenchmark = 10

    /// Context length sweet spot for text correction tasks.
    /// Too small (<4K) = model is too weak. Too large (>65K) = likely a huge slow model.
    private static let minContextLength = 4_096
    private static let maxContextLength = 65_536

    /// Model ID patterns that indicate oversized/slow models (70B+, MoE giants, etc.).
    private static let oversizedPatterns = [
        "405b", "403b", "236b", "180b", "141b",  // giant dense models
        "120b", "110b", "104b", "72b", "70b",     // large models
        "65b", "48b",                               // still very large
    ]

    /// Fetch free models from OpenRouter, pre-filtered to known-good families
    /// and right-sized for text correction (fast, not too big, not too small).
    /// Returns (allFreeCount, candidateModels) — allFreeCount is for display only.
    static func fetchFreeModels(apiKey: String) async -> (totalFree: Int, candidates: [(id: String, name: String)]) {
        guard let url = URL(string: "https://openrouter.ai/api/v1/models") else { return (0, []) }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10

        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let models = json["data"] as? [[String: Any]] else {
            return (0, [])
        }

        // Collect all free models
        let allFree = models.compactMap { m -> (id: String, name: String, contextLength: Int)? in
            guard let id = m["id"] as? String,
                  id.hasSuffix(":free"),
                  let name = m["name"] as? String else { return nil }
            let ctx = m["context_length"] as? Int ?? 0
            return (id, name, ctx)
        }

        let candidates = allFree
            // 1. Only known-good families
            .filter { model in
                let lower = model.id.lowercased()
                return preferredModelFamilies.contains { lower.contains($0) }
            }
            // 2. Context length in sweet spot (not too small, not too large)
            .filter { $0.contextLength >= minContextLength && $0.contextLength <= maxContextLength }
            // 3. Drop oversized models (70B+ params) — too slow for text correction
            .filter { model in
                let lower = model.id.lowercased()
                return !oversizedPatterns.contains { lower.contains($0) }
            }
            // 4. Sort by context length descending (prefer capable models within the size cap)
            .sorted { $0.contextLength > $1.contextLength }

        // Cap at maxModelsToBenchmark
        let capped = Array(candidates.prefix(maxModelsToBenchmark))

        return (allFree.count, capped.map { ($0.id, $0.name) })
    }

    /// Quality test cases: input text with known errors → expected keywords in correct output.
    private static let qualityTests: [(input: String, prompt: String, mustContain: [String], mustNotContain: [String])] = [
        // English grammar test
        (
            input: "She dont goes to school yesterday",
            prompt: "Detect the language of the following text and correct its spelling and grammar in that same language.\nRules:\n- Return ONLY the corrected text — no explanations, no markdown, no quotes.\n- Preserve the original language exactly.\n- If the text is already correct, return it unchanged.\n\nText to correct:\nShe dont goes to school yesterday",
            mustContain: ["didn't", "go", "school", "yesterday"],
            mustNotContain: ["```", "here is", "sure", "corrected"]
        ),
        // Vietnamese test
        (
            input: "toi di hoc ngay hom wa",
            prompt: "Detect the language of the following text and correct its spelling and grammar in that same language.\nRules:\n- Return ONLY the corrected text — no explanations, no markdown, no quotes.\n- Preserve the original language exactly.\n- For Vietnamese text: fix tone marks (dấu), diacritics, and common lỗi chính tả while keeping the meaning intact.\n- If the text is already correct, return it unchanged.\n\nText to correct:\ntoi di hoc ngay hom wa",
            mustContain: ["tôi", "đi", "học"],
            mustNotContain: ["```", "here is", "sure"]
        ),
    ]

    /// Evaluate quality of a model response.
    /// Returns a score 0.0–1.0 (1.0 = perfect).
    private static func evaluateQuality(_ response: String, testIndex: Int) -> Double {
        let test = qualityTests[testIndex]
        let lower = response.lowercased()

        // Check must-contain keywords
        let containHits = test.mustContain.filter { lower.contains($0.lowercased()) }
        let containScore = Double(containHits.count) / Double(test.mustContain.count)

        // Penalize if response contains unwanted commentary
        let hasUnwanted = test.mustNotContain.contains { lower.contains($0.lowercased()) }
        let cleanScore: Double = hasUnwanted ? 0.0 : 1.0

        // Penalize overly long responses (likely includes explanation)
        let lengthRatio = Double(response.count) / Double(test.input.count)
        let lengthScore: Double = lengthRatio > 3.0 ? 0.3 : 1.0

        // Weighted: 50% keyword accuracy, 30% clean output, 20% length
        return containScore * 0.5 + cleanScore * 0.3 + lengthScore * 0.2
    }

    /// Benchmark a single model: send correction prompts, measure latency and quality.
    /// Returns (model_id, latency_ms, quality_score) on success, nil on failure.
    /// Quality score is 0.0–1.0; models below 0.5 are considered low quality.
    static func benchmarkModel(apiKey: String, modelId: String) async -> (id: String, latencyMs: Int, quality: Double)? {
        let url = URL(string: "https://openrouter.ai/api/v1/chat/completions")!

        var totalLatency = 0
        var totalQuality = 0.0
        var testsRun = 0

        for (index, test) in qualityTests.enumerated() {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = 15
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

            let body: [String: Any] = [
                "model": modelId,
                "messages": [
                    ["role": "user", "content": test.prompt]
                ]
            ]
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)

            let start = CFAbsoluteTimeGetCurrent()
            guard let (data, response) = try? await URLSession.shared.data(for: request),
                  let http = response as? HTTPURLResponse,
                  http.statusCode == 200 else {
                // If any test fails (rate limit, timeout), skip this model
                return nil
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let first = choices.first,
                  let msg = first["message"] as? [String: Any],
                  let content = msg["content"] as? String,
                  !content.isEmpty else {
                return nil
            }

            let elapsed = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
            let quality = evaluateQuality(content, testIndex: index)

            totalLatency += elapsed
            totalQuality += quality
            testsRun += 1

            // Early exit: if first test quality is terrible, skip the rest
            if index == 0 && quality < 0.3 {
                return (modelId, elapsed, quality)
            }
        }

        guard testsRun > 0 else { return nil }
        let avgLatency = totalLatency / testsRun
        let avgQuality = totalQuality / Double(testsRun)
        return (modelId, avgLatency, avgQuality)
    }
}

// MARK: - Errors
enum AIError: Error, LocalizedError {
    case commandFailed(String)
    case apiError(String)
    case parseError
    case noProviderConfigured
    
    var errorDescription: String? {
        switch self {
        case .commandFailed(let msg): return "Command failed: \(msg)"
        case .apiError(let msg): return "API error: \(msg)"
        case .parseError: return "Failed to parse AI response"
        case .noProviderConfigured: return "No AI provider configured"
        }
    }
}

// MARK: - Factory
func createAIProvider(from config: Config) throws -> AIProvider {
    switch config.aiProvider {
    case .claudeCode:
        guard findExecutable("claude") != nil else {
            throw AIError.commandFailed(
                "Claude CLI not found. Install Claude Code from https://claude.ai/code, " +
                "then make sure the 'claude' command is accessible in your PATH."
            )
        }
        let model = config.model ?? Config.DefaultModels.claudeCode
        return ClaudeCodeProvider(model: model)
    case .codexCode:
        guard findExecutable("codex") != nil else {
            throw AIError.commandFailed(
                "Codex CLI not found. Install Codex and make sure the 'codex' command is accessible in your PATH."
            )
        }
        let model = config.model ?? Config.DefaultModels.openaiCodex
        return CodexCodeProvider(model: model)
    case .copilot:
        guard findExecutable("gh") != nil else {
            throw AIError.commandFailed(
                "GitHub CLI not found. Install with: brew install gh, " +
                "then run: gh extension install github/gh-copilot"
            )
        }
        let model = config.model ?? Config.DefaultModels.copilot
        return CopilotProvider(model: model)
    case .claude:
        guard let apiKey = config.anthropicAPIKey, !apiKey.isEmpty else {
            throw AIError.noProviderConfigured
        }
        let model = config.model ?? Config.DefaultModels.anthropic
        return ClaudeAPIProvider(apiKey: apiKey, model: model)
    case .gemini:
        guard let apiKey = config.geminiAPIKey, !apiKey.isEmpty else {
            throw AIError.noProviderConfigured
        }
        let model = config.model ?? Config.DefaultModels.gemini
        return GeminiProvider(apiKey: apiKey, model: model)
    case .codex:
        guard let apiKey = config.openaiAPIKey, !apiKey.isEmpty else {
            throw AIError.noProviderConfigured
        }
        let model = config.model ?? Config.DefaultModels.openaiCodex
        return OpenAICodexProvider(apiKey: apiKey, model: model)
    case .openrouter:
        guard let apiKey = config.openrouterAPIKey, !apiKey.isEmpty else {
            throw AIError.noProviderConfigured
        }
        let model = config.model ?? Config.DefaultModels.openrouter
        return OpenRouterProvider(apiKey: apiKey, model: model, fallbackModels: config.fallbackModels ?? [])
    }
}

/// Build correction prompt, appending user's writing style requirements if set.
/// Reads config fresh each call so changes in Preferences take effect immediately.
///
/// Language handling: the prompt explicitly instructs the model to detect the
/// language of the input and correct it in that language. Vietnamese (tiếng Việt)
/// is called out explicitly because tone marks and diacritics are commonly
/// mishandled by generic spell-checkers.
func buildCorrectionPrompt(text: String, context: String = "") -> String {
    let config = Config.load()
    let bundleId = currentCorrectionBundleId

    // Per-app style takes priority, fall back to global style
    let writingStyle: String
    if let bundleId = bundleId,
       let appStyle = config.perAppStyles?[bundleId],
       !appStyle.isEmpty {
        writingStyle = appStyle
    } else {
        writingStyle = config.writingStyle ?? ""
    }

    if writingStyle.isEmpty {
        return """
        \(context)Detect the language of the following text and correct its spelling and grammar in that same language.
        Rules:
        - Return ONLY the corrected text — no explanations, no markdown, no quotes.
        - Preserve the original language exactly (e.g. English stays English, Vietnamese/tiếng Việt stays Vietnamese, etc.).
        - For Vietnamese text: fix tone marks (dấu), diacritics, and common lỗi chính tả while keeping the meaning intact.
        - Preserve the original formatting and line breaks.
        - If the text is already correct, return it unchanged.

        Text to correct:
        \(text)
        """
    } else {
        return """
        \(context)Detect the language of the following text and rewrite/improve it in that same language.
        Apply these writing style requirements: \(writingStyle)
        Also fix any spelling and grammar errors.
        Rules:
        - Return ONLY the rewritten text — no explanations, no markdown, no quotes.
        - Preserve the original language exactly (e.g. English stays English, Vietnamese/tiếng Việt stays Vietnamese, etc.).
        - For Vietnamese text: ensure tone marks (dấu) and diacritics are correct.
        - Preserve the original formatting and line breaks.

        Text to rewrite:
        \(text)
        """
    }
}

private func parseErrorMessage(from data: Data) -> String {
    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
        if let error = json["error"] as? [String: Any] {
            if let message = error["message"] as? String {
                return message
            }
        }
        if let message = json["message"] as? String {
            return message
        }
        if let error = json["error"] as? String {
            return error
        }
    }
    let raw = String(data: data, encoding: .utf8) ?? "Unknown error"
    return raw.trimmingCharacters(in: .whitespacesAndNewlines)
}
