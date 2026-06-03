import Foundation

// MARK: - Text Actions

/// Fixed AI actions always shown in the Quick Action Picker.
/// (Make formal / casual / expand are now user-configurable custom actions.)
enum TextAction: String, CaseIterable {
    case correct   = "correct"
    case translate = "translate"
    case summarize = "summarize"

    var title: String {
        switch self {
        case .correct:   return "Correct grammar"
        case .translate: return "Translate"
        case .summarize: return "Summarize"
        }
    }

    var icon: String {
        switch self {
        case .correct:   return "✏️"
        case .translate: return "🌐"
        case .summarize: return "✂️"
        }
    }

    var shortcutKey: String {
        switch self {
        case .correct:   return "1"
        case .translate: return "2"
        case .summarize: return "3"
        }
    }

    /// Build the full prompt to send to the AI provider for this action.
    func buildPrompt(for text: String) -> String {
        switch self {
        case .correct:
            // Use global writing style only. Per-app style is exposed as a
            // separate "Correct · AppName" action in the Quick Action Picker.
            let globalStyle = Config.load().writingStyle ?? ""
            return buildCorrectionPrompt(text: text, writingStyleOverride: globalStyle)

        case .translate:
            let cfg = Config.load()
            let target = cfg.translateTargetLanguage ?? Config.TranslateLanguage.auto.rawValue
            if target == Config.TranslateLanguage.auto.rawValue {
                return """
                Detect the source language of the following text.
                - If it is English, translate it to Vietnamese.
                - Otherwise, translate it to English.
                Return ONLY the translated text — no explanations, no quotes, no markdown.

                Text:
                \(text)
                """
            } else {
                return """
                Translate the following text to \(target).
                Return ONLY the translated text — no explanations, no quotes, no markdown.

                Text:
                \(text)
                """
            }

        case .summarize:
            return """
            LANGUAGE: Respond in the EXACT same language as the input text. DO NOT translate.

            Summarize the text below concisely, capturing only the key points.
            Return ONLY the summary — no explanations, no quotes, no markdown.

            Text:
            \(text)
            """
        }
    }
}
