import SwiftUI
import SlopKit

/// Renders a `LayoutNode` tree as SwiftUI views.
/// Uses `AnyView` type erasure to support recursive node rendering.
struct ScriptedTemplateRenderer: View {
    let root: LayoutNode
    @ObservedObject var store: RawTemplateStore
    let theme: SlopTheme
    let renderTarget: SlopRenderTarget
    let onAction: (String) -> Void

    var body: some View {
        renderNode(root)
    }

    // MARK: - Recursive Rendering (AnyView for type erasure)

    func renderNode(_ node: LayoutNode) -> AnyView {
        switch node {
        // MARK: - Layout
        case .vstack(let spacing, let children):
            return AnyView(
                VStack(spacing: spacing) {
                    ForEach(Array(children.enumerated()), id: \.offset) { _, child in
                        renderNode(child)
                    }
                }
            )

        case .hstack(let spacing, let children):
            return AnyView(
                HStack(spacing: spacing) {
                    ForEach(Array(children.enumerated()), id: \.offset) { _, child in
                        renderNode(child)
                    }
                }
            )

        case .zstack(let children):
            return AnyView(
                ZStack {
                    ForEach(Array(children.enumerated()), id: \.offset) { _, child in
                        renderNode(child)
                    }
                }
            )

        case .scrollView(let axes, let child):
            return AnyView(
                ScrollView(resolveScrollAxes(axes)) {
                    renderNode(child)
                }
            )

        case .padding(let edges, let amount, let child):
            return AnyView(
                renderNode(child)
                    .padding(resolveEdgeSet(edges), amount)
            )

        case .frame(let width, let height, let alignment, let child):
            return AnyView(
                renderNode(child)
                    .frame(
                        width: width,
                        height: height,
                        alignment: resolveFrameAlignment(alignment)
                    )
            )

        case .background(let color, let cornerRadius, let child):
            return AnyView(
                renderNode(child)
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(resolveColor(color))
                    )
            )

        case .exportVisibility(let visibility, let child):
            switch visibility {
            case .hideInExport:
                if renderTarget == .interactive {
                    return renderNode(child)
                }
            case .onlyInExport:
                if renderTarget != .interactive {
                    return renderNode(child)
                }
            }
            return AnyView(EmptyView())

        // MARK: - Display
        case .text(let content, let style):
            return AnyView(styledText(content, style: style))

        case .image(let systemName, let size, let color):
            return AnyView(
                Image(systemName: systemName)
                    .font(.system(size: size ?? 16))
                    .foregroundStyle(color.flatMap { resolveColor($0) } ?? theme.foreground)
            )

        case .divider:
            return AnyView(Divider())

        case .spacer(let minLength):
            return AnyView(Spacer(minLength: minLength))

        case .progressBar(let value, let total, let color):
            let tint = color.flatMap { resolveColor($0) } ?? theme.accent
            let fraction = total > 0 ? min(max(value / total, 0), 1) : 0
            return AnyView(
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(tint.opacity(0.2))
                            .frame(height: 6)
                        Capsule()
                            .fill(tint)
                            .frame(width: geo.size.width * fraction, height: 6)
                    }
                }
                .frame(height: 6)
            )

        case .colorDot(let hex, let size):
            return AnyView(
                Circle()
                    .fill(resolveColor(hex))
                    .frame(width: size, height: size)
            )

        // MARK: - Input
        case .textField(let fieldKey, let placeholder):
            return AnyView(
                TextField(placeholder, text: stringBinding(fieldKey))
                    .textFieldStyle(.plain)
            )

        case .numberField(let fieldKey):
            return AnyView(
                TextField("0", value: numberBinding(fieldKey), format: .number)
                    .textFieldStyle(.plain)
            )

        case .toggle(let fieldKey, let label):
            return AnyView(Toggle(label, isOn: boolBinding(fieldKey)))

        case .picker(let fieldKey, let options):
            return AnyView(
                Picker("", selection: stringBinding(fieldKey)) {
                    ForEach(options, id: \.value) { option in
                        Text(option.label).tag(option.value)
                    }
                }
            )

        case .slider(let fieldKey, let range, let step):
            if let step {
                return AnyView(Slider(value: doubleBinding(fieldKey), in: range, step: step))
            } else {
                return AnyView(Slider(value: doubleBinding(fieldKey), in: range))
            }

        case .button(let label, let action, let style):
            return AnyView(styledButton(label: label, action: action, style: style))

        // MARK: - Data
        case .forEach(let arrayKey, let builder):
            if let items = store.values[arrayKey]?.asArray {
                return AnyView(
                    ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                        if let record = item.asRecord {
                            renderNode(builder(record, index))
                        }
                    }
                )
            }
            return AnyView(EmptyView())

        case .conditional(let predicate, let thenNode, let elseNode):
            if predicate {
                return renderNode(thenNode)
            } else if let elseNode {
                return renderNode(elseNode)
            }
            return AnyView(EmptyView())

        case .empty:
            return AnyView(EmptyView())
        }
    }

    // MARK: - Text Styling

    private func styledText(_ content: String, style: TextStyle) -> some View {
        Text(content)
            .font(resolveFont(style.font))
            .fontWeight(resolveWeight(style.weight))
            .foregroundStyle(style.color.flatMap { resolveColor($0) } ?? theme.foreground)
            .multilineTextAlignment(resolveTextAlignment(style.alignment))
            .lineLimit(style.lineLimit)
    }

    // MARK: - Button Styling

    @ViewBuilder
    private func styledButton(label: String, action: String, style: LayoutNode.ButtonVariant?) -> some View {
        let btn = Button(label) { onAction(action) }
        switch style {
        case .bordered:
            btn.buttonStyle(.bordered)
        case .borderedProminent:
            btn.buttonStyle(.borderedProminent)
        case .plain:
            btn.buttonStyle(.plain)
        case .default, .none:
            btn.buttonStyle(.automatic)
        }
    }

    // MARK: - Bindings

    private func stringBinding(_ key: String) -> Binding<String> {
        Binding(
            get: { store.values[key]?.asString ?? "" },
            set: { store.setValue(.string($0), forKey: key) }
        )
    }

    private func numberBinding(_ key: String) -> Binding<Double> {
        Binding(
            get: { store.values[key]?.asNumber ?? 0 },
            set: { store.setValue(.number($0), forKey: key) }
        )
    }

    private func doubleBinding(_ key: String) -> Binding<Double> {
        numberBinding(key)
    }

    private func boolBinding(_ key: String) -> Binding<Bool> {
        Binding(
            get: { store.values[key]?.asBool ?? false },
            set: { store.setValue(.bool($0), forKey: key) }
        )
    }

    // MARK: - Resolution Helpers

    private func resolveColor(_ hex: String) -> Color {
        Color(hex: hex) ?? theme.accent
    }

    private func resolveFont(_ style: TextStyle.FontStyle?) -> Font {
        switch style {
        case .largeTitle: return .largeTitle
        case .title: return .title
        case .title2: return .title2
        case .title3: return .title3
        case .headline: return .headline
        case .subheadline: return .subheadline
        case .body, .none: return .body
        case .callout: return .callout
        case .footnote: return .footnote
        case .caption: return .caption
        case .caption2: return .caption2
        }
    }

    private func resolveWeight(_ weight: TextStyle.FontWeight?) -> Font.Weight {
        switch weight {
        case .ultraLight: return .ultraLight
        case .thin: return .thin
        case .light: return .light
        case .regular, .none: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        case .heavy: return .heavy
        case .black: return .black
        }
    }

    private func resolveTextAlignment(_ alignment: TextStyle.TextAlignment?) -> SwiftUI.TextAlignment {
        switch alignment {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        case .none: return .leading
        }
    }

    private func resolveScrollAxes(_ axes: LayoutNode.ScrollAxes) -> Axis.Set {
        switch axes {
        case .vertical: return .vertical
        case .horizontal: return .horizontal
        case .both: return [.vertical, .horizontal]
        }
    }

    private func resolveEdgeSet(_ edges: LayoutNode.EdgeSet) -> Edge.Set {
        switch edges {
        case .all: return .all
        case .horizontal: return .horizontal
        case .vertical: return .vertical
        case .top: return .top
        case .bottom: return .bottom
        case .leading: return .leading
        case .trailing: return .trailing
        }
    }

    private func resolveFrameAlignment(_ alignment: LayoutNode.FrameAlignment?) -> Alignment {
        switch alignment {
        case .center, .none: return .center
        case .leading: return .leading
        case .trailing: return .trailing
        case .top: return .top
        case .bottom: return .bottom
        case .topLeading: return .topLeading
        case .topTrailing: return .topTrailing
        case .bottomLeading: return .bottomLeading
        case .bottomTrailing: return .bottomTrailing
        }
    }
}
