import Foundation
import CoreGraphics

struct Config: Codable {
    var aiProvider: AIProvider
    var anthropicAPIKey: String?
    var geminiAPIKey: String?
    var openaiAPIKey: String?
    var hotkey: HotkeyConfig
    var customPrompt: String?
    var model: String?
    
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
            model: nil
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
    
    static func load() -> Config {
        guard FileManager.default.fileExists(atPath: configPath.path),
              let data = try? Data(contentsOf: configPath),
              let config = try? JSONDecoder().decode(Config.self, from: data) else {
            return .default
        }
        return config
    }
    
    func save() throws {
        let dir = Config.configPath.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(self)
        try data.write(to: Config.configPath)
    }
}
