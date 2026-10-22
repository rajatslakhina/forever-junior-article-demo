import Foundation

public enum Skill: String, CaseIterable, Sendable, Codable, Comparable {
    case concurrency, architecture, testing, ui, performance

    public static func < (lhs: Skill, rhs: Skill) -> Bool {
        (allCases.firstIndex(of: lhs) ?? 0) < (allCases.firstIndex(of: rhs) ?? 0)
    }
}

/// Evidence that the assignee did the thinking before the agent did the typing.
public struct OwnershipEvidence: Equatable, Sendable, Codable {
    /// A short design note written by the assignee, not generated for them.
    public var designNoteByAssignee: Bool
    /// Failing tests, written by the assignee, that define "done".
    public var testsWrittenFirst: Bool

    public init(designNoteByAssignee: Bool, testsWrittenFirst: Bool) {
        self.designNoteByAssignee = designNoteByAssignee
        self.testsWrittenFirst = testsWrittenFirst
    }

    public static let none = OwnershipEvidence(designNoteByAssignee: false, testsWrittenFirst: false)
    public static let full = OwnershipEvidence(designNoteByAssignee: true, testsWrittenFirst: true)
}

public struct Ticket: Identifiable, Equatable, Sendable, Codable {
    public var id: String
    public var title: String
    public var skill: Skill
    public var assignee: String
    public var evidence: OwnershipEvidence

    public init(id: String, title: String, skill: Skill, assignee: String, evidence: OwnershipEvidence) {
        self.id = id
        self.title = title
        self.skill = skill
        self.assignee = assignee
        self.evidence = evidence
    }
}

/// What the agent is allowed to do on a ticket.
public enum Delegation: Equatable, Sendable {
    /// The agent may write the code. The assignee has already designed it and
    /// written the tests that define done.
    case agentWrites
    /// The agent may tutor (any `TutorMode`) but not write the change, because
    /// the ownership evidence is missing.
    case tutorOnly(missing: [Missing])
    /// This ticket is the assignee's unassisted rep for a skill they are short on.
    case agentOff(skill: Skill)

    public enum Missing: String, Equatable, Sendable {
        case designNote = "design note"
        case testsFirst = "tests first"
    }

    public var label: String {
        switch self {
        case .agentWrites: return "Agent writes"
        case .tutorOnly: return "Tutor only"
        case .agentOff: return "Agent off"
        }
    }
}

/// Decides, per ticket, how much of the work an agent may take.
///
/// The rule order is the policy: the apprenticeship rotation comes first, so a
/// junior can't skip their unassisted rep by writing a design note quickly.
public struct DelegationGate: Sendable {
    public var agentOffTickets: Set<String>

    public init(agentOffTickets: Set<String>) {
        self.agentOffTickets = agentOffTickets
    }

    public func decide(_ ticket: Ticket) -> Delegation {
        if agentOffTickets.contains(ticket.id) {
            return .agentOff(skill: ticket.skill)
        }
        var missing: [Delegation.Missing] = []
        if !ticket.evidence.designNoteByAssignee { missing.append(.designNote) }
        if !ticket.evidence.testsWrittenFirst { missing.append(.testsFirst) }
        return missing.isEmpty ? .agentWrites : .tutorOnly(missing: missing)
    }
}

/// How many unassisted reps each engineer has in each skill.
public struct SkillLedger: Equatable, Sendable {
    private var reps: [String: [Skill: Int]]

    public init(_ reps: [String: [Skill: Int]] = [:]) {
        self.reps = reps
    }

    public func reps(_ engineer: String, _ skill: Skill) -> Int {
        reps[engineer]?[skill] ?? 0
    }

    public mutating func record(_ engineer: String, _ skill: Skill) {
        reps[engineer, default: [:]][skill, default: 0] += 1
    }
}

/// Chooses which tickets are worked with the agent off.
///
/// For each engineer, tickets are taken in order in windows of `windowSize`
/// (the last window may be shorter). In each window, the ticket whose skill
/// has the fewest unassisted reps in the ledger becomes the agent-off ticket;
/// ties go to the earlier ticket. The ledger is updated as reps are planned,
/// so the next window favours a different gap.
public struct ApprenticeshipPlan: Sendable {
    public var windowSize: Int

    public init(windowSize: Int = 4) {
        self.windowSize = max(1, windowSize)
    }

    public func agentOffTickets(for tickets: [Ticket], ledger: SkillLedger) -> (ids: Set<String>, ledger: SkillLedger) {
        var ledger = ledger
        var chosen: Set<String> = []
        var engineers: [String] = []
        for ticket in tickets where !engineers.contains(ticket.assignee) {
            engineers.append(ticket.assignee)
        }
        for engineer in engineers {
            let mine = tickets.filter { $0.assignee == engineer }
            var start = 0
            while start < mine.count {
                let end = min(start + windowSize, mine.count)
                let window = mine[start..<end]
                var pick: Ticket?
                for ticket in window {
                    guard let current = pick else { pick = ticket; continue }
                    if ledger.reps(engineer, ticket.skill) < ledger.reps(engineer, current.skill) {
                        pick = ticket
                    }
                }
                if let pick {
                    chosen.insert(pick.id)
                    ledger.record(engineer, pick.skill)
                }
                start = end
            }
        }
        return (chosen, ledger)
    }
}

/// Counts per decision kind, for a sprint's worth of tickets.
public struct SprintSummary: Equatable, Sendable {
    public var agentWrites = 0
    public var tutorOnly = 0
    public var agentOff = 0

    public init(_ decisions: [Delegation]) {
        for decision in decisions {
            switch decision {
            case .agentWrites: agentWrites += 1
            case .tutorOnly: tutorOnly += 1
            case .agentOff: agentOff += 1
            }
        }
    }

    public var total: Int { agentWrites + tutorOnly + agentOff }
}
