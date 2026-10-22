import XCTest
@testable import ApprenticeLoop

final class TutorContractTests: XCTestCase {
    func testTeachingReplyPassesPointAtLine() {
        let violations = TutorMode.pointAtLine.contract.check(
            reply: SampleScenario.tutorReply,
            sourceLineCount: SampleScenario.actorSourceLineCount)
        XCTAssertEqual(violations, [])
    }

    func testFixDumpFailsPointAtLineThreeWays() {
        let violations = TutorMode.pointAtLine.contract.check(
            reply: SampleScenario.fixDumpReply,
            sourceLineCount: SampleScenario.actorSourceLineCount)
        XCTAssertEqual(violations, [
            .tooMuchCode(found: 9, allowed: 2),
            .noQuestionForLearner,
            .noLineCitation
        ])
    }

    func testTeachingReplyCitesTheSuspensionPoint() {
        let cited = ReplyAnalysis.citedLines(in: SampleScenario.tutorReply)
        XCTAssertEqual(cited, [6, 6, 5, 5])
        let lines = SampleScenario.actorSource.components(separatedBy: "\n")
        XCTAssertTrue(lines.indices.contains(5))
        XCTAssertTrue(lines[5].contains("try await"))
    }

    func testCitationOutOfRangeIsFlagged() {
        let reply = "Check line 42. What did you expect it to return?"
        let violations = TutorMode.pointAtLine.contract.check(reply: reply, sourceLineCount: 10)
        XCTAssertEqual(violations, [.citedLineOutOfRange(line: 42, sourceLines: 10)])
    }

    func testQuizFirstAllowsNoCodeAtAll() {
        let reply = "What does the actor guarantee?\n```swift\nlet x = 1\n```"
        let violations = TutorMode.quizFirst.contract.check(reply: reply, sourceLineCount: 10)
        XCTAssertEqual(violations, [.tooMuchCode(found: 1, allowed: 0)])
    }

    func testQuestionMarkInsideCodeDoesNotCount() {
        let reply = "```swift\nlet name = user?.name\n```"
        XCTAssertFalse(ReplyAnalysis.asksQuestion(reply))
    }

    func testEmptyReplyFailsEverythingItCan() {
        let violations = TutorMode.pointAtLine.contract.check(reply: "", sourceLineCount: 10)
        XCTAssertEqual(violations, [.noQuestionForLearner, .noLineCitation])
    }

    func testNegativeMaxCodeLinesIsClampedToZero() {
        XCTAssertEqual(TutorContract(maxCodeLines: -3, mustAskQuestion: false, mustCiteLine: false).maxCodeLines, 0)
    }

    func testNumberedSourceMatchesLineCount() {
        let numbered = TutorPrompt.numbered(SampleScenario.actorSource)
        XCTAssertEqual(numbered.components(separatedBy: "\n").count, SampleScenario.actorSourceLineCount)
        XCTAssertTrue(numbered.components(separatedBy: "\n")[5].hasPrefix(" 6| "))
    }

    func testEveryModeHasAnInstructionAndAsksAQuestion() {
        for mode in TutorMode.allCases {
            XCTAssertFalse(mode.instruction.isEmpty)
            XCTAssertTrue(mode.contract.mustAskQuestion)
        }
    }
}

final class DelegationGateTests: XCTestCase {
    func testSampleSprintMatchesTheArticle() {
        let summary = SprintSummary(SampleScenario.decisions.map(\.delegation))
        XCTAssertEqual(summary.agentWrites, 4)
        XCTAssertEqual(summary.tutorOnly, 5)
        XCTAssertEqual(summary.agentOff, 3)
        XCTAssertEqual(summary.total, 12)
    }

    func testRotationPicksEachJuniorsWeakestSkill() {
        let ids = SampleScenario.plan.agentOffTickets(for: SampleScenario.tickets, ledger: SampleScenario.ledger).ids
        XCTAssertEqual(ids, ["A2", "B3", "C2"])
    }

    func testRotationOverridesFullEvidence() {
        // B3 has a design note and tests, but architecture is Ben's zero-rep skill.
        let b3 = SampleScenario.tickets.first { $0.id == "B3" }
        XCTAssertEqual(b3?.evidence, .full)
        if let b3 { XCTAssertEqual(SampleScenario.gate.decide(b3), .agentOff(skill: .architecture)) }
    }

    func testTiesGoToTheEarlierTicket() {
        // Chen has 1 rep in both testing (C2) and concurrency (C3): C2 comes first.
        let c3 = SampleScenario.tickets.first { $0.id == "C3" }
        if let c3 { XCTAssertEqual(SampleScenario.gate.decide(c3), .tutorOnly(missing: [.designNote, .testsFirst])) }
    }

    func testMissingEvidenceIsListedInOrder() {
        let ticket = Ticket(id: "X", title: "x", skill: .ui, assignee: "Z", evidence: .none)
        XCTAssertEqual(DelegationGate(agentOffTickets: []).decide(ticket), .tutorOnly(missing: [.designNote, .testsFirst]))
    }

    func testLedgerUpdatesSoSecondWindowPicksADifferentSkill() {
        let tickets = (1...8).map { i in
            Ticket(id: "T\(i)", title: "t", skill: i % 2 == 0 ? .testing : .ui, assignee: "Z", evidence: .full)
        }
        let result = ApprenticeshipPlan(windowSize: 4).agentOffTickets(for: tickets, ledger: SkillLedger())
        XCTAssertEqual(result.ids, ["T1", "T6"])
        XCTAssertEqual(result.ledger.reps("Z", .ui), 1)
        XCTAssertEqual(result.ledger.reps("Z", .testing), 1)
    }

    func testShortLastWindowAndEmptyInput() {
        let tickets = (1...5).map { Ticket(id: "T\($0)", title: "t", skill: .ui, assignee: "Z", evidence: .full) }
        XCTAssertEqual(ApprenticeshipPlan(windowSize: 4).agentOffTickets(for: tickets, ledger: SkillLedger()).ids, ["T1", "T5"])
        XCTAssertEqual(ApprenticeshipPlan().agentOffTickets(for: [], ledger: SkillLedger()).ids, [])
        XCTAssertEqual(ApprenticeshipPlan(windowSize: 0).windowSize, 1)
    }
}
