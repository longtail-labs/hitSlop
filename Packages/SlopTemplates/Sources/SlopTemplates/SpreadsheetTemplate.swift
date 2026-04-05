import Foundation
import SwiftUI
import SlopKit
import SwiftCSV

// MARK: - Data Model

@SlopData
public struct SpreadsheetData {
    @SlopKit.Section("Document") @Field("Title") var title: String = "Untitled Spreadsheet"
}

// MARK: - CSV Parsing

private struct CSVTable {
    var headers: [String]
    var rows: [[String]]

    init(csvString: String) {
        guard !csvString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            self.headers = ["A", "B", "C", "D", "E"]
            self.rows = Array(repeating: ["", "", "", "", ""], count: 10)
            return
        }

        do {
            let csv = try CSV<Named>(string: csvString)
            let parsedHeaders = csv.header.isEmpty ? ["A", "B", "C"] : csv.header
            let parsedRows = csv.rows.map { row in
                parsedHeaders.map { row[$0] ?? "" }
            }
            self.headers = parsedHeaders
            self.rows = parsedRows.isEmpty ? [Array(repeating: "", count: parsedHeaders.count)] : parsedRows
        } catch {
            self.headers = ["A", "B", "C"]
            self.rows = [["", "", ""]]
        }
    }

    func toCSV() -> String {
        let escapedHeaders = headers.map { escapeCSVField($0) }
        var lines = [escapedHeaders.joined(separator: ",")]
        for row in rows {
            let escapedRow = row.map { escapeCSVField($0) }
            lines.append(escapedRow.joined(separator: ","))
        }
        return lines.joined(separator: "\n")
    }

    private func escapeCSVField(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return field
    }
}

// MARK: - Template View

struct SpreadsheetView: View {
    @TemplateData var data: SpreadsheetData
    @SidecarContent var content: String
    @Environment(\.slopTheme) private var theme
    @State private var editingCell: (row: Int, col: Int)?
    @State private var hoveredRow: Int?

    init(store: RawTemplateStore, sidecarStore: SidecarStore) {
        self._data = TemplateState(store: store)
        self._content = SidecarContent(key: "content", store: sidecarStore)
    }

    private var table: CSVTable {
        CSVTable(csvString: content)
    }

