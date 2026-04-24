import Foundation
import CoreGraphics

// Keychain account names and the JSON placeholder for stored keys.
private enum KeychainAccount {
    static let anthropic  = "anthropic_api_key"
    static let gemini     = "gemini_api_key"
    static let openai     = "openai_api_key"
    static let openrouter = "openrouter_api_key"
    static let freellmapi = "freellmapi_api_key"
    /// Value written to config.json when the real key lives in the Keychain.
    static let placeholder = "keychain"
}

struct Config: Codable {
    var aiProvider: AIProvider
    var anthropicAPIKey: String?
    var geminiAPIKey: String?
    var openaiAPIKey: String?
    var openrouterAPIKey: String?
    var freellmAPIKey: String?
    var freellmBaseURL: String?
    var hotkey: HotkeyConfig
    var customPrompt: String?
    var model: String?
    var fallbackModels: [String]?
    var writingStyle: String?
    var perAppStyles: [String: String]?
    var telegramBotToken: String?
    var telegramChatId: String?
    var forceApply: Bool?
    var ollamaBaseURL: String?
    var translateTargetLanguage: String?  // nil = auto (EN↔VI); see TranslateLanguage enum
    var customActions: [CustomAction]?   // nil → defaults are returned at load time (max 5)

    // MARK: - Custom Action

    struct CustomAction: Codable {
        /// Stable identifier (UUID string). Never changes after creation.
        var id: String
        /// Display name shown in the Quick Action Picker.
        var name: String
        /// Single emoji icon shown next to the name.
        var icon: String
        /// Task-level instruction written by the user.
        /// The language-preservation rule is automatically prepended at runtime.
        var prompt: String

        /// Three pre-built actions that replace the old hard-coded formal / casual / expand.
        static var defaults: [CustomAction] {
            [
                CustomAction(
                    id: "com.correctme.builtin.formal",
                    name: "Make formal",
                    icon: "📝",
                    prompt: "Rewrite the text below in a formal, professional tone while keeping its original language(s).\n- Fix spelling and grammar errors.\n- Return ONLY the rewritten text — no explanations, no quotes, no markdown."
                ),
                CustomAction(
                    id: "com.correctme.builtin.casual",
                    name: "Make casual",
                    icon: "💬",
                    prompt: "Rewrite the text below in a casual, friendly, conversational tone while keeping its original language(s).\n- Fix spelling and grammar errors.\n- Return ONLY the rewritten text — no explanations, no quotes, no markdown."
                ),
                CustomAction(
                    id: "com.correctme.builtin.expand",
                    name: "Expand",
                    icon: "➕",
                    prompt: "Expand and elaborate on the text below with more detail and context, in the same language(s) as the original.\n- Keep the same tone and style.\n- Return ONLY the expanded text — no explanations, no quotes, no markdown."
                ),
            ]
        }

        /// Builds the full AI prompt: language-preservation rule + user's task instruction + text.
        func buildPrompt(for text: String) -> String {
            """
            LANGUAGE RULE (highest priority): Detect the language(s) of the input text. \
            Your output MUST use the EXACT same language(s). \
            If the input is Vietnamese, output Vietnamese. \
            If the input is English, output English. \
            If the input mixes languages, keep that exact mix. \
            NEVER translate any word into a different language.

            \(prompt)

            Text:
            \(text)
            """
        }
    }

    enum AIProvider: String, Codable {
        case claude = "claude"
        case gemini = "gemini"
        case claudeCode = "claude-code"
        case codex = "codex"
        case codexCode = "codex-code"
        case copilot = "copilot"
        case openrouter = "openrouter"
        case ollama = "ollama"
        case freellmapi = "freellmapi"
    }

    struct HotkeyConfig: Codable {
        var keyCode: UInt16
        var modifiers: UInt64
        var displayName: String

        static var `default`: HotkeyConfig {
            HotkeyConfig(
                keyCode: 14, // 'E' key
                modifiers: CGEventFlags.maskCommand.rawValue | CGEventFlags.maskShift.rawValue,
                displayName: "⌘⇧E"
            )
        }
    }

    static var `default`: Config {
        Config(
            aiProvider: .claudeCode,
            anthropicAPIKey: nil,
            geminiAPIKey: nil,
            openaiAPIKey: nil,
            openrouterAPIKey: nil,
            freellmAPIKey: nil,
            freellmBaseURL: nil,
            hotkey: .default,
            customPrompt: nil,
            model: nil,
            writingStyle: nil,
            perAppStyles: nil,
            telegramBotToken: nil,
            telegramChatId: nil,
            forceApply: nil
        )
    }

