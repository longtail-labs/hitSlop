import SwiftUI
import AppKit
import UniformTypeIdentifiers
@_spi(TemplatePicker) import SlopUI

// MARK: - Data Model

struct TemplateInfo: Identifiable {
    let id: String
    let templateID: String
    let templateVersion: String
    let name: String
    let templateDescription: String?
    let schema: Schema
    let metadata: TemplateMetadata
    let previewURL: URL?
    let rawCategories: [String]

    var categories: [TemplateCategoryCatalog.Entry] {
        rawCategories.map { TemplateCategoryCatalog.entry(for: $0) }
    }

    var category: TemplateCategoryCatalog.Entry {
        categories.first ?? TemplateCategoryCatalog.entry(for: nil)
    }

    var previewAspectRatio: CGFloat {
        TemplatePickerSupport.previewAspectRatio(for: metadata)
    }

    var categoryDisplayName: String? {
        rawCategories.isEmpty ? nil : category.label
    }

    var canvasSizeText: String {
        "\(Int(metadata.width.rounded())) × \(Int(metadata.height.rounded()))"
    }

    var versionLabel: String {
        "v\(templateVersion)"
    }

    var themeLabel: String? {
        ThemeCatalog.resolve(metadata.theme)?.displayName
    }

    var heroDescription: String {
        if let templateDescription, !templateDescription.isEmpty {
            return templateDescription
        }

        return previewURL == nil ? "Template preview unavailable." : "Real preview, uncropped."
    }

    func matches(searchText: String) -> Bool {
        let query = searchText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard !query.isEmpty else { return true }

        let haystack = ([
            name,
            templateDescription ?? "",
            themeLabel ?? "",
        ] + rawCategories + categories.map(\.label))
            .joined(separator: " ")
            .lowercased()

        return haystack.contains(query)
    }
}

// MARK: - Picker Window Factory

func makePickerWindow(delegate: AppDelegate) -> NSWindow {
    let view = TemplatePickerView(delegate: delegate)

    let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 1120, height: 640),
        styleMask: [.titled, .closable, .resizable, .miniaturizable],
        backing: .buffered,
        defer: false
    )
    window.title = "Choose a Template"
    window.minSize = NSSize(width: 920, height: 520)
    window.contentView = NSHostingView(rootView: view)
    window.center()
    window.isReleasedWhenClosed = false
    window.isRestorable = false
    window.backgroundColor = NSColor(red: 0.09, green: 0.09, blue: 0.09, alpha: 1)

    return window
}

// MARK: - Sidebar Selection

private enum SidebarSelection: Hashable {
    case all
    case recents
    case category(String)
}

private struct TemplateGroup: Identifiable {
    let category: TemplateCategoryCatalog.Entry
    let templates: [TemplateInfo]

    var id: String { category.id }
}

private struct PickerPalette {
    let background = Color(red: 0.09, green: 0.09, blue: 0.09)
    let sidebar = Color(red: 0.07, green: 0.07, blue: 0.07)
    let browser = Color(red: 0.10, green: 0.10, blue: 0.10)
    let hero = Color(red: 0.08, green: 0.08, blue: 0.08)
    let surface = Color.white.opacity(0.035)
    let elevated = Color.white.opacity(0.06)
    let border = Color.white.opacity(0.08)
    let muted = Color.white.opacity(0.52)
    let faint = Color.white.opacity(0.28)
    let accent = PickerBranding.accent
    let stage = Color(red: 0.14, green: 0.14, blue: 0.14)
}

// MARK: - Picker View

private struct TemplatePickerView: View {
    let delegate: AppDelegate

    @State private var allTemplates: [TemplateInfo] = []
    @State private var recentTemplateInfos: [TemplateInfo] = []
    @State private var selection: SidebarSelection = .all
    @State private var selectedTemplateID: String?
    @State private var searchText = ""

    private let palette = PickerPalette()

    private var categoryEntries: [TemplateCategoryCatalog.Entry] {
        TemplateCategoryCatalog.sorted(allTemplates.flatMap(\.rawCategories))
    }

