import XCTest
@testable import CorrectMe

final class AIProvidersTests: XCTestCase {
    func testBuildCorrectionPromptContainsInputText() {
        let input = "Ths is a tst sentense."
        let prompt = buildCorrectionPrompt(text: input)
        XCTAssertTrue(prompt.contains(input), "Prompt must contain the original text")
    }

    func testBuildCorrectionPromptWithoutStyleContainsLanguageInstruction() {
        let prompt = buildCorrectionPrompt(text: "sample")
        XCTAssertTrue(
            prompt.contains("original language") || prompt.contains("Detect the language"),
            "Basic prompt should include language preservation instruction"
        )
    }

    func testBuildCorrectionPromptWithContextPrefixesIt() {
        let context = "IMPORTANT: no file access.\n\n"
        let prompt = buildCorrectionPrompt(text: "hello", context: context)
        XCTAssertTrue(
            prompt.hasPrefix(context),
            "Prompt should start with the provided context"
        )
    }

    func testBuildCorrectionPromptPreservesVietnameseKeyword() {
        let prompt = buildCorrectionPrompt(text: "xin chào")
        XCTAssertTrue(
            prompt.contains("Vietnamese") || prompt.contains("tiếng Việt"),
            "Prompt should mention Vietnamese language support"
        )
    }

    func testBuildCorrectionPromptReturnOnlyInstruction() {
        let prompt = buildCorrectionPrompt(text: "test")
        // Verify the no-markdown constraint is present
        XCTAssertTrue(
            prompt.contains("no explanations") || prompt.contains("no markdown") || prompt.contains("ONLY"),
            "Prompt must instruct model to return only the corrected text"
        )
    }
}
