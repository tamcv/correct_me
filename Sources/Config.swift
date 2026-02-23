import Foundation
import CoreGraphics

// Keychain account names and the JSON placeholder for stored keys.
private enum KeychainAccount {
    static let anthropic  = "anthropic_api_key"
    static let gemini     = "gemini_api_key"
    static let openai     = "openai_api_key"
    /// Value written to config.json when the real key lives in the Keychain.
    static let placeholder = "keychain"
}

struct Config: Codable {
    var aiProvider: AIProvider
    var anthropicAPIKey: String?
    var geminiAPIKey: String?
    var openaiAPIKey: String?
    var hotkey: HotkeyConfig
    var customPrompt: String?
    var model: String?
    var writingStyle: String?

    enum AIProvider: String, Codable {
        case claude = "claude"
        case gemini = "gemini"
        case claudeCode = "claude-code"
        case codex = "codex"
        case codexCode = "codex-code"
        case copilot = "copilot"
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
            hotkey: .default,
            customPrompt: nil,
            model: nil,
            writingStyle: nil
        )
    }

    enum DefaultModels {
        static let claudeCode = "claude-haiku-4-5"
        static let anthropic = "claude-haiku-4-5-20251001"
        static let gemini = "gemini-2.0-flash"
        static let openaiCodex = "gpt-5.1-codex-mini"
        static let copilot = "gpt-5-mini"
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
