import SwiftUI

public typealias SlopCurrencyField = CurrencyInput

public struct SlopSurfaceCard<Content: View>: View {
    private let padding: CGFloat
    private let content: Content

    @Environment(\.slopTheme) private var theme

    public init(
        padding: CGFloat = 14,
        @ViewBuilder content: () -> Content
    ) {
        self.padding = padding
        self.content = content()
    }

    public var body: some View {
        content
            .padding(padding)
            .background(theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                    .stroke(theme.divider.opacity(0.6), lineWidth: 1)
            )
    }
}

public struct SlopTemplateHeader<Trailing: View>: View {
    private let titlePlaceholder: String
    private let title: Binding<String>
    private let subtitlePlaceholder: String?
    private let subtitle: Binding<String>?
    private let trailing: Trailing

    @Environment(\.slopTheme) private var theme

    public init(
        titlePlaceholder: String,
        title: Binding<String>,
        subtitlePlaceholder: String? = nil,
        subtitle: Binding<String>? = nil,
        @ViewBuilder trailing: () -> Trailing = { EmptyView() }
    ) {
        self.titlePlaceholder = titlePlaceholder
        self.title = title
        self.subtitlePlaceholder = subtitlePlaceholder
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                SlopTextField(titlePlaceholder, text: title)
                    .font(theme.titleFont)
                    .foregroundStyle(theme.foreground)

                if let subtitle {
                    SlopTextField(subtitlePlaceholder ?? "", text: subtitle)
                        .font(theme.bodyFont)
                        .foregroundStyle(theme.secondary)
                }
            }

            Spacer(minLength: 0)
            trailing
        }
    }
}

public struct SlopDateField: View {
    private let selection: Binding<Date>
    private let displayedComponents: DatePickerComponents

    @Environment(\.slopRenderTarget) private var renderTarget
    @Environment(\.slopTheme) private var theme

    public init(
        _ selection: Binding<Date>,
        displayedComponents: DatePickerComponents = [.date]
    ) {
        self.selection = selection
        self.displayedComponents = displayedComponents
    }

    public var body: some View {
        if renderTarget == .interactive {
            DatePicker("", selection: selection, displayedComponents: displayedComponents)
                .labelsHidden()
                .datePickerStyle(.compact)
        } else {
            Text(dateFormatter.string(from: selection.wrappedValue))
                .foregroundStyle(theme.secondary)
        }
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = displayedComponents.contains(.date) ? .medium : .none
        formatter.timeStyle = displayedComponents.contains(.hourAndMinute) ? .short : .none
        return formatter
    }
}

public struct SlopTextArea: View {
    private let placeholder: String
    private let text: Binding<String>
    private let minHeight: CGFloat

    @Environment(\.slopRenderTarget) private var renderTarget
    @Environment(\.slopTheme) private var theme

    public init(
        _ placeholder: String = "",
        text: Binding<String>,
        minHeight: CGFloat = 88
    ) {
        self.placeholder = placeholder
        self.text = text
        self.minHeight = minHeight
    }

    public var body: some View {
        if renderTarget == .interactive {
            ZStack(alignment: .topLeading) {
                if text.wrappedValue.isEmpty, !placeholder.isEmpty {
                    Text(placeholder)
                        .font(theme.bodyFont)
                        .foregroundStyle(theme.secondary.opacity(0.8))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 8)
                        .allowsHitTesting(false)
                }

                TextEditor(text: text)
                    .font(theme.bodyFont)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: minHeight)
            }
        } else {
            Text(text.wrappedValue.isEmpty ? placeholder : text.wrappedValue)
                .font(theme.bodyFont)
                .foregroundStyle(text.wrappedValue.isEmpty ? theme.secondary : theme.foreground)
                .padding(.horizontal, 5)
                .padding(.vertical, 8)
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        }
    }
}

public struct SlopEnumField: View {
    private let selection: Binding<String>
    private let options: [EnumOption]

