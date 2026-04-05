import AppKit
import SwiftUI
import UniformTypeIdentifiers
import SlopKit

@MainActor
struct SchemaInspectorView: View {
    @ObservedObject var document: SlopTemplateDocumentModel
    let schema: Schema

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(Array(schema.sections.enumerated()), id: \.offset) { _, section in
                        SchemaSectionView(
                            section: section,
                            data: rootBinding,
                            packageURL: document.fileURL
                        )
                    }
                }
                .padding(12)
            }
        }
    }

    private var header: some View {
        HStack {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 12, weight: .semibold))
            Text("Inspector")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
            Spacer()
        }
        .foregroundColor(.primary)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var rootBinding: Binding<[String: FieldValue]> {
        Binding(
            get: { document.rawData },
            set: { document.rawStore.setValues($0) }
        )
    }
}

private struct SchemaSectionView: View {
    let section: SchemaSection
    let data: Binding<[String: FieldValue]>
    var packageURL: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(section.title.uppercased())
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(section.fields.filter { $0.label != "ID" }.enumerated()), id: \.element.key) { _, field in
                    SchemaFieldEditor(field: field, data: data, packageURL: packageURL)
                }
            }
        }
    }
}

private struct SchemaFieldEditor: View {
    let field: FieldDescriptor
    let data: Binding<[String: FieldValue]>
    var packageURL: URL?

    var body: some View {
        switch field.kind {
        case .bool:
            Toggle(field.label, isOn: boolBinding)
                .toggleStyle(.switch)
                .controlSize(.small)

        case .record:
            recordEditor

        case .array:
            arrayEditor

        case .file:
            fileEditor

        default:
            VStack(alignment: .leading, spacing: 6) {
                fieldLabel
                editorControl
            }
        }
    }

