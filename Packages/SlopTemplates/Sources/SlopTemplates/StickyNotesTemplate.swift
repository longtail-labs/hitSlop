import Foundation
import SwiftUI
import SlopKit

@SlopData
public struct StickyNote: Identifiable {
    @Field("ID") public var id: String = UUID().uuidString
    @Field("Text") var text: String = ""
    @Field("X") public var x: Double = 0
    @Field("Y") public var y: Double = 0
    @Field("Width") public var width: Double = 160
    @Field("Height") public var height: Double = 140
    @Field("Color") var color: String = "#FFD93D"
}

extension StickyNote: CanvasPositionable {}

@SlopData
public struct StickyNotesData {
    @Field("Canvas Title") var canvasTitle: String = "Sticky Notes"
    @Field("Notes") var notes: [StickyNote] = StickyNotesData.defaultNotes
    @Field("Viewport") var viewport: CanvasViewport = CanvasViewport()
}

extension StickyNotesData {
    static var defaultNotes: [StickyNote] {
        func note(_ text: String, _ x: Double, _ y: Double, _ color: String) -> StickyNote {
            var n = StickyNote()
            n.text = text
            n.x = x
            n.y = y
            n.color = color
            return n
        }
        return [
            note("Remember to buy groceries", 80, 100, "#FFD93D"),
            note("Call dentist on Monday", 320, 80, "#FF6B6B"),
            note("Read chapter 5 of the book", 180, 320, "#6BCB77"),
            note("Ideas for the weekend:\n- Hiking\n- Movie night\n- Cook pasta", 500, 200, "#4A9EFF"),
            note("Meeting notes from Friday", 600, 450, "#C084FC"),
        ]
    }
}

// MARK: - Template

@SlopTemplate(
    id: "com.hitslop.templates.sticky-notes",
    name: "Sticky Notes",
    description: "Scatter short notes on a board for quick reminders and scratch ideas.",
    version: "1.0.0",
    width: 600, height: 500,
    minWidth: 400, minHeight: 300,
    shape: .roundedRect(radius: 16),
    alwaysOnTop: true,
    categories: ["work"]
)
struct StickyNotesView: View {
    @TemplateData var data: StickyNotesData
    @Environment(\.slopTheme) private var theme
    @Environment(\.slopRenderTarget) private var renderTarget

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Divider().background(theme.divider)

            if renderTarget == .interactive {
                SlopCanvas(
                    items: $data.notes,
                    viewport: $data.viewport,
                    gridSpacing: 30,
                    minZoom: 0.3,
                    maxZoom: 3.0,
                    onDoubleTap: { worldPoint in
                        withAnimation {
                            var note = StickyNote()
                            note.x = worldPoint.x - 80
                            note.y = worldPoint.y - 70
                            data.notes.append(note)
                        }
                    }
                ) { $note in
                    StickyNoteContent(note: $note) {
                        withAnimation { data.notes.removeAll { $0.id == note.id } }
                    }
                }
            } else {
                exportContent
            }
        }
        .background(theme.background)
    }

    private var exportContent: some View {
        let columns = [
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8),
        ]
        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(data.notes) { note in
                VStack(alignment: .leading, spacing: 4) {
                    Text(note.text)
                        .font(theme.font(size: 11))
                        .foregroundStyle(.black.opacity(0.8))
                        .lineLimit(4)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(colorFromHex(note.color))
                )
            }
        }
        .padding(12)
    }

    private var header: some View {
        HStack {
            SlopTextField("Canvas Title", text: $data.canvasTitle)
                .font(theme.font(size: 18, weight: .bold))
                .foregroundStyle(theme.foreground)

            Spacer()

            Text("\(data.notes.count) notes")
                .font(.caption)
                .foregroundStyle(theme.secondary)

            SlopInteractiveOnly {
                Button {
                    withAnimation {
                        var note = StickyNote()
                        note.text = "New note"
                        note.x = data.viewport.x - 80
                        note.y = data.viewport.y - 70
                        data.notes.append(note)
                    }
                } label: {
                    Label("Add", systemImage: "plus")
                        .font(.caption)
                        .foregroundStyle(theme.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }
}

// MARK: - Note Content (no drag/position logic — canvas handles that)

private struct StickyNoteContent: View {
    @Binding var note: StickyNote
    let onDelete: () -> Void
    @Environment(\.slopTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "line.3.horizontal")
                    .font(theme.font(size: 9))
                    .foregroundStyle(.black.opacity(0.2))
                Spacer()
                Button(action: onDelete) {
                    Image(systemName: "xmark")
                        .font(theme.font(size: 9, weight: .bold))
                        .foregroundStyle(.black.opacity(0.3))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 8)
            .padding(.top, 6)

            TextEditor(text: $note.text)
                .font(theme.font(size: 12))
                .foregroundStyle(.black.opacity(0.8))
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
        }
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(colorFromHex(note.color))
                .shadow(color: .black.opacity(0.08), radius: 3, y: 2)
        )
    }
}

