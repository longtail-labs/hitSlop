import AppKit
import SwiftUI
import SlopKit

@MainActor
final class ThemePickerPanel: NSPanel {
    static let panelWidth: CGFloat = 240
    private static let cornerRadius: CGFloat = 12

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    init(document: SlopTemplateDocumentModel) {
        let rect = NSRect(x: 0, y: 0, width: Self.panelWidth, height: 440)
        super.init(
            contentRect: rect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isFloatingPanel = true
        becomesKeyOnlyIfNeeded = true
        isMovableByWindowBackground = false
        isReleasedWhenClosed = false
        isRestorable = false
        hidesOnDeactivate = false
        level = .floating
        collectionBehavior = [.moveToActiveSpace]

        let root = ThemePickerView(document: document)
            .frame(width: Self.panelWidth)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Self.cornerRadius))
            .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius))

        let hostingView = NSHostingView(rootView: root)
        hostingView.frame = rect
        hostingView.autoresizingMask = [.width, .height]
        contentView = hostingView
    }

    func reposition(relativeTo window: NSWindow, gap: CGFloat = 8) {
        let parentFrame = window.frame
        let x = parentFrame.minX - Self.panelWidth - gap
        let y = parentFrame.minY
        let height = parentFrame.height
        setFrame(
            NSRect(x: x, y: y, width: Self.panelWidth, height: height),
            display: true
        )
    }
}

// MARK: - Theme Picker View

private struct ThemePickerView: View {
    @ObservedObject var document: SlopTemplateDocumentModel

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    defaultButton
                    let packageThemes = ThemeCatalog.packageEntries(from: document.fileURL)
                    if !packageThemes.isEmpty {
                        groupSection(ThemeCatalog.Group(
                            id: "document",
                            displayName: "Document",
                            entries: packageThemes
                        ))
                    }
                    ForEach(ThemeCatalog.groups()) { group in
                        groupSection(group)
                    }
                }
                .padding(12)
            }
        }
    }

    private var header: some View {
        HStack {
            Image(systemName: "paintpalette")
                .font(.system(size: 12, weight: .semibold))
            Text("Theme")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
            Spacer()
        }
        .foregroundColor(.primary)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var defaultButton: some View {
        Button {
            document.setTheme(nil)
        } label: {
            HStack {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 11))
                Text("Default")
                    .font(.system(size: 12, weight: .medium))
                Spacer()
                if document.themeName == nil {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(document.themeName == nil ? Color.accentColor.opacity(0.12) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func groupSection(_ group: ThemeCatalog.Group) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(group.displayName)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(group.entries) { entry in
                    swatchButton(entry)
                }
            }
        }
    }

    private func swatchButton(_ entry: ThemeCatalog.Entry) -> some View {
        let isSelected = document.themeName == entry.id
        return Button {
            document.setTheme(entry.id)
        } label: {
            VStack(spacing: 4) {
                swatchColors(entry.theme)
                    .frame(height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                    )

                Text(entry.displayName)
                    .font(.system(size: 9))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .buttonStyle(.plain)
    }

    private func swatchColors(_ theme: SlopTheme) -> some View {
        HStack(spacing: 0) {
            Rectangle().fill(theme.background)
            Rectangle().fill(theme.accent)
            Rectangle().fill(theme.surface)
            Rectangle().fill(theme.secondary)
        }
    }
}
