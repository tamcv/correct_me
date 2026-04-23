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

        case .formal:
            return """
            LANGUAGE RULE (highest priority): Detect the language(s) of the input text. \
            Your output MUST use the EXACT same language(s). \
            If the input is Vietnamese, output Vietnamese. \
            If the input is English, output English. \
            If the input mixes languages, keep that exact mix. \
            NEVER translate any word into a different language.

            Task: Rewrite the text below in a formal, professional tone while keeping its original language(s).
            - Fix spelling and grammar errors.
            - Return ONLY the rewritten text — no explanations, no quotes, no markdown.

            Text:
            \(text)
            """

        case .casual:
            return """
            LANGUAGE RULE (highest priority): Detect the language(s) of the input text. \
            Your output MUST use the EXACT same language(s). \
            If the input is Vietnamese, output Vietnamese. \
            If the input is English, output English. \
            If the input mixes languages, keep that exact mix. \
            NEVER translate any word into a different language.

            Task: Rewrite the text below in a casual, friendly, conversational tone while keeping its original language(s).
            - Fix spelling and grammar errors.
            - Return ONLY the rewritten text — no explanations, no quotes, no markdown.

            Text:
            \(text)
            """

        case .summarize:
            return """
            LANGUAGE RULE (highest priority): Detect the language(s) of the input text. \
            Your output MUST use the EXACT same language(s). \
            If the input is Vietnamese, output Vietnamese. \
            If the input is English, output English. \
            NEVER translate any word into a different language.

            Task: Summarize the text below concisely, capturing only the key points, in the same language(s) as the original.
            - Return ONLY the summary — no explanations, no quotes, no markdown.

            Text:
            \(text)
            """

        case .expand:
            return """
            LANGUAGE RULE (highest priority): Detect the language(s) of the input text. \
            Your output MUST use the EXACT same language(s). \
            If the input is Vietnamese, output Vietnamese. \
            If the input is English, output English. \
            If the input mixes languages, keep that exact mix. \
            NEVER translate any word into a different language.

            Task: Expand and elaborate on the text below with more detail and context, in the same language(s) as the original.
            - Keep the same tone and style.
            - Return ONLY the expanded text — no explanations, no quotes, no markdown.

            Text:
            \(text)
            """
        }
    }
}