    private var baseTemplates: [TemplateInfo] {
        switch selection {
        case .all:
            return allTemplates
        case .recents:
            return recentTemplateInfos
        case .category(let categoryID):
            return allTemplates.filter { $0.categories.contains { $0.id == categoryID } }
        }
    }

    private var visibleTemplates: [TemplateInfo] {
        baseTemplates.filter { $0.matches(searchText: searchText) }
    }

    private var groupedVisibleTemplates: [TemplateGroup] {
        let grouped = Dictionary(grouping: visibleTemplates, by: { $0.category.id })
        return categoryEntries.compactMap { category in
            guard let templates = grouped[category.id], !templates.isEmpty else {
                return nil
            }
            return TemplateGroup(
                category: category,
                templates: templates.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            )
        }
    }

    private var selectedTemplate: TemplateInfo? {
        guard let selectedTemplateID = TemplatePickerSupport.resolvedSelection(
            currentSelectionID: selectedTemplateID,
            visibleTemplateIDs: visibleTemplates.map(\.id)
        ) else {
            return nil
        }

        return visibleTemplates.first { $0.id == selectedTemplateID }
    }

    private var selectionTitle: String {
        switch selection {
        case .all:
            return "All Templates"
        case .recents:
            return "Recent Documents"
        case .category(let categoryID):
            return TemplateCategoryCatalog.entry(for: categoryID).label
        }
    }

    private var selectionSummary: String {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            switch selection {
            case .all:
                return "Browse the full built-in catalog."
            case .recents:
                return "Open something you were already working on."
            case .category(let categoryID):
                return TemplateCategoryCatalog.entry(for: categoryID).summary
            }
        }

        return "\(visibleTemplates.count) matching templates."
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                TemplatePickerSidebar(
                    palette: palette,
                    selection: $selection,
                    categoryEntries: categoryEntries,
                    countForSelection: count(for:)
                )

                Divider().background(palette.border)

                TemplateBrowserPanel(
                    palette: palette,
                    selectionTitle: selectionTitle,
                    selectionSummary: selectionSummary,
                    searchText: $searchText,
                    selection: selection,
                    visibleTemplates: visibleTemplates,
                    groupedTemplates: groupedVisibleTemplates,
                    selectedTemplateID: $selectedTemplateID,
                    onSelect: { template in
                        selectedTemplateID = template.id
                    },
                    onOpen: { template in
                        selectedTemplateID = template.id
                        openSelected(template)
                    }
                )

                Divider().background(palette.border)

