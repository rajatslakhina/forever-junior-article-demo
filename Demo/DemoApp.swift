import SwiftUI
import ApprenticeLoop

@main
struct DemoApp: App {
    var body: some Scene {
        WindowGroup {
            RootView(screen: UserDefaults.standard.string(forKey: "screen") == "tutor" ? .tutor : .sprint)
        }
    }
}

enum Screen: String, CaseIterable, Identifiable {
    case sprint = "Sprint gate"
    case tutor = "Tutor contract"
    var id: String { rawValue }
}

struct RootView: View {
    @State var screen: Screen

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Screen", selection: $screen) {
                        ForEach(Screen.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                switch screen {
                case .sprint: SprintSections()
                case .tutor: TutorSections()
                }
                Section {
                    EmptyView()
                } footer: {
                    Text("Constructed example: hand-written tickets, skill ledger and model replies. Not a real team or a recorded model session.")
                }
            }
            .navigationTitle("Apprentice loop")
        }
    }
}

// MARK: - Sprint gate

struct SprintSections: View {
    private let decisions = SampleScenario.decisions
    private var summary: SprintSummary { SprintSummary(decisions.map(\.delegation)) }

    var body: some View {
        Section("One sprint, three juniors, \(summary.total) tickets") {
            HStack(spacing: 10) {
                Tile(value: summary.agentWrites, label: "Agent writes", color: .blue)
                Tile(value: summary.tutorOnly, label: "Tutor only", color: .orange)
                Tile(value: summary.agentOff, label: "Agent off", color: .green)
            }
            .padding(.vertical, 4)
            Text("Before the gate, the agent wrote all \(summary.total) and the juniors reviewed them.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        ForEach(["Asha", "Ben", "Chen"], id: \.self) { name in
            Section(name) {
                ForEach(decisions.filter { $0.ticket.assignee == name }, id: \.ticket.id) { item in
                    TicketRow(ticket: item.ticket, delegation: item.delegation)
                }
            }
        }
    }
}

struct Tile: View {
    let value: Int
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text("\(value)").font(.system(size: 30, weight: .bold, design: .rounded)).foregroundStyle(color)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
    }
}

struct TicketRow: View {
    let ticket: Ticket
    let delegation: Delegation

    private var color: Color {
        switch delegation {
        case .agentWrites: return .blue
        case .tutorOnly: return .orange
        case .agentOff: return .green
        }
    }

    private var detail: String {
        switch delegation {
        case .agentWrites: return "Design note and tests are theirs"
        case let .tutorOnly(missing): return "Missing: " + missing.map(\.rawValue).joined(separator: ", ")
        case let .agentOff(skill): return "Unassisted rep: \(skill.rawValue)"
        }
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(ticket.id) · \(ticket.title)").font(.subheadline.weight(.medium))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(delegation.label)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(color.opacity(0.15), in: Capsule())
                .foregroundStyle(color)
        }
    }
}

// MARK: - Tutor contract

struct TutorSections: View {
    private let mode = TutorMode.pointAtLine

    var body: some View {
        Section("C3 · Chen's actor (\(mode.title))") {
            ScrollView(.horizontal, showsIndicators: false) {
                Text(TutorPrompt.numbered(SampleScenario.actorSource))
                    .font(.system(size: 11, design: .monospaced))
                    .fixedSize()
            }
            Text(SampleScenario.actorQuestion).font(.footnote).italic()
        }
        ReplySection(title: "Reply A · teaches", reply: SampleScenario.tutorReply, mode: mode)
        ReplySection(title: "Reply B · hands over the fix", reply: SampleScenario.fixDumpReply, mode: mode)
    }
}

struct ReplySection: View {
    let title: String
    let reply: String
    let mode: TutorMode

    private var violations: [TutorContract.Violation] {
        mode.contract.check(reply: reply, sourceLineCount: SampleScenario.actorSourceLineCount)
    }

    var body: some View {
        Section(title) {
            Text(reply)
                .font(.caption)
                .lineLimit(2)
            if violations.isEmpty {
                Label("Passes the contract", systemImage: "checkmark.seal.fill").foregroundStyle(.green)
            } else {
                ForEach(violations, id: \.description) { violation in
                    Label(violation.description, systemImage: "xmark.octagon.fill")
                        .foregroundStyle(.red)
                        .font(.footnote)
                }
            }
        }
    }
}