    @Environment(\.slopRenderTarget) private var renderTarget
    @Environment(\.slopTheme) private var theme

    public init(selection: Binding<String>, options: [EnumOption]) {
        self.selection = selection
        self.options = options
    }

    public init(selection: Binding<String>, options: [String]) {
        self.init(
            selection: selection,
            options: options.map { EnumOption(value: $0, label: $0) }
        )
    }

    public var body: some View {
        if renderTarget == .interactive {
            Picker("", selection: selection) {
                ForEach(options) { option in
                    Text(option.label).tag(option.value)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .controlSize(.small)
        } else {
            Text(selectedLabel)
                .foregroundStyle(theme.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .allowsTightening(true)
                .truncationMode(.tail)
        }
    }

    private var selectedLabel: String {
        options.first { $0.value == selection.wrappedValue }?.label ?? selection.wrappedValue
    }
}

public struct SlopStringListEditor: View {
    private let title: String?
    private let items: Binding<[String]>
    private let addLabel: String
    private let placeholder: String

    @Environment(\.slopTheme) private var theme
    @Environment(\.slopRenderTarget) private var renderTarget

    public init(
        title: String? = nil,
        items: Binding<[String]>,
        addLabel: String = "Add Item",
        placeholder: String = "Item"
    ) {
        self.title = title
        self.items = items
        self.addLabel = addLabel
        self.placeholder = placeholder
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                SectionHeader(title)
            }

            if items.wrappedValue.isEmpty, renderTarget != .interactive {
                Text("None")
                    .font(theme.bodyFont)
                    .foregroundStyle(theme.secondary)
            } else {
                ForEach(Array(items.wrappedValue.enumerated()), id: \.offset) { index, value in
                    HStack(spacing: 8) {
                        if renderTarget == .interactive {
                            SlopTextField(placeholder, text: itemBinding(at: index))
                                .font(theme.bodyFont)
                                .foregroundStyle(theme.foreground)
                        } else {
                            Text(value)
                                .font(theme.bodyFont)
                                .foregroundStyle(theme.foreground)
                                .lineLimit(1...5)
                                .truncationMode(.tail)
                                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                        }

                        Spacer(minLength: 0)

                        if renderTarget == .interactive {
                            RemoveButton {
                                var updated = items.wrappedValue
                                guard updated.indices.contains(index) else { return }
                                updated.remove(at: index)
                                items.wrappedValue = updated
                            }
                        }
                    }
                }
            }

            if renderTarget == .interactive {
                AddItemButton(addLabel) {
                    items.wrappedValue.append("")
                }
            }
        }
    }

    private func itemBinding(at index: Int) -> Binding<String> {
        Binding(
            get: {
                let values = items.wrappedValue
                guard values.indices.contains(index) else { return "" }
                return values[index]
            },
            set: { newValue in
                var values = items.wrappedValue
                while values.count <= index {
                    values.append("")
                }
                values[index] = newValue
                items.wrappedValue = values
            }
        )
    }
}

public struct SlopRecordListSection<Content: View, EmptyStateContent: View>: View {
    private let title: String
    private let isEmpty: Bool
    private let addLabel: String?
    private let onAdd: (() -> Void)?
    private let content: Content
    private let emptyState: EmptyStateContent

    @Environment(\.slopRenderTarget) private var renderTarget

    public init(
        title: String,
        isEmpty: Bool,
        addLabel: String? = nil,
        onAdd: (() -> Void)? = nil,
        @ViewBuilder emptyState: () -> EmptyStateContent,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.isEmpty = isEmpty
        self.addLabel = addLabel
        self.onAdd = onAdd
        self.emptyState = emptyState()
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionHeader(title)
                Spacer()
                if renderTarget == .interactive, let addLabel, let onAdd {
                    AddItemButton(addLabel, action: onAdd)
                }
            }

            if isEmpty {
                emptyState
            } else {
                content
            }
        }
    }
}
