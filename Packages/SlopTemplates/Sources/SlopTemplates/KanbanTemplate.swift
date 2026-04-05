import Foundation
import SwiftUI
import SlopKit

@SlopData
public struct KanbanCard: Identifiable {
    @Field("ID") public var id: String = UUID().uuidString
    @Field("Title") var title: String = ""
    @Field("Description") var description: String = ""
    @Field("Color") var color: String = "#4A9EFF"
}

@SlopData
public struct KanbanColumn: Identifiable {
    @Field("ID") public var id: String = UUID().uuidString
    @Field("Name") var name: String = ""
    @Field("Cards") var cards: [KanbanCard] = []
}

@SlopData
public struct KanbanData {
    @Field("Board Title") var boardTitle: String = "My Board"
    @Field("Columns") var columns: [KanbanColumn] = KanbanData.defaultColumns
}

extension KanbanData {
    static var defaultColumns: [KanbanColumn] {
        func card(_ title: String, _ desc: String, _ color: String) -> KanbanCard {
            var c = KanbanCard()
            c.title = title
            c.description = desc
            c.color = color
            return c
        }
        func column(_ name: String, _ cards: [KanbanCard]) -> KanbanColumn {
            var col = KanbanColumn()
            col.name = name
            col.cards = cards
            return col
        }
        return [
            column("To Do", [
                card("Design mockups", "Create wireframes for the new landing page", "#FF6B6B"),
                card("Write specs", "Document API requirements", "#4A9EFF"),
                card("Research competitors", "Analyze top 5 competitors", "#FFD93D"),
            ]),
            column("In Progress", [
                card("Build auth flow", "Implement OAuth2 login", "#6BCB77"),
                card("Database schema", "Set up PostgreSQL tables", "#4A9EFF"),
            ]),
            column("Done", [
                card("Project setup", "Initialize repo and CI/CD", "#C084FC"),
                card("Team onboarding", "All members have access", "#6BCB77"),
            ]),
        ]
    }
}

// MARK: - Template

@SlopTemplate(
    id: "com.hitslop.templates.kanban",
    name: "Kanban Board",
    description: "Organize work into columns with visual cards for tasks, bugs, and ideas.",
    version: "1.0.0",
    width: 700, height: 500,
    minWidth: 500, minHeight: 300,
    shape: .roundedRect(radius: 16),
    alwaysOnTop: true,
    categories: ["popular", "work"]
)
struct KanbanView: View {
    @TemplateData var data: KanbanData
    @Environment(\.slopTheme) private var theme
    @Environment(\.slopRenderTarget) private var renderTarget

    var body: some View {
        Group {
            if renderTarget == .interactive {
                KanbanBoardView(data: $data)
            } else {
                KanbanExportView(data: data)
            }
        }
        .background(theme.background)
    }
}


// Preference key to collect column frames in the board coordinate space.
private struct ColumnFrameKey: PreferenceKey {
    nonisolated(unsafe) static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

private struct KanbanBoardView: View {
    @Binding var data: KanbanData
    @Environment(\.slopTheme) private var theme
    @State private var draggedCard: KanbanCard?
    @State private var dragSourceColumnID: String?
    @State private var dragOffset: CGSize = .zero
    @State private var columnFrames: [String: CGRect] = [:]
    @State private var highlightedColumnID: String?

    private let boardSpace = "kanbanBoard"

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                TextField("Board Title", text: $data.boardTitle)
                    .font(theme.title(size: 20))
                    .foregroundStyle(theme.foreground)
                    .textFieldStyle(.plain)

                Spacer()

                Button {
                    withAnimation {
                        var col = KanbanColumn()
                        col.name = "New Column"
                        data.columns.append(col)
                    }
                } label: {
                    Label("Add Column", systemImage: "plus")
                        .font(.caption)
                        .foregroundStyle(theme.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider().background(theme.divider)

            // Columns
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach($data.columns) { $column in
                        ColumnView(
                            column: $column,
                            allColumns: $data.columns,
                            draggedCard: $draggedCard,
                            dragSourceColumnID: $dragSourceColumnID,
                            dragOffset: $dragOffset,
                            highlightedColumnID: $highlightedColumnID,
                            columnFrames: columnFrames,
                            boardSpace: boardSpace
                        )
                    }
                }
                .padding(12)
            }
            .coordinateSpace(name: boardSpace)
            .onPreferenceChange(ColumnFrameKey.self) { columnFrames = $0 }
        }
    }
}

private struct ColumnView: View {
    @Binding var column: KanbanColumn
    @Binding var allColumns: [KanbanColumn]
    @Binding var draggedCard: KanbanCard?
    @Binding var dragSourceColumnID: String?
    @Binding var dragOffset: CGSize
    @Binding var highlightedColumnID: String?
    let columnFrames: [String: CGRect]
    let boardSpace: String
    @Environment(\.slopTheme) private var theme

    private var isTargeted: Bool { highlightedColumnID == column.id }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Column header
            HStack {
                TextField("Column", text: $column.name)
                    .font(theme.font(size: 13, weight: .semibold))
                    .foregroundStyle(theme.foreground)
                    .textFieldStyle(.plain)

                Text("\(column.cards.count)")
                    .font(theme.font(size: 11, weight: .medium))
                    .foregroundStyle(theme.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule().fill(theme.surface)
                    )

                Spacer()

                Button {
                    withAnimation { allColumns.removeAll { $0.id == column.id } }
                } label: {
                    Image(systemName: "xmark")
                        .font(theme.font(size: 10, weight: .medium))
                        .foregroundStyle(theme.secondary.opacity(0.5))
                }
                .buttonStyle(.plain)
            }

