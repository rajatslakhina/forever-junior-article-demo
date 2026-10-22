import Foundation

/// Four ways to prompt a model so that it builds a junior engineer's skill
/// instead of replacing it. Each mode pairs the instruction you send with a
/// `TutorContract` that is checked in code against the reply you get back,
/// because "please don't just give me the answer" is a request, not a guarantee.
public enum TutorMode: String, CaseIterable, Sendable, Codable {
    /// "Explain this diff as if I must defend it in review."
    case defendTheDiff
    /// "Quiz me before you show the fix."
    case quizFirst
    /// "Show two designs and make me pick, then critique my pick."
    case twoDesigns
    /// "Don't write code. Point at the line where my reasoning breaks."
    case pointAtLine

    public var title: String {
        switch self {
        case .defendTheDiff: return "Defend the diff"
        case .quizFirst: return "Quiz me first"
        case .twoDesigns: return "Two designs, I pick"
        case .pointAtLine: return "Point at the line"
        }
    }

    /// The instruction placed in the system prompt for this mode.
    public var instruction: String {
        switch self {
        case .defendTheDiff:
            return "Explain the reasoning behind this diff the way a reviewer will challenge it. Do not rewrite it. End with the two questions I am most likely to be asked in review."
        case .quizFirst:
            return "Do not show a fix. Ask me one question at a time that leads me to the cause. Wait for my answer before the next question."
        case .twoDesigns:
            return "Sketch two different designs in prose, with at most a few lines of code each. Ask me to pick one and say why. Critique my pick only after I answer."
        case .pointAtLine:
            return "Do not write code. Name the single line number where my reasoning breaks, say what I assumed there that is false, and ask me what happens next."
        }
    }

    /// What a reply in this mode must satisfy.
    public var contract: TutorContract {
        switch self {
        case .defendTheDiff: return TutorContract(maxCodeLines: 4, mustAskQuestion: true, mustCiteLine: false)
        case .quizFirst: return TutorContract(maxCodeLines: 0, mustAskQuestion: true, mustCiteLine: false)
        case .twoDesigns: return TutorContract(maxCodeLines: 12, mustAskQuestion: true, mustCiteLine: false)
        case .pointAtLine: return TutorContract(maxCodeLines: 2, mustAskQuestion: true, mustCiteLine: true)
        }
    }
}

/// Builds the full prompt for a tutor-mode request. Source lines are numbered
/// so that a line citation in the reply can be checked against real lines.
public enum TutorPrompt {
    public static func system(for mode: TutorMode) -> String {
        """
        You are tutoring a junior iOS engineer who will own this code after you leave the conversation.
        Your goal is that they can explain and defend the fix themselves.
        \(mode.instruction)
        """
    }

    public static func user(source: String, question: String) -> String {
        "\(numbered(source))\n\n\(question)"
    }

    /// Prefixes each line with its 1-based number, e.g. `  5| let x = 1`.
    public static func numbered(_ source: String) -> String {
        let lines = source.components(separatedBy: "\n")
        let width = String(lines.count).count
        return lines.enumerated().map { index, line in
            let n = String(index + 1)
            return String(repeating: " ", count: max(0, width - n.count)) + n + "| " + line
        }.joined(separator: "\n")
    }
}