    var body: some View {
        SlopContent {
            VStack(alignment: .leading, spacing: 0) {
                // Title bar
                SlopTextField("Title", text: $data.title)
                    .font(theme.font(size: 18, weight: .bold))
                    .foregroundStyle(theme.foreground)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 8)

                Divider().background(theme.divider)

                // Spreadsheet grid
                SlopEditable($content) { value in
                    staticTable(for: CSVTable(csvString: value))
                } editor: { binding in
                    editableTable(binding: binding)
                }
            }
        }
        .background(theme.background)
    }

    @ViewBuilder
    private func staticTable(for table: CSVTable) -> some View {
        ScrollView([.horizontal, .vertical]) {
            Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
                // Header row
                GridRow {
                    ForEach(Array(table.headers.enumerated()), id: \.offset) { _, header in
                        Text(header)
                            .font(theme.mono(size: 11, weight: .semibold))
                            .foregroundStyle(theme.foreground)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .frame(minWidth: 80, alignment: .leading)
                            .background(theme.secondary.opacity(0.15))
                    }
                }

                Divider()

                // Data rows
                ForEach(Array(table.rows.enumerated()), id: \.offset) { _, row in
                    GridRow {
                        ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                            Text(cell)
                                .font(theme.mono(size: 11))
                                .foregroundStyle(theme.foreground)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .frame(minWidth: 80, alignment: .leading)
                        }
                    }
                }
            }
            .padding(8)
        }
    }

    @ViewBuilder
    private func editableTable(binding: Binding<String>) -> some View {
        let currentTable = CSVTable(csvString: binding.wrappedValue)

        VStack(spacing: 0) {
            ScrollView([.horizontal, .vertical]) {
                Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
                    // Header row
                    GridRow {
                        Text("")
                            .frame(width: 30)

                        ForEach(Array(currentTable.headers.enumerated()), id: \.offset) { colIdx, header in
                            headerCell(header, column: colIdx, table: currentTable, binding: binding)
                        }
                    }

                    Divider()

                    // Data rows
                    ForEach(Array(currentTable.rows.enumerated()), id: \.offset) { rowIdx, row in
                        GridRow {
                            // Row number with hover delete
                            ZStack {
                                if hoveredRow == rowIdx {
                                    Button {
                                        removeRow(at: rowIdx, table: currentTable, binding: binding)
                                    } label: {
                                        Image(systemName: "minus.circle.fill")
                                            .font(theme.font(size: 11))
                                            .foregroundStyle(.red.opacity(0.7))
                                    }
                                    .buttonStyle(.plain)
                                } else {
                                    Text("\(rowIdx + 1)")
                                        .font(theme.mono(size: 10))
                                        .foregroundStyle(theme.secondary)
                                }
                            }
                            .frame(width: 30)
                            .onHover { hovering in
                                hoveredRow = hovering ? rowIdx : nil
                            }

                            ForEach(Array(row.enumerated()), id: \.offset) { colIdx, cell in
                                editableCell(cell, row: rowIdx, col: colIdx, table: currentTable, binding: binding)
                            }
                        }
                    }
                }
                .padding(8)
            }

            // Toolbar
            Divider().background(theme.divider)
            HStack(spacing: 12) {
                Button(action: { addRow(table: currentTable, binding: binding) }) {
                    Label("Add Row", systemImage: "plus")
                        .font(theme.font(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundStyle(theme.accent)

                Button(action: { addColumn(table: currentTable, binding: binding) }) {
                    Label("Add Column", systemImage: "plus.rectangle.on.rectangle")
                        .font(theme.font(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundStyle(theme.accent)

                Spacer()

                if currentTable.rows.count > 1 {
                    Button(action: { removeLastRow(table: currentTable, binding: binding) }) {
                        Label("Remove Row", systemImage: "minus")
                            .font(theme.font(size: 11))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private func headerCell(_ header: String, column: Int, table: CSVTable, binding: Binding<String>) -> some View {
        TextField("Column", text: Binding(
            get: { header },
            set: { newValue in
                var updated = table
                updated.headers[column] = newValue
                binding.wrappedValue = updated.toCSV()
            }
        ))
        .font(theme.mono(size: 11, weight: .semibold))
        .foregroundStyle(theme.foreground)
        .textFieldStyle(.plain)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(minWidth: 80, alignment: .leading)
        .background(theme.secondary.opacity(0.15))
    }

    @ViewBuilder
    private func editableCell(_ cell: String, row: Int, col: Int, table: CSVTable, binding: Binding<String>) -> some View {
        TextField("", text: Binding(
            get: { cell },
            set: { newValue in
                var updated = table
                // Ensure row exists
                while updated.rows.count <= row {
                    updated.rows.append(Array(repeating: "", count: updated.headers.count))
                }
                // Ensure column exists
                while updated.rows[row].count <= col {
                    updated.rows[row].append("")
                }
                updated.rows[row][col] = newValue
                binding.wrappedValue = updated.toCSV()
            }
        ))
        .font(theme.mono(size: 11))
        .foregroundStyle(theme.foreground)
        .textFieldStyle(.plain)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .frame(minWidth: 80, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 2)
                .stroke(theme.divider, lineWidth: 0.5)
        )
    }

    private func addRow(table: CSVTable, binding: Binding<String>) {
        var updated = table
        updated.rows.append(Array(repeating: "", count: updated.headers.count))
        binding.wrappedValue = updated.toCSV()
    }

    private func addColumn(table: CSVTable, binding: Binding<String>) {
        var updated = table
        let colName = columnName(for: updated.headers.count)
        updated.headers.append(colName)
        for i in 0..<updated.rows.count {
            updated.rows[i].append("")
        }
        binding.wrappedValue = updated.toCSV()
    }

    private func removeRow(at index: Int, table: CSVTable, binding: Binding<String>) {
        guard table.rows.count > 1, table.rows.indices.contains(index) else { return }
        var updated = table
        updated.rows.remove(at: index)
        binding.wrappedValue = updated.toCSV()
        hoveredRow = nil
    }

    private func removeLastRow(table: CSVTable, binding: Binding<String>) {
        guard table.rows.count > 1 else { return }
        var updated = table
        updated.rows.removeLast()
        binding.wrappedValue = updated.toCSV()
    }

    private func columnName(for index: Int) -> String {
        // A, B, C, ... Z, AA, AB, ...
        var name = ""
        var n = index
        repeat {
            name = String(UnicodeScalar(65 + n % 26)!) + name
            n = n / 26 - 1
        } while n >= 0
        return name
    }
}

// MARK: - Template Class (manual — needs sidecar store)

public final class SpreadsheetView_SlopTemplate: AnySlopTemplate {
    public static let templateID = "com.hitslop.templates.spreadsheet"
    public static let name = "Spreadsheet"
    public static let templateDescription: String? = "Edit lightweight CSV-style tables in a compact spreadsheet window."
    public static let version = "1.0.0"
    public static let minimumHostVersion = "1.0.0"
    public static let schema: Schema = {
        var sections = SpreadsheetData.schema.sections
        sections.append(SchemaSection("Content", fields: [
            FieldDescriptor(
                key: "content",
                label: "Content",
                kind: .file,
                required: false,
                defaultValue: .null,
                fileDescriptor: FileFieldDescriptor(
                    fileExtension: "csv",
                    mimeType: "text/csv",
                    isText: true,
                    defaultFilename: "content.csv"
                )
            )
        ]))
        return Schema(sections: sections)
    }()
    public static let metadata = TemplateMetadata(
        width: 640,
        height: 480,
        minSize: CGSize(width: 400, height: 300),
        windowShape: .roundedRect(radius: 16),
        theme: nil,
        alwaysOnTop: true,
        titleBarHidden: true,
        categories: ["popular", "work"]
    )

    private let store: RawTemplateStore
    private let sidecar: SidecarStore

    public init(rawStore: RawTemplateStore) {
        self.store = rawStore
        self.sidecar = SidecarStore()
    }

    public init(rawStore: RawTemplateStore, sidecarStore: SidecarStore) {
        self.store = rawStore
        self.sidecar = sidecarStore
    }

    @MainActor
    public func body() -> AnyView {
        AnyView(SpreadsheetView(store: store, sidecarStore: sidecar))
    }
}

@objc(SpreadsheetView_EntryPoint)
public final class SpreadsheetView_EntryPoint: SlopTemplateEntryPoint {
    @objc override public class func templateType() -> AnyObject.Type {
        SpreadsheetView_SlopTemplate.self
    }
}