                TemplateHeroPanel(
                    palette: palette,
                    template: selectedTemplate,
                    selectionSummary: selectionSummary
                )
            }

            Divider().background(palette.border)

            bottomBar
        }
        .background(palette.background)
        .task {
            allTemplates = loadTemplates()
            recentTemplateInfos = loadRecentTemplates()
            syncSelection()
        }
        .onChange(of: selection) { _, newSelection in
            if newSelection == .recents {
                recentTemplateInfos = loadRecentTemplates()
            }
            syncSelection()
        }
        .onChange(of: searchText) { _, _ in
            syncSelection()
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack {
            Button("Open Existing\u{2026}") {
                openExistingFile()
            }
            .buttonStyle(.bordered)

            Spacer()

            if let template = selectedTemplate {
                Text(template.templateID)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(palette.faint)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            Button("Choose") {
                if let template = selectedTemplate {
                    openSelected(template)
                }
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(selectedTemplate == nil)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(palette.background)
    }

    // MARK: - Data & Actions

    private func count(for selection: SidebarSelection) -> Int {
        switch selection {
        case .all:
            return allTemplates.count
        case .recents:
            return recentTemplateInfos.count
        case .category(let categoryID):
            return allTemplates.filter { $0.categories.contains { $0.id == categoryID } }.count
        }
    }

    private func loadTemplates() -> [TemplateInfo] {
        delegate.templateRegistry.entries
            .map(makeTemplateInfo)
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func loadRecentTemplates() -> [TemplateInfo] {
        delegate.recentURLs.compactMap { url in
            guard let envelope = try? SlopFile.loadEnvelope(from: url),
                  let entry = delegate.templateRegistry.resolve(
                    templateID: envelope.templateID,
                    version: envelope.templateVersion
                  )
            else { return nil }

            var info = makeTemplateInfo(entry)
            let recentPreviewURL = SlopPreviewAssetResolver.resolvePreviewURL(for: url) ?? info.previewURL
            info = TemplateInfo(
                id: url.path,
                templateID: info.templateID,
                templateVersion: info.templateVersion,
                name: url.deletingPathExtension().lastPathComponent,
                templateDescription: info.templateDescription,
                schema: info.schema,
                metadata: info.metadata,
                previewURL: recentPreviewURL,
                rawCategories: info.rawCategories
            )
            return info
        }
    }

    private func makeTemplateInfo(_ entry: SlopTemplateRegistry.Entry) -> TemplateInfo {
        let previewURL = entry.previewURL
            ?? SlopTemplatePreviewCache.previewURL(
                for: entry.manifest.id,
                version: entry.manifest.version
            )
        let resolvedPreview: URL? = FileManager.default.fileExists(atPath: previewURL.path)
            ? previewURL : nil

        return TemplateInfo(
            id: entry.id,
            templateID: entry.manifest.id,
            templateVersion: entry.manifest.version,
            name: entry.manifest.name,
            templateDescription: entry.manifest.description,
            schema: entry.manifest.schema,
            metadata: entry.manifest.metadata,
            previewURL: resolvedPreview,
            rawCategories: entry.manifest.metadata.categories
        )
    }

    private func syncSelection() {
        selectedTemplateID = TemplatePickerSupport.resolvedSelection(
            currentSelectionID: selectedTemplateID,
            visibleTemplateIDs: visibleTemplates.map(\.id)
        )
    }

    private func openSelected(_ template: TemplateInfo) {
        if selection == .recents {
            let url = URL(fileURLWithPath: template.id)
            delegate.openTemplate(url)
            delegate.pickerWindow?.close()
            return
        }
        saveAndOpen(template)
    }

    private func saveAndOpen(_ template: TemplateInfo) {
        let panel = NSSavePanel()
        let baseName = template.name
            .replacingOccurrences(of: " ", with: "-")
            .lowercased()
        panel.nameFieldStringValue = baseName + ".slop"
        panel.canCreateDirectories = true
        panel.prompt = "Create"

        guard panel.runModal() == .OK, var destURL = panel.url else { return }

        if destURL.pathExtension != "slop" {
            destURL = destURL.appendingPathExtension("slop")
        }

        do {
            let slopFile = SlopFile(
                templateID: template.templateID,
                templateVersion: template.templateVersion,
                data: template.schema.defaultValues()
            )
            let data = try slopFile.encodedData(schema: template.schema)
            try SlopFile.writePackage(at: destURL, data: data, schema: template.schema)

            delegate.openTemplate(destURL)
            delegate.pickerWindow?.close()
        } catch {
            showError("Failed to create document", error)
        }
    }

    private func openExistingFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.treatsFilePackagesAsDirectories = false
        if let slopType = UTType(filenameExtension: "slop") {
            panel.allowedContentTypes = [slopType]
        }
        if panel.runModal() == .OK, let url = panel.url {
            delegate.openTemplate(url)
            delegate.pickerWindow?.close()
        }
    }

    private func showError(_ message: String, _ error: Error) {
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = error.localizedDescription
        alert.runModal()
    }
}

// MARK: - Sidebar

private struct TemplatePickerSidebar: View {
    let palette: PickerPalette
    @Binding var selection: SidebarSelection
    let categoryEntries: [TemplateCategoryCatalog.Entry]
    let countForSelection: (SidebarSelection) -> Int

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 36, height: 36)

                Text("hitSlop")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 18)

            sidebarRow(
                selection: .all,
                icon: "square.grid.2x2",
                title: "All Templates",
                count: countForSelection(.all)
            )

            sidebarRow(
                selection: .recents,
                icon: "clock.arrow.circlepath",
                title: "Recents",
                count: countForSelection(.recents)
            )

            if !categoryEntries.isEmpty {
                Text("Collections")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.9)
                    .foregroundStyle(palette.faint)
                    .padding(.horizontal, 18)
                    .padding(.top, 18)
                    .padding(.bottom, 8)

                ForEach(categoryEntries) { category in
                    sidebarRow(
                        selection: .category(category.id),
                        icon: category.icon,
                        title: category.label,
                        count: countForSelection(.category(category.id))
                    )
                }
            }

            Spacer(minLength: 0)
        }
        .frame(width: 220)
        .background(
            LinearGradient(
                colors: [palette.sidebar, palette.sidebar.opacity(0.92)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private func sidebarRow(
        selection rowSelection: SidebarSelection,
        icon: String,
        title: String,
        count: Int
    ) -> some View {
        let isActive = selection == rowSelection

        return Button {
            selection = rowSelection
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 18)

                Text(title)
                    .font(.system(size: 13, weight: isActive ? .semibold : .regular))

                Spacer(minLength: 0)

                Text("\(count)")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(isActive ? .white.opacity(0.9) : palette.faint)
            }
            .foregroundStyle(isActive ? .white : palette.muted)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isActive ? palette.elevated : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isActive ? palette.border : Color.clear, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 10)
        .padding(.vertical, 1)
    }
}

