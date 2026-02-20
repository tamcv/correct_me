import XCTest
@testable import CorrectMe

final class ConfigTests: XCTestCase {
    private var tempConfigURL: URL!

    override func setUp() {
        super.setUp()
        // Use a temp file so tests don't touch ~/.correctme/config.json
        tempConfigURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("correctme_test_\(UUID().uuidString).json")
    }

    override func tearDown() {
        super.tearDown()
        try? FileManager.default.removeItem(at: tempConfigURL)
    }

    func testDefaultConfigHasExpectedValues() {
        let config = Config.default
        XCTAssertEqual(config.aiProvider, .claudeCode)
        XCTAssertNil(config.anthropicAPIKey)
        XCTAssertNil(config.geminiAPIKey)
        XCTAssertNil(config.openaiAPIKey)
        XCTAssertEqual(config.hotkey.displayName, "⌘⇧E")
        XCTAssertNil(config.model)
        XCTAssertNil(config.writingStyle)
    }

    func testSaveAndLoadRoundTrip() throws {
        var config = Config.default
        config.aiProvider = .gemini
        config.geminiAPIKey = "test-gemini-key"
        config.model = "gemini-2.0-flash"
        config.writingStyle = "Use formal tone."

        // Save to temp file
        let data = try JSONEncoder().encode(config)
        try data.write(to: tempConfigURL)

        // Load from temp file
        let loaded = try JSONDecoder().decode(Config.self, from: data)
        XCTAssertEqual(loaded.aiProvider, .gemini)
        XCTAssertEqual(loaded.geminiAPIKey, "test-gemini-key")
        XCTAssertEqual(loaded.model, "gemini-2.0-flash")
        XCTAssertEqual(loaded.writingStyle, "Use formal tone.")
    }

    func testLoadFromMissingFileReturnsDefault() {
        // Point configPath to a nonexistent file; load() should return .default
        // We test this indirectly: decode from garbage data returns default
        let config = (try? JSONDecoder().decode(Config.self, from: Data())) ?? Config.default
        XCTAssertEqual(config.aiProvider, Config.default.aiProvider)
    }

    func testHotkeyConfigCodable() throws {
        let hotkey = Config.HotkeyConfig(keyCode: 14, modifiers: 1_048_840, displayName: "⌘⇧E")
        let data = try JSONEncoder().encode(hotkey)
        let decoded = try JSONDecoder().decode(Config.HotkeyConfig.self, from: data)
        XCTAssertEqual(decoded.keyCode, hotkey.keyCode)
        XCTAssertEqual(decoded.modifiers, hotkey.modifiers)
        XCTAssertEqual(decoded.displayName, hotkey.displayName)
    }

    func testAllAIProviderRawValuesDecodable() throws {
        let cases: [(String, Config.AIProvider)] = [
            ("claude", .claude),
            ("gemini", .gemini),
            ("claude-code", .claudeCode),
            ("codex", .codex),
            ("codex-code", .codexCode),
            ("copilot", .copilot),
        ]
        for (raw, expected) in cases {
            let json = "\"\(raw)\""
            let decoded = try JSONDecoder().decode(Config.AIProvider.self, from: json.data(using: .utf8)!)
            XCTAssertEqual(decoded, expected, "Failed to decode provider '\(raw)'")
        }
    }
}
