import Foundation
import SwiftUI
import SlopKit

@SlopData
public struct BrainDumpItem: Identifiable {
    @Field("ID") public var id: String = UUID().uuidString
    @Field("Text") var text: String = ""
    @Field("Category") var category: String = "idea"
    @Field("Processed") var isProcessed: Bool = false
}

@SlopData
public struct BrainDumpData {
    @SlopKit.Section("Inbox")
    @Field("Title") var title: String = "Brain Dump"
    @Field("Items") var items: [BrainDumpItem] = BrainDumpData.defaultItems

    var unprocessedCount: Int { items.filter { !$0.isProcessed }.count }
    var totalCount: Int { items.count }

    var itemsByCategory: [String: [BrainDumpItem]] {
        Dictionary(grouping: items) { $0.category }
    }

    var ideaCount: Int { itemsByCategory["idea"]?.count ?? 0 }
    var taskCount: Int { itemsByCategory["task"]?.count ?? 0 }
    var noteCount: Int { itemsByCategory["note"]?.count ?? 0 }
    var questionCount: Int { itemsByCategory["question"]?.count ?? 0 }
}

extension BrainDumpData {
    static var defaultItems: [BrainDumpItem] {
        var i1 = BrainDumpItem()
        i1.text = "Add dark mode to app"
        i1.category = "idea"
        i1.isProcessed = false

        var i2 = BrainDumpItem()
        i2.text = "Call dentist to schedule appointment"
        i2.category = "task"
        i2.isProcessed = false

        var i3 = BrainDumpItem()
        i3.text = "Research competitor features"
        i3.category = "note"
        i3.isProcessed = true

        var i4 = BrainDumpItem()
        i4.text = "Should we migrate to the new API?"
        i4.category = "question"
        i4.isProcessed = false

        return [i1, i2, i3, i4]
    }
}

// MARK: - Template

@SlopTemplate(
    id: "com.hitslop.templates.brain-dump",
    name: "Brain Dump",
    description: "Quick capture inbox for ideas, tasks, notes, and questions.",
    version: "1.0.0",
    width: 380, height: 600,
    minWidth: 340, minHeight: 480,
    shape: .roundedRect(radius: 16),
    theme: "cool",
    alwaysOnTop: true,
    categories: ["work"]
)
struct BrainDumpView: View {
    @TemplateData var data: BrainDumpData
    @Environment(\.slopTheme) private var theme
    @Environment(\.slopRenderTarget) private var renderTarget

    var body: some View {
        SlopContent {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                SlopTextField("Title", text: $data.title)
                    .font(theme.title(size: 24))
                    .foregroundStyle(theme.foreground)

                // Stats
                HStack(spacing: 10) {
                    MetricPill("\(data.unprocessedCount) unprocessed", tint: theme.accent)
                    MetricPill("\(data.totalCount) total", tint: theme.secondary)
                    Spacer()
                }

                // Category breakdown
                HStack(spacing: 8) {
                    categoryPill("💡", count: data.ideaCount, label: "Ideas")
                    categoryPill("✓", count: data.taskCount, label: "Tasks")
                    categoryPill("📝", count: data.noteCount, label: "Notes")
                    categoryPill("?", count: data.questionCount, label: "Q's")
                }

                Divider().background(theme.divider)

                // Items
                if data.items.isEmpty {
                    EmptyState(
                        icon: "lightbulb",
                        title: "Empty inbox",
                        subtitle: "Capture your thoughts as they come"
                    )
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader("Captured Items")

                            ForEach($data.items) { $item in
                                itemRow(item: $item)
                            }

                            AddItemButton("Add Item") {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    data.items.insert(BrainDumpItem(), at: 0)
                                }
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
        .background(theme.background)
    }

    @ViewBuilder
    private func categoryPill(_ icon: String, count: Int, label: String) -> some View {
        VStack(spacing: 4) {
            Text(icon)
                .font(theme.font(size: 14))
            Text("\(count)")
                .font(theme.mono(size: 11, weight: .bold))
                .foregroundStyle(theme.secondary)
            Text(label)
                .font(theme.font(size: 8, weight: .medium))
                .foregroundStyle(theme.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(theme.surface)
        .cornerRadius(8)
    }

    @ViewBuilder
    private func itemRow(item: Binding<BrainDumpItem>) -> some View {
        HStack(spacing: 12) {
            // Processed checkbox
            SlopInteractiveOnly {
                Button {
                    withAnimation { item.wrappedValue.isProcessed.toggle() }
                } label: {
                    Image(systemName: item.wrappedValue.isProcessed ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(item.wrappedValue.isProcessed ? theme.accent : theme.secondary.opacity(0.3))
                }
                .buttonStyle(.plain)
            }
            if renderTarget != .interactive {
                Image(systemName: item.wrappedValue.isProcessed ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(item.wrappedValue.isProcessed ? theme.accent : theme.secondary.opacity(0.3))
            }

            VStack(alignment: .leading, spacing: 6) {
                SlopTextField("Thought", text: item.text)
                    .font(theme.font(size: 14, weight: item.wrappedValue.isProcessed ? .regular : .medium))
                    .foregroundStyle(item.wrappedValue.isProcessed ? theme.secondary.opacity(0.7) : theme.foreground)
                    .strikethrough(item.wrappedValue.isProcessed, color: theme.secondary)

                // Category picker
                SlopInteractiveOnly {
                    Menu {
                        Button("💡 Idea") { item.wrappedValue.category = "idea" }
                        Button("✓ Task") { item.wrappedValue.category = "task" }
                        Button("📝 Note") { item.wrappedValue.category = "note" }
                        Button("? Question") { item.wrappedValue.category = "question" }
                    } label: {
                        HStack(spacing: 4) {
                            Text(categoryIcon(for: item.wrappedValue.category))
                                .font(theme.font(size: 10))
                            Text(item.wrappedValue.category)
                                .font(theme.mono(size: 9, weight: .medium))
                                .foregroundStyle(theme.secondary)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(theme.surface)
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }
                if renderTarget != .interactive {
                    HStack(spacing: 4) {
                        Text(categoryIcon(for: item.wrappedValue.category))
                            .font(theme.font(size: 10))
                        Text(item.wrappedValue.category)
                            .font(theme.mono(size: 9, weight: .medium))
                            .foregroundStyle(theme.secondary)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(theme.surface)
                    .cornerRadius(4)
                }
            }

            if renderTarget != .interactive {
                Spacer()
            }

            RemoveButton {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    data.items.removeAll { $0.id == item.wrappedValue.id }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func categoryIcon(for category: String) -> String {
        switch category {
        case "idea": return "💡"
        case "task": return "✓"
        case "note": return "📝"
        case "question": return "?"
        default: return "💡"
        }
    }
}