// MARK: - Browser

private struct TemplateBrowserPanel: View {
    let palette: PickerPalette
    let selectionTitle: String
    let selectionSummary: String
    @Binding var searchText: String
    let selection: SidebarSelection
    let visibleTemplates: [TemplateInfo]
    let groupedTemplates: [TemplateGroup]
    @Binding var selectedTemplateID: String?
    let onSelect: (TemplateInfo) -> Void
    let onOpen: (TemplateInfo) -> Void

    private let columns = [
        GridItem(.flexible(minimum: 180, maximum: 260), spacing: 12),
        GridItem(.flexible(minimum: 180, maximum: 260), spacing: 12),
    ]

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider().background(palette.border)

            Group {
                if visibleTemplates.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        if selection == .all {
                            LazyVStack(alignment: .leading, spacing: 22) {
                                ForEach(groupedTemplates) { group in
                                    VStack(alignment: .leading, spacing: 12) {
                                        HStack(spacing: 8) {
                                            Image(systemName: group.category.icon)
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundStyle(palette.accent)
                                            Text(group.category.label)
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundStyle(.white)
                                            Text("\(group.templates.count)")
                                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                                .foregroundStyle(palette.faint)
                                        }

                                        LazyVGrid(columns: columns, spacing: 12) {
                                            ForEach(group.templates) { template in
                                                TemplateCardView(
                                                    palette: palette,
                                                    template: template,
                                                    isSelected: selectedTemplateID == template.id,
                                                    onSelect: { onSelect(template) },
                                                    onOpen: { onOpen(template) }
                                                )
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(18)
                        } else {
                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(visibleTemplates) { template in
                                    TemplateCardView(
                                        palette: palette,
                                        template: template,
                                        isSelected: selectedTemplateID == template.id,
                                        onSelect: { onSelect(template) },
                                        onOpen: { onOpen(template) }
                                    )
                                }
                            }
                            .padding(18)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(palette.browser)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(selectionTitle)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(selectionSummary)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(palette.muted)
                }

                Spacer()

                Text("\(visibleTemplates.count)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(palette.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule(style: .continuous)
                            .fill(palette.surface)
                    )
            }

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(palette.faint)

                TextField("Search templates, themes, or categories", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(palette.faint)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(palette.border, lineWidth: 1)
            )
        }
        .padding(18)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: selection == .recents ? "clock.arrow.circlepath" : "magnifyingglass")
                .font(.system(size: 34))
                .foregroundStyle(palette.faint)

            Text(selection == .recents ? "No recent documents yet" : "No templates match that search")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.78))

            Text(selection == .recents ? "Open or create a few documents and they’ll appear here." : "Try a broader query or switch categories.")
                .font(.system(size: 13))
                .foregroundStyle(palette.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }
}

private struct TemplateCardView: View {
    let palette: PickerPalette
    let template: TemplateInfo
    let isSelected: Bool
    let onSelect: () -> Void
    let onOpen: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TemplatePreviewSurface(
                info: template,
                stageSurface: palette.stage,
                cornerRadius: 14,
                contentInset: 6,
                placeholderIconSize: 20,
                placeholderTitleSize: 10
            )
            .aspectRatio(template.previewAspectRatio, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 118, maxHeight: 168)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(template.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    Text(template.versionLabel)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(palette.faint)
                }

