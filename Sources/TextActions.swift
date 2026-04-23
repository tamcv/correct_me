import Foundation

// MARK: - Text Actions

/// All AI actions available in the Quick Action Picker.
enum TextAction: String, CaseIterable {
    case correct   = "correct"
    case translate = "translate"
    case formal    = "formal"
    case casual    = "casual"
    case summarize = "summarize"
    case expand    = "expand"

    var title: String {
        switch self {
        case .correct:   return "Correct grammar"
        case .translate: return "Translate"
        case .formal:    return "Make formal"
        case .casual:    return "Make casual"
        case .summarize: return "Summarize"
        case .expand:    return "Expand"
        }
    }

    var icon: String {
        switch self {
        case .correct:   return "✏️"
        case .translate: return "🌐"
        case .formal:    return "📝"
        case .casual:    return "💬"
        case .summarize: return "✂️"
        case .expand:    return "➕"
        }
    }

    var shortcutKey: String {
        switch self {
        case .correct:   return "1"
        case .translate: return "2"
        case .formal:    return "3"
        case .casual:    return "4"
        case .summarize: return "5"
        case .expand:    return "6"
        }
    }

    /// Build the full prompt to send to the AI provider for this action.
    func buildPrompt(for text: String) -> String {
        switch self {
        case .correct:
            return buildCorrectionPrompt(text: text)

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

        case .formal:
            return """
            Rewrite the following text in a formal, professional tone.
            Rules:
            - DO NOT translate. Keep every word in its original language.
            - If the text mixes languages, keep that exact mix.
            - Fix any spelling or grammar errors while rewriting.
            - Return ONLY the rewritten text — no explanations, no quotes, no markdown.

            Text:
            \(text)
            """

        case .casual:
            return """
            Rewrite the following text in a casual, friendly, conversational tone.
            Rules:
            - DO NOT translate. Keep every word in its original language.
            - If the text mixes languages, keep that exact mix.
            - Fix any spelling or grammar errors while rewriting.
            - Return ONLY the rewritten text — no explanations, no quotes, no markdown.

            Text:
            \(text)
            """

        case .summarize:
            return """
            Summarize the following text concisely, capturing only the key points.
            Rules:
            - DO NOT translate. Write the summary in the same language(s) as the original.
            - Return ONLY the summary — no explanations, no quotes, no markdown.

            Text:
            \(text)
            """

        case .expand:
            return """
            Expand and elaborate on the following text with more detail and context.
            Rules:
            - DO NOT translate. Write the expansion in the same language(s) as the original.
            - Keep the same tone and style as the original.
            - Return ONLY the expanded text — no explanations, no quotes, no markdown.

            Text:
            \(text)
            """
        }
    }
}
