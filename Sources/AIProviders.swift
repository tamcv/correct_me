import Foundation

protocol AIProvider {
    func correctText(_ text: String) async throws -> String
}

// MARK: - Claude Code (uses local claude command)
class ClaudeCodeProvider: AIProvider {
    private let model: String?

    init(model: String?) {
        self.model = model
    }

    func correctText(_ text: String) async throws -> String {
        let prompt = """
        Correct the spelling and grammar of the following text.
        Return ONLY the corrected text without any explanation or markdown.
        Preserve the original formatting, line breaks, and language.
        If the text is already correct, return it unchanged.

        Text to correct:
        \(text)
        """

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        var args = ["claude", "--no-session-persistence"]
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

        // Add timeout mechanism
        let timeout: TimeInterval = 30.0 // 30 seconds
        let deadline = Date().addingTimeInterval(timeout)

        while process.isRunning && Date() < deadline {
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        }

        if process.isRunning {
            process.terminate()
            throw AIError.commandFailed("Claude CLI timed out after \(Int(timeout)) seconds")
        }

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if process.terminationStatus != 0 {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let error = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw AIError.commandFailed(error)
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
        let prompt = """
        Correct the spelling and grammar of the following text.
        Return ONLY the corrected text without any explanation or markdown.
        Preserve the original formatting, line breaks, and language.
        If the text is already correct, return it unchanged.

        Text to correct:
        \(text)
        """

        let tempDir = FileManager.default.temporaryDirectory
        let outputURL = tempDir.appendingPathComponent("correctme_codex_output_\(UUID().uuidString).txt")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        var args = ["codex"]
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
        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        _ = String(data: outputData, encoding: .utf8) ?? ""

        if process.terminationStatus != 0 {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let error = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw AIError.commandFailed(error)
        }

        let fileData = (try? Data(contentsOf: outputURL)) ?? Data()
        let output = String(data: fileData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        try? FileManager.default.removeItem(at: outputURL)

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
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        
        let prompt = """
        Correct the spelling and grammar of the following text.
        Return ONLY the corrected text without any explanation or markdown.
        Preserve the original formatting, line breaks, and language.
        If the text is already correct, return it unchanged.
        
        Text to correct:
        \(text)
        """
        
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 4096,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
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
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let prompt = """
        Correct the spelling and grammar of the following text.
        Return ONLY the corrected text without any explanation or markdown.
        Preserve the original formatting, line breaks, and language.
        If the text is already correct, return it unchanged.
        
        Text to correct:
        \(text)
        """
        
        let body: [String: Any] = [
            "contents": [
                ["parts": [["text": prompt]]]
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
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
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let prompt = """
        Correct the spelling and grammar of the following text.
        Return ONLY the corrected text without any explanation or markdown.
        Preserve the original formatting, line breaks, and language.
        If the text is already correct, return it unchanged.

        Text to correct:
        \(text)
        """

        let body: [String: Any] = [
            "model": model,
            "input": prompt
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        
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
        let model = config.model ?? Config.DefaultModels.claudeCode
        return ClaudeCodeProvider(model: model)
    case .codexCode:
        let model = config.model ?? Config.DefaultModels.openaiCodex
        return CodexCodeProvider(model: model)
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
