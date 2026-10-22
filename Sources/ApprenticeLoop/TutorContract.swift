import Foundation

/// A deterministic check on a model's tutor-mode reply.
///
/// The check is deliberately dumb: it counts lines that look like code, looks
/// for a question addressed to the learner, and looks for a "line N" citation.
/// A dumb check that runs on every reply beats a clever instruction that the
/// model is free to ignore.
public struct TutorContract: Equatable, Sendable, Codable {
    /// Maximum number of code-looking lines the reply may contain.
    public var maxCodeLines: Int
    /// The reply must hand the thinking back with at least one question.
    public var mustAskQuestion: Bool
    /// The reply must cite a specific line ("line 5") that exists in the source.
    public var mustCiteLine: Bool

    public init(maxCodeLines: Int, mustAskQuestion: Bool, mustCiteLine: Bool) {
        self.maxCodeLines = max(0, maxCodeLines)
        self.mustAskQuestion = mustAskQuestion
        self.mustCiteLine = mustCiteLine
    }

    public enum Violation: Equatable, Sendable, CustomStringConvertible {
        case tooMuchCode(found: Int, allowed: Int)
        case noQuestionForLearner
        case noLineCitation
        case citedLineOutOfRange(line: Int, sourceLines: Int)

        public var description: String {
            switch self {
            case let .tooMuchCode(found, allowed): return "Wrote \(found) lines of code (allowed \(allowed))"
            case .noQuestionForLearner: return "Never handed the thinking back with a question"
            case .noLineCitation: return "Didn't point at a line"
            case let .citedLineOutOfRange(line, count): return "Cited line \(line), source has \(count)"
            }
        }
    }

    /// Returns every way `reply` breaks the contract. Empty means it passed.
    /// `sourceLineCount` is the number of lines in the code the learner sent.
    public func check(reply: String, sourceLineCount: Int) -> [Violation] {
        var violations: [Violation] = []
        let code = ReplyAnalysis.codeLineCount(in: reply)
        if code > maxCodeLines {
            violations.append(.tooMuchCode(found: code, allowed: maxCodeLines))
        }
        if mustAskQuestion && !ReplyAnalysis.asksQuestion(reply) {
            violations.append(.noQuestionForLearner)
        }
        if mustCiteLine {
            let cited = ReplyAnalysis.citedLines(in: reply)
            if cited.isEmpty {
                violations.append(.noLineCitation)
            } else if let bad = cited.first(where: { $0 < 1 || $0 > sourceLineCount }) {
                violations.append(.citedLineOutOfRange(line: bad, sourceLines: sourceLineCount))
            }
        }
        return violations
    }
}

/// The text heuristics behind `TutorContract`. Public so they can be tested
/// and reused, e.g. in a CI job that replays recorded tutor sessions.
public enum ReplyAnalysis {
    /// Lines inside ``` fences, plus unfenced lines that look like Swift.
    public static func codeLineCount(in reply: String) -> Int {
        var inFence = false
        var count = 0
        for raw in reply.components(separatedBy: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("```") { inFence.toggle(); continue }
            if line.isEmpty { continue }
            if inFence || looksLikeSwift(line) { count += 1 }
        }
        return count
    }

    /// A conservative "this is a statement, not a sentence" test.
    public static func looksLikeSwift(_ line: String) -> Bool {
        let starts = ["func ", "let ", "var ", "if let ", "guard ", "return ", "await ", "try ", "actor ", "class ", "struct ", "private ", "}", "case "]
        if starts.contains(where: { line.hasPrefix($0) }) { return true }
        if line.hasSuffix("{") || line.hasSuffix("}") { return true }
        return false
    }

    /// True if any sentence outside code fences ends with a question mark.
    public static func asksQuestion(_ reply: String) -> Bool {
        var inFence = false
        for raw in reply.components(separatedBy: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("```") { inFence.toggle(); continue }
            if !inFence && line.contains("?") && !looksLikeSwift(line) { return true }
        }
        return false
    }

    /// Every number N in phrases like "line 5" or "Line 12" (case-insensitive).
    public static func citedLines(in reply: String) -> [Int] {
        let lower = reply.lowercased()
        var result: [Int] = []
        var searchStart = lower.startIndex
        while let range = lower.range(of: "line ", range: searchStart..<lower.endIndex) {
            var digits = ""
            var index = range.upperBound
            while index < lower.endIndex, let d = lower[index].wholeNumberValue {
                digits.append(String(d))
                index = lower.index(after: index)
            }
            if let n = Int(digits) { result.append(n) }
            searchStart = range.upperBound
        }
        return result
    }
}