                if let description = template.templateDescription, !description.isEmpty {
                    Text(description)
                        .font(.system(size: 11))
                        .foregroundStyle(palette.muted)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 6) {
                    cardPill(template.category.label, icon: template.category.icon)
                    cardPill(template.canvasSizeText, icon: "aspectratio")
                }

                if let themeLabel = template.themeLabel {
                    Text(themeLabel.uppercased())
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(0.8)
                        .foregroundStyle(palette.faint)
                        .lineLimit(1)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isSelected ? palette.accent.opacity(0.10) : palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isSelected ? AnyShapeStyle(PickerBranding.accentGradient) : AnyShapeStyle(palette.border.opacity(0.6)), lineWidth: isSelected ? 1.5 : 1)
        )
        .shadow(color: (isSelected ? palette.accent.opacity(0.15) : .black.opacity(0.08)), radius: isSelected ? 12 : 8, y: 6)
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onTapGesture(count: 2, perform: onOpen)
        .onTapGesture(count: 1, perform: onSelect)
    }

    private func cardPill(_ text: String, icon: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .bold))
            Text(text)
                .font(.system(size: 10, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundStyle(.white.opacity(0.74))
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
    }
}

// MARK: - Hero

private struct TemplateHeroPanel: View {
    let palette: PickerPalette
    let template: TemplateInfo?
    let selectionSummary: String

    var body: some View {
        Group {
            if let template {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: template.category.icon)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(palette.accent)
                                Text(template.category.label.uppercased())
                                    .font(.system(size: 11, weight: .semibold))
                                    .tracking(1.0)
                                    .foregroundStyle(palette.faint)
                            }

                            Text(template.name)
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .fixedSize(horizontal: false, vertical: true)

                            Text(template.heroDescription)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white.opacity(0.82))
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        TemplatePreviewSurface(
                            info: template,
                            stageSurface: palette.stage,
                            cornerRadius: 24,
                            contentInset: 10,
                            placeholderIconSize: 34,
                            placeholderTitleSize: 13
                        )
                        .aspectRatio(template.previewAspectRatio, contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .fill(palette.surface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .stroke(palette.border, lineWidth: 1)
                        )

                        VStack(alignment: .leading, spacing: 12) {
                            heroMetric("Canvas", value: template.canvasSizeText)
                            heroMetric("Version", value: template.versionLabel)
                            if let themeLabel = template.themeLabel {
                                heroMetric("Theme", value: themeLabel)
                            }
                            heroMetric("Collection", value: template.category.label)
                        }

                    }
                    .padding(22)
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "rectangle.stack.badge.plus")
                        .font(.system(size: 34))
                        .foregroundStyle(palette.faint)

                    Text("Select a template")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.82))

                    Text(selectionSummary)
                        .font(.system(size: 13))
                        .foregroundStyle(palette.muted)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(32)
            }
        }
        .frame(width: 340)
        .background(
            LinearGradient(
                colors: [palette.hero, palette.hero.opacity(0.92)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private func heroMetric(_ label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(palette.faint)
                .frame(width: 72, alignment: .leading)

            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.84))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Preview Surface

private struct TemplatePreviewSurface: View {
    let info: TemplateInfo
    let stageSurface: Color
    let cornerRadius: CGFloat
    let contentInset: CGFloat
    let placeholderIconSize: CGFloat
    let placeholderTitleSize: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(stageSurface)

            if let previewURL = info.previewURL,
               let nsImage = NSImage(contentsOf: previewURL) {
                Image(nsImage: nsImage)
                    .resizable()
                    .interpolation(.high)
                    .antialiased(true)
                    .scaledToFit()
                    .padding(contentInset)
            } else {
                VStack(spacing: placeholderTitleSize > 0 ? 10 : 0) {
                    Image(systemName: info.category.icon)
                        .font(.system(size: placeholderIconSize))
                        .foregroundColor(Color.white.opacity(0.28))
                    if placeholderTitleSize > 0 {
                        Text(info.name)
                            .font(.system(size: placeholderTitleSize, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.45))
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(placeholderTitleSize > 0 ? 20 : 4)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}