    /// Available target languages for the Translate action.
    enum TranslateLanguage: String, CaseIterable {
        case auto                = "Auto (EN ↔ VI)"
        case english             = "English"
        case vietnamese          = "Vietnamese"
        case spanish             = "Spanish"
        case french              = "French"
        case german              = "German"
        case japanese            = "Japanese"
        case korean              = "Korean"
        case chineseSimplified   = "Chinese (Simplified)"
        case chineseTraditional  = "Chinese (Traditional)"
        case portuguese          = "Portuguese"
        case italian             = "Italian"
        case russian             = "Russian"
        case arabic              = "Arabic"
    }

    enum DefaultModels {
        static let claudeCode = "claude-haiku-4-5"
        static let anthropic = "claude-haiku-4-5-20251001"
        static let gemini = "gemini-2.0-flash"
        static let openaiCodex = "gpt-5.1-codex-mini"
        static let copilot = "gpt-5-mini"
        static let openrouter = "meta-llama/llama-3.1-8b-instruct:free"
        static let ollama = "llama3.2"
        static let freellmapi = "auto"
    }

    static var configPath: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".correctme/config.json")
    }

    /// Loads config from disk and resolves API keys from the Keychain.
    /// If any plaintext key is found in the JSON, it is migrated to the Keychain
    /// and the placeholder is flushed to disk immediately.
    static func load() -> Config {
        guard FileManager.default.fileExists(atPath: configPath.path),
              let data = try? Data(contentsOf: configPath),
              var config = try? JSONDecoder().decode(Config.self, from: data) else {
            return .default
        }

        var hadPlaintext = false
        config.anthropicAPIKey = resolveAPIKey(config.anthropicAPIKey,
                                               account: KeychainAccount.anthropic,
                                               hadPlaintext: &hadPlaintext)
        config.geminiAPIKey    = resolveAPIKey(config.geminiAPIKey,
                                               account: KeychainAccount.gemini,
                                               hadPlaintext: &hadPlaintext)
        config.openaiAPIKey    = resolveAPIKey(config.openaiAPIKey,
                                               account: KeychainAccount.openai,
                                               hadPlaintext: &hadPlaintext)
        config.openrouterAPIKey = resolveAPIKey(config.openrouterAPIKey,
                                                account: KeychainAccount.openrouter,
                                                hadPlaintext: &hadPlaintext)
        config.freellmAPIKey    = resolveAPIKey(config.freellmAPIKey,
                                                account: KeychainAccount.freellmapi,
                                                hadPlaintext: &hadPlaintext)

        // Populate custom action defaults for existing users who don't have them yet.
        if config.customActions == nil {
            config.customActions = CustomAction.defaults
        }

        // Flush any plaintext keys from disk right away.
        if hadPlaintext { try? config.save() }

        return config
    }

    /// Saves config to disk. API keys are written to the Keychain;
    /// only the placeholder string is stored in the JSON file.
    func save() throws {
        var sanitized = self
        sanitized.anthropicAPIKey = storeAPIKey(anthropicAPIKey, account: KeychainAccount.anthropic)
        sanitized.geminiAPIKey    = storeAPIKey(geminiAPIKey,    account: KeychainAccount.gemini)
        sanitized.openaiAPIKey    = storeAPIKey(openaiAPIKey,    account: KeychainAccount.openai)
        sanitized.openrouterAPIKey = storeAPIKey(openrouterAPIKey, account: KeychainAccount.openrouter)
        sanitized.freellmAPIKey    = storeAPIKey(freellmAPIKey,    account: KeychainAccount.freellmapi)

        let dir = Config.configPath.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(sanitized)
        try data.write(to: Config.configPath)
    }

    // MARK: - Private Keychain helpers

    /// Resolves a config-file key value to the real API key:
    /// - placeholder → load from Keychain
    /// - real value  → save to Keychain, set hadPlaintext flag (so JSON gets flushed)
    /// - nil/empty   → nil
    private static func resolveAPIKey(_ value: String?,
                                      account: String,
                                      hadPlaintext: inout Bool) -> String? {
        guard let v = value, !v.isEmpty else { return nil }
        if v == KeychainAccount.placeholder {
            return KeychainHelper.load(account: account)
        }
        // Plaintext key found in JSON: migrate it to the Keychain.
        KeychainHelper.save(account: account, value: v)
        hadPlaintext = true
        return v  // Return the real value for this session; save() will write placeholder.
    }

    /// Persists a key to the Keychain and returns the placeholder to embed in JSON.
    /// Returns nil (and deletes from Keychain) when the value is nil or empty.
    private func storeAPIKey(_ value: String?, account: String) -> String? {
        guard let v = value, !v.isEmpty else {
            KeychainHelper.delete(account: account)
            return nil
        }
        if v == KeychainAccount.placeholder { return KeychainAccount.placeholder }
        KeychainHelper.save(account: account, value: v)
        return KeychainAccount.placeholder
    }
}