            // Cards
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 6) {
                    ForEach($column.cards) { $card in
                        let isDragging = draggedCard?.id == card.id && dragSourceColumnID == column.id
                        CardView(card: $card) {
                            withAnimation { column.cards.removeAll { $0.id == card.id } }
                        }
                        .opacity(isDragging ? 0.3 : 1)
                        .offset(isDragging ? dragOffset : .zero)
                        .zIndex(isDragging ? 100 : 0)
                        .gesture(
                            DragGesture(coordinateSpace: .named(boardSpace))
                                .onChanged { value in
                                    if draggedCard == nil {
                                        draggedCard = card
                                        dragSourceColumnID = column.id
                                    }
                                    dragOffset = value.translation
                                    // Highlight the column under the drag point
                                    let pt = value.location
                                    highlightedColumnID = columnFrames.first(where: {
                                        $0.value.contains(pt)
                                    })?.key
                                }
                                .onEnded { value in
                                    let pt = value.location
                                    if let targetID = columnFrames.first(where: { $0.value.contains(pt) })?.key,
                                       targetID != column.id,
                                       let card = draggedCard {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            // Remove from source
                                            if let srcIdx = allColumns.firstIndex(where: { $0.id == column.id }) {
                                                allColumns[srcIdx].cards.removeAll { $0.id == card.id }
                                            }
                                            // Add to target
                                            if let dstIdx = allColumns.firstIndex(where: { $0.id == targetID }) {
                                                allColumns[dstIdx].cards.append(card)
                                            }
                                        }
                                    }
                                    draggedCard = nil
                                    dragSourceColumnID = nil
                                    dragOffset = .zero
                                    highlightedColumnID = nil
                                }
                        )
                    }
                }
            }
            .frame(maxHeight: .infinity)

            // Add card button
            Button {
                withAnimation {
                    var card = KanbanCard()
                    card.title = "New Card"
                    column.cards.append(card)
                }
            } label: {
                HStack {
                    Image(systemName: "plus")
                        .font(theme.font(size: 11))
                    Text("Add card")
                        .font(theme.font(size: 12))
                }
                .foregroundStyle(theme.secondary.opacity(0.6))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(theme.divider, style: StrokeStyle(lineWidth: 1, dash: [4]))
                )
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .frame(width: 200)
        .background(
            GeometryReader { proxy in
                RoundedRectangle(cornerRadius: 10)
                    .fill(isTargeted ? theme.accent.opacity(0.08) : theme.surface.opacity(0.5))
                    .preference(
                        key: ColumnFrameKey.self,
                        value: [column.id: proxy.frame(in: .named(boardSpace))]
                    )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(isTargeted ? theme.accent.opacity(0.3) : Color.clear, lineWidth: 1.5)
        )
    }
}

private struct CardView: View {
    @Binding var card: KanbanCard
    let onDelete: () -> Void
    @Environment(\.slopTheme) private var theme

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(colorFromHex(card.color))
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 3) {
                TextField("Title", text: $card.title)
                    .font(theme.font(size: 12, weight: .medium))
                    .foregroundStyle(theme.foreground)
                    .textFieldStyle(.plain)
                    .lineLimit(2)
                TextField("Add description...", text: $card.description)
                    .font(theme.font(size: 10))
                    .foregroundStyle(theme.secondary)
                    .textFieldStyle(.plain)
                    .lineLimit(2)
            }

            Spacer()

            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(theme.font(size: 8, weight: .medium))
                    .foregroundStyle(theme.secondary.opacity(0.4))
            }
            .buttonStyle(.plain)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(theme.background)
                .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
        )
    }
}

// MARK: - Static Export View (for ImageRenderer / PDF)

private struct KanbanExportView: View {
    let data: KanbanData
    @Environment(\.slopTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text(data.boardTitle)
                    .font(theme.title(size: 20))
                    .foregroundStyle(theme.foreground)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider().background(theme.divider)

            // Columns — flat HStack (no ScrollView)
            HStack(alignment: .top, spacing: 12) {
                ForEach(data.columns) { column in
                    ExportColumnView(column: column)
                }
            }
            .padding(12)
        }
    }
}

private struct ExportColumnView: View {
    let column: KanbanColumn
    @Environment(\.slopTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(column.name)
                    .font(theme.font(size: 13, weight: .semibold))
                    .foregroundStyle(theme.foreground)

                Text("\(column.cards.count)")
                    .font(theme.font(size: 11, weight: .medium))
                    .foregroundStyle(theme.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule().fill(theme.surface)
                    )
                Spacer()
            }

            VStack(spacing: 6) {
                ForEach(column.cards) { card in
                    ExportCardView(card: card)
                }
            }
        }
        .padding(10)
        .frame(width: 200)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(theme.surface.opacity(0.5))
        )
    }
}

private struct ExportCardView: View {
    let card: KanbanCard
    @Environment(\.slopTheme) private var theme

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(colorFromHex(card.color))
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 3) {
                Text(card.title)
                    .font(theme.font(size: 12, weight: .medium))
                    .foregroundStyle(theme.foreground)
                    .lineLimit(2)
                if !card.description.isEmpty {
                    Text(card.description)
                        .font(theme.font(size: 10))
                        .foregroundStyle(theme.secondary)
                        .lineLimit(2)
                }
            }
            Spacer()
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(theme.background)
        )
    }
}
