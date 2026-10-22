import Foundation

/// A constructed example: one sprint for three junior iOS engineers, plus one
/// tutor-mode exchange about a Swift concurrency bug. The names, tickets,
/// ledger and replies are hand-written for illustration. They are not
/// recordings of a real team or a real model.
public enum SampleScenario {
    public static let ledger = SkillLedger([
        "Asha": [.concurrency: 0, .ui: 4, .testing: 2, .architecture: 1],
        "Ben": [.architecture: 0, .concurrency: 3, .performance: 1, .ui: 2],
        "Chen": [.concurrency: 1, .testing: 1, .ui: 3, .performance: 2]
    ])

    private static let designOnly = OwnershipEvidence(designNoteByAssignee: true, testsWrittenFirst: false)
    private static let testsOnly = OwnershipEvidence(designNoteByAssignee: false, testsWrittenFirst: true)

    public static let tickets: [Ticket] = [
        Ticket(id: "A1", title: "Empty state for Saved", skill: .ui, assignee: "Asha", evidence: .full),
        Ticket(id: "A2", title: "Cancel search on new keystroke", skill: .concurrency, assignee: "Asha", evidence: .none),
        Ticket(id: "A3", title: "Snapshot tests for Settings", skill: .testing, assignee: "Asha", evidence: designOnly),
        Ticket(id: "A4", title: "Dynamic Type on Profile", skill: .ui, assignee: "Asha", evidence: .full),
        Ticket(id: "B1", title: "Trim launch work", skill: .performance, assignee: "Ben", evidence: .full),
        Ticket(id: "B2", title: "Onboarding carousel", skill: .ui, assignee: "Ben", evidence: .none),
        Ticket(id: "B3", title: "Split Feed into a package", skill: .architecture, assignee: "Ben", evidence: .full),
        Ticket(id: "B4", title: "Retry for uploads", skill: .concurrency, assignee: "Ben", evidence: testsOnly),
        Ticket(id: "C1", title: "Badge on Inbox tab", skill: .ui, assignee: "Chen", evidence: .full),
        Ticket(id: "C2", title: "Contract tests for /orders", skill: .testing, assignee: "Chen", evidence: .full),
        Ticket(id: "C3", title: "Duplicate image downloads", skill: .concurrency, assignee: "Chen", evidence: .none),
        Ticket(id: "C4", title: "Scroll hitch in Gallery", skill: .performance, assignee: "Chen", evidence: designOnly)
    ]

    public static let plan = ApprenticeshipPlan(windowSize: 4)

    public static var gate: DelegationGate {
        DelegationGate(agentOffTickets: plan.agentOffTickets(for: tickets, ledger: ledger).ids)
    }

    public static var decisions: [(ticket: Ticket, delegation: Delegation)] {
        let gate = gate
        return tickets.map { ($0, gate.decide($0)) }
    }

    // MARK: - Tutor exchange for ticket C3

    /// Chen's code. Two views request the same avatar at once and it downloads twice.
    public static let actorSource = """
    actor ImageCache {
        private var images: [URL: Data] = [:]

        func image(for url: URL) async throws -> Data {
            if let cached = images[url] { return cached }
            let (data, _) = try await URLSession.shared.data(from: url)
            images[url] = data
            return data
        }
    }
    """

    public static let actorQuestion = "This is an actor, so I thought only one call could run at a time. Why do I still see two downloads for the same URL?"

    public static var actorSourceLineCount: Int {
        actorSource.components(separatedBy: "\n").count
    }

    /// A reply that teaches: it names the line, the false assumption, and hands the next step back.
    public static let tutorReply = """
    Look at line 6. You're assuming the actor holds the whole function, start to finish.
    It doesn't. At the await on line 6 the actor suspends, and while the first download is in flight a second call for the same URL can run line 5, find nothing in the cache, and start its own download.
    So the bug isn't the data race you were guarding against. It's a check, then a suspension, then an act.
    Before you change anything: what would the second caller need to find on line 5 so that it waits for the first download instead of starting another?
    """

    /// A reply that solves it: correct, and it leaves Chen with nothing to defend in review.
    public static let fixDumpReply = """
    This is actor reentrancy. Here's the fix: store the in-flight task.
    ```swift
    actor ImageCache {
        private var tasks: [URL: Task<Data, Error>] = [:]

        func image(for url: URL) async throws -> Data {
            if let task = tasks[url] { return try await task.value }
            let task = Task { try await URLSession.shared.data(from: url).0 }
            tasks[url] = task
            return try await task.value
        }
    }
    ```
    That should resolve the duplicate downloads.
    """
}
