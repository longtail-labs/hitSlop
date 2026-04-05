import AppKit
import SwiftUI
import SlopKit

@MainActor
final class SkinPickerPanel: NSPanel {
    static let panelWidth: CGFloat = 240
    private static let cornerRadius: CGFloat = 12

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    init(
        document: SlopTemplateDocumentModel,
        onShapeSelected: @escaping (WindowShape?) -> Void
    ) {
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

        let root = SkinPickerView(document: document, onShapeSelected: onShapeSelected)
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
        let x = parentFrame.maxX + gap
        let y = parentFrame.minY
        let height = parentFrame.height
        setFrame(
            NSRect(x: x, y: y, width: Self.panelWidth, height: height),
            display: true
        )
    }
}

// MARK: - Skin Picker View

private struct SkinPickerView: View {
    @ObservedObject var document: SlopTemplateDocumentModel
    let onShapeSelected: (WindowShape?) -> Void

    private let skinColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 2)
    private let shapeColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    defaultButton
                    vectorShapesSection
                    ForEach(SkinCatalog.groups()) { group in
                        skinGroupSection(group)
                    }
                }
                .padding(12)
            }
        }
    }

    private var header: some View {
        HStack {
            Image(systemName: "square.on.circle")
                .font(.system(size: 12, weight: .semibold))
            Text("Shape")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
            Spacer()
        }
        .foregroundColor(.primary)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var defaultButton: some View {
        Button {
            onShapeSelected(nil)
        } label: {
            HStack {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 11))
                Text("Default")
                    .font(.system(size: 12, weight: .medium))
                Spacer()
                if document.slopFile.windowShape == nil {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(document.slopFile.windowShape == nil ? Color.accentColor.opacity(0.12) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Vector Shapes

    private var vectorShapesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Shapes")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            LazyVGrid(columns: shapeColumns, spacing: 8) {
                vectorShapeButton(
                    "Rounded",
                    systemName: "rectangle",
                    shape: .roundedRect(radius: 16)
                )
                vectorShapeButton(
                    "Circle",
                    systemName: "circle",
                    shape: .circle
                )
                vectorShapeButton(
                    "Capsule",
                    systemName: "capsule",
                    shape: .capsule
                )
            }
        }
    }

    private func vectorShapeButton(
        _ name: String,
        systemName: String,
        shape: WindowShape
    ) -> some View {
        let isSelected = document.slopFile.windowShape == shape
        return Button {
            onShapeSelected(shape)
        } label: {
            VStack(spacing: 4) {
                Image(systemName: systemName)
                    .font(.system(size: 20))
                    .frame(width: 48, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.primary.opacity(0.06))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                    )

                Text(name)
                    .font(.system(size: 9))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Skin Groups

    private func skinGroupSection(_ group: SkinCatalog.Group) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(group.displayName)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            LazyVGrid(columns: skinColumns, spacing: 8) {
                ForEach(group.entries) { entry in
                    skinButton(entry)
                }
            }
        }
    }

    private func skinButton(_ entry: SkinCatalog.Entry) -> some View {
        let isSelected: Bool = {
            if case .skin(let name) = document.slopFile.windowShape {
                return name == entry.id
            }
            return false
        }()

        return Button {
            onShapeSelected(.skin(entry.id))
        } label: {
            VStack(spacing: 4) {
                Group {
                    if let image = entry.previewImage {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } else {
                        Rectangle()
                            .fill(Color.primary.opacity(0.06))
                    }
                }
                .frame(width: 64, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
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
}
