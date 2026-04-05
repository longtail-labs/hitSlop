import Foundation
import SwiftUI
import SlopKit

@SlopData
public struct ActionItem: Identifiable {
    @Field("ID") public var id: String = UUID().uuidString
    @Field("Task") var task: String = ""
    @Field("Assignee") var assignee: String = ""
    @Field("Due Date", editor: .date) var dueDate: Date = .now
    @Field("Done") var done: Bool = false
}

@SlopData
public struct MeetingNotesData {
    @SlopKit.Section("Meeting")
    @Field("Meeting Title") var meetingTitle: String = "Sprint Planning"
    @Field("Date", editor: .date) var date: Date = .now
    @Field("Attendees") var attendees: String = "Alice, Bob, Charlie"

    @SlopKit.Section("Content")
    @Field("Agenda", editor: .multiLine) var agenda: String = "1. Review last sprint\n2. Plan next sprint\n3. Blockers"
    @Field("Notes", editor: .multiLine) var notes: String = ""

    @SlopKit.Section("Actions")
    @Field("Action Items") var actionItems: [ActionItem] = MeetingNotesData.defaultActionItems

    var completedActions: Int {
        actionItems.filter { $0.done }.count
    }

    var totalActions: Int {
        actionItems.count
    }

    var pendingActions: Int {
        actionItems.filter { !$0.done }.count
    }
}

extension MeetingNotesData {
    static var defaultActionItems: [ActionItem] {
        func action(_ task: String, _ assignee: String, _ dueDate: Date, _ done: Bool) -> ActionItem {
            var a = ActionItem()
            a.task = task
            a.assignee = assignee
            a.dueDate = dueDate
            a.done = done
            return a
        }

        return [
            action("Update documentation", "Alice", makeDate(2026, 4, 5), false),
            action("Review pull requests", "Bob", makeDate(2026, 4, 3), false),
            action("Schedule follow-up", "Charlie", makeDate(2026, 4, 2), true)
        ]
    }

    private static func makeDate(_ y: Int, _ m: Int, _ d: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: y, month: m, day: d)) ?? .now
    }
}

@SlopTemplate(
    id: "com.hitslop.templates.meeting-notes",
    name: "Meeting Notes",
    description: "Capture meeting agendas, notes, and action items in one place.",
    version: "1.0.0",
    width: 460, height: 600,
    shape: .roundedRect(radius: 16),
    theme: "paper-ledger",
    alwaysOnTop: true,
    categories: ["work"]
)
struct MeetingNotesView: View {
    @TemplateData var data: MeetingNotesData
    @Environment(\.slopTheme) private var theme
    @Environment(\.slopRenderTarget) private var renderTarget

    var body: some View {
        SlopContent {
            VStack(alignment: .leading, spacing: 16) {
                SlopTemplateHeader(
                    titlePlaceholder: "Meeting title",
                    title: $data.meetingTitle
                ) {
                    SlopSurfaceCard(padding: 10) {
                        SlopDateField($data.date)
                    }
                }

                // Attendees
                HStack(spacing: 6) {
                    Image(systemName: "person.2.fill")
                        .font(.caption)
                        .foregroundColor(theme.secondary)

                    SlopTextField("Attendees", text: $data.attendees)
                        .font(.caption)
                        .foregroundColor(theme.secondary)
                }

                Divider()
                    .background(theme.divider)

                // Agenda section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Agenda")
                        .font(.headline)
                        .foregroundColor(theme.foreground)

                    SlopSurfaceCard(padding: 10) {
                        SlopTextArea("Agenda", text: $data.agenda, minHeight: 72)
                    }
                }

                // Notes section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Notes")
                        .font(.headline)
                        .foregroundColor(theme.foreground)

                    SlopSurfaceCard(padding: 10) {
                        SlopTextArea("Add meeting notes...", text: $data.notes, minHeight: 96)
                    }
                }

                Divider()
                    .background(theme.divider)

                // Action items section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Action Items")
                            .font(.headline)
                            .foregroundColor(theme.foreground)

                        Spacer()

                        Text("\(data.completedActions) of \(data.totalActions) completed")
                            .font(.caption)
                            .foregroundColor(theme.secondary)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        ForEach($data.actionItems) { $item in
                            ActionItemRow(item: $item, theme: theme, renderTarget: renderTarget)
                        }
                    }

                    // Add action item button
                    SlopInteractiveOnly {
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                data.actionItems.append(ActionItem())
                            }
                        }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Add Action Item")
                            }
                            .font(.subheadline)
                            .foregroundColor(theme.accent)
                        }
                    }
                }
            }
            .padding(24)
        }
        .background(theme.background)
    }
}

struct ActionItemRow: View {
    @Binding var item: ActionItem
    let theme: SlopTheme
    let renderTarget: SlopRenderTarget

    var body: some View {
        HStack(spacing: 12) {
            SlopInteractiveOnly {
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        item.done.toggle()
                    }
                }) {
                    Image(systemName: item.done ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(item.done ? theme.accent : theme.secondary)
                }
                .buttonStyle(.plain)
            }

            if renderTarget != .interactive {
                Image(systemName: item.done ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(item.done ? theme.accent : theme.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                SlopTextField("Task", text: $item.task)
                    .font(.body)
                    .foregroundColor(theme.foreground)
                    .strikethrough(item.done)

                HStack(spacing: 8) {
                    if !item.assignee.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "person.fill")
                                .font(.caption2)
                            SlopTextField("Assignee", text: $item.assignee)
                                .font(.caption)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(theme.accent)
                        .cornerRadius(6)
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.caption2)
                        SlopDateField($item.dueDate)
                    }
                    .foregroundColor(theme.secondary)
                }
            }

            Spacer()
        }
        .padding(10)
        .background(theme.surface)
        .cornerRadius(8)
        .opacity(item.done ? 0.6 : 1.0)
    }
}