    private var editorControl: some View {
        Group {
            switch field.resolvedEditor {
            case .multiLine:
                SlopTextArea(field.label, text: stringBinding, minHeight: 88)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.white.opacity(0.04))
                    )

            case .date:
                SlopDateField(dateBinding)

            case .enumeration:
                SlopEnumField(selection: stringBinding, options: field.options ?? [])

            case .color:
                HStack(spacing: 8) {
                    SlopColorField(hex: stringBinding)
                    TextField(field.label, text: stringBinding)
                        .textFieldStyle(.roundedBorder)
                }

            case .currency(let codeField):
                let currencyCode = codeField.flatMap { data.wrappedValue[$0]?.asString } ?? "USD"
                SlopCurrencyField(currency: currencyCode, value: numberBinding, width: 100)

            case .singleLine, .automatic, .stringList:
                switch field.kind {
                case .number:
                    TextField(field.label, value: numberBinding, format: .number)
                        .textFieldStyle(.roundedBorder)

                case .image:
                    imageEditor

                case .string, .richText, .color:
                    TextField(field.label, text: stringBinding)
                        .textFieldStyle(.roundedBorder)

                case .bool, .enumeration, .array, .record, .file, .date:
                    EmptyView()
                }
            }
        }
    }

    @ViewBuilder
    private var recordEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel
            if let recordSchema = field.recordSchema {
                DisclosureGroup(field.label) {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(recordSchema.sections.enumerated()), id: \.offset) { _, section in
                            SchemaSectionView(
                                section: section,
                                data: recordBinding,
                                packageURL: packageURL
                            )
                        }
                    }
                    .padding(.top, 8)
                }
                .font(.system(size: 11, design: .monospaced))
            } else {
                unsupportedText("Missing record schema")
            }
        }
    }

    @ViewBuilder
    private var arrayEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                fieldLabel
                Spacer()
                Button("Add") {
                    addArrayItem()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            if let itemSchema = field.itemSchema {
                recordArrayEditor(itemSchema: itemSchema)
            } else if field.hasPrimitiveArrayItems {
                primitiveArrayEditor
            } else {
                unsupportedText("Missing array item metadata")
            }
        }
    }

    @ViewBuilder
    private func recordArrayEditor(itemSchema: Schema) -> some View {
        let items = arrayItems
        if items.isEmpty {
            unsupportedText("No items")
        } else {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, _ in
                    SlopSurfaceCard(padding: 10) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Item \(index + 1)")
                                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Button("Remove") {
                                    removeArrayItem(at: index)
                                }
                                .buttonStyle(.plain)
                                .foregroundColor(.red)
                            }

                            ForEach(Array(itemSchema.sections.enumerated()), id: \.offset) { _, section in
                                SchemaSectionView(
                                    section: section,
                                    data: arrayRecordBinding(at: index, schema: itemSchema),
                                    packageURL: packageURL
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var primitiveArrayEditor: some View {
        if field.arrayItemKind == .string || field.resolvedEditor == .stringList {
            SlopStringListEditor(
                items: stringArrayBinding,
                addLabel: "Add Value",
                placeholder: field.label
            )
        } else {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(arrayItems.enumerated()), id: \.offset) { index, _ in
                    HStack(spacing: 8) {
                        primitiveArrayItemEditor(at: index)
                        Spacer(minLength: 0)
                        Button("Remove") {
                            removeArrayItem(at: index)
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.red)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func primitiveArrayItemEditor(at index: Int) -> some View {
        if let itemKind = field.arrayItemKind {
            switch itemKind {
            case .number:
                TextField("Value", value: primitiveNumberBinding(at: index), format: .number)
                    .textFieldStyle(.roundedBorder)
            case .bool:
                Toggle("Value", isOn: primitiveBoolBinding(at: index))
                    .toggleStyle(.switch)
                    .controlSize(.small)
            case .date:
                SlopDateField(primitiveDateBinding(at: index))
            case .color:
                HStack(spacing: 8) {
                    SlopColorField(hex: primitiveStringBinding(at: index))
                    TextField("Color", text: primitiveStringBinding(at: index))
                        .textFieldStyle(.roundedBorder)
                }
            default:
                TextField("Value", text: primitiveStringBinding(at: index))
                    .textFieldStyle(.roundedBorder)
            }
        } else {
            unsupportedText("Missing array item type")
        }
    }

    @ViewBuilder
    private var fileEditor: some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel
            if let desc = field.fileDescriptor {
                HStack(spacing: 8) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Text(desc.defaultFilename)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.primary)
                    Spacer()
                    Button("Open") {
                        openSidecarFile(key: field.key)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            } else {
                unsupportedText("Missing file descriptor")
            }
        }
    }

    private var fieldLabel: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(field.label)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.primary)

            if let hint = field.hint {
                Text(hint)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
    }

    private func unsupportedText(_ message: String) -> some View {
        Text(message)
            .font(.system(size: 10, design: .monospaced))
            .foregroundColor(.secondary)
    }

    private var fieldBinding: Binding<FieldValue> {
        Binding(
            get: { data.wrappedValue[field.key] ?? field.defaultValue },
            set: { newValue in
                var updated = data.wrappedValue
                updated[field.key] = newValue
                data.wrappedValue = updated
            }
        )
    }

    private var stringBinding: Binding<String> {
        Binding(
            get: { fieldBinding.wrappedValue.asString ?? field.defaultValue.asString ?? "" },
            set: { fieldBinding.wrappedValue = stringValue($0) }
        )
    }

    private var numberBinding: Binding<Double> {
        Binding(
            get: { fieldBinding.wrappedValue.asNumber ?? field.defaultValue.asNumber ?? 0 },
            set: { fieldBinding.wrappedValue = .number($0) }
        )
    }

    private var boolBinding: Binding<Bool> {
        Binding(
            get: { fieldBinding.wrappedValue.asBool ?? field.defaultValue.asBool ?? false },
            set: { fieldBinding.wrappedValue = .bool($0) }
        )
    }

    private var dateBinding: Binding<Date> {
        Binding(
            get: { fieldBinding.wrappedValue.asDate ?? field.defaultValue.asDate ?? .now },
            set: { fieldBinding.wrappedValue = .date($0) }
        )
    }

    private var recordBinding: Binding<[String: FieldValue]> {
        let defaultRecord = field.recordSchema?.defaultValues() ?? [:]
        return Binding(
            get: { fieldBinding.wrappedValue.asRecord ?? defaultRecord },
            set: { fieldBinding.wrappedValue = .record($0) }
        )
    }

    private var arrayItems: [FieldValue] {
        fieldBinding.wrappedValue.asArray ?? []
    }

    private func addArrayItem() {
        var items = arrayItems
        if let itemSchema = field.itemSchema {
            items.append(.record(itemSchema.defaultValues()))
        } else if let itemKind = field.arrayItemKind {
            items.append(defaultPrimitiveValue(for: itemKind))
        }
        fieldBinding.wrappedValue = .array(items)
    }

    private func removeArrayItem(at index: Int) {
        var items = arrayItems
        guard items.indices.contains(index) else { return }
        items.remove(at: index)
        fieldBinding.wrappedValue = .array(items)
    }

    private func arrayRecordBinding(at index: Int, schema: Schema) -> Binding<[String: FieldValue]> {
        Binding(
            get: {
                let items = arrayItems
                guard items.indices.contains(index),
                      let record = items[index].asRecord
                else { return schema.defaultValues() }
                return record
            },
            set: { updatedRecord in
                var items = arrayItems
                while items.count <= index {
                    items.append(.record(schema.defaultValues()))
                }
                items[index] = .record(updatedRecord)
                fieldBinding.wrappedValue = .array(items)
            }
        )
    }

    @ViewBuilder
    private var imageEditor: some View {
        let path = stringBinding.wrappedValue
        let resolved = TemplateImage(path).resolved(relativeTo: packageURL)
        VStack(alignment: .leading, spacing: 6) {
            if !path.isEmpty, let nsImage = NSImage(contentsOfFile: resolved) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            HStack(spacing: 6) {
                Button("Choose\u{2026}") {
                    let panel = NSOpenPanel()
                    panel.allowsMultipleSelection = false
                    panel.canChooseDirectories = false
                    panel.allowedContentTypes = [.image]
                    if panel.runModal() == .OK, let url = panel.url {
                        let imported = TemplateImage.importAsset(from: url, into: packageURL)
                        stringBinding.wrappedValue = imported.path
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                if !path.isEmpty {
                    Button("Clear") {
                        stringBinding.wrappedValue = ""
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.red)
                    .controlSize(.small)
                }
            }
        }
    }

    private func openSidecarFile(key: String) {
        guard let desc = field.fileDescriptor, let packageURL else { return }
        let sidecarURL = packageURL.appendingPathComponent(desc.defaultFilename)
        NSWorkspace.shared.open(sidecarURL)
    }

    private var stringArrayBinding: Binding<[String]> {
        Binding(
            get: { arrayItems.compactMap(\.asString) },
            set: { fieldBinding.wrappedValue = .array($0.map(FieldValue.string)) }
        )
    }

    private func primitiveStringBinding(at index: Int) -> Binding<String> {
        Binding(
            get: {
                let items = arrayItems
                guard items.indices.contains(index) else { return "" }
                return items[index].asString ?? ""
            },
            set: { updatePrimitiveArrayValue(at: index, value: .string($0)) }
        )
    }

    private func primitiveNumberBinding(at index: Int) -> Binding<Double> {
        Binding(
            get: {
                let items = arrayItems
                guard items.indices.contains(index) else { return 0 }
                return items[index].asNumber ?? 0
            },
            set: { updatePrimitiveArrayValue(at: index, value: .number($0)) }
        )
    }

    private func primitiveBoolBinding(at index: Int) -> Binding<Bool> {
        Binding(
            get: {
                let items = arrayItems
                guard items.indices.contains(index) else { return false }
                return items[index].asBool ?? false
            },
            set: { updatePrimitiveArrayValue(at: index, value: .bool($0)) }
        )
    }

    private func primitiveDateBinding(at index: Int) -> Binding<Date> {
        Binding(
            get: {
                let items = arrayItems
                guard items.indices.contains(index) else { return .now }
                return items[index].asDate ?? .now
            },
            set: { updatePrimitiveArrayValue(at: index, value: .date($0)) }
        )
    }

    private func updatePrimitiveArrayValue(at index: Int, value: FieldValue) {
        var items = arrayItems
        while items.count <= index {
            items.append(.null)
        }
        items[index] = value
        fieldBinding.wrappedValue = .array(items)
    }

    private func defaultPrimitiveValue(for kind: FieldKind) -> FieldValue {
        switch kind {
        case .string, .richText, .enumeration:
            return .string("")
        case .number:
            return .number(0)
        case .bool:
            return .bool(false)
        case .color:
            return .color("#000000")
        case .date:
            return .date(.now)
        case .image:
            return .image("")
        case .array, .record, .file:
            return .null
        }
    }

    private func stringValue(_ raw: String) -> FieldValue {
        switch field.kind {
        case .color:
            return .color(raw)
        case .image:
            return .image(raw)
        default:
            return .string(raw)
        }
    }
}
