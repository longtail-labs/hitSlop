import Foundation

/// All IPC method names for the slop CLI protocol.
public enum SlopMethod: String, CaseIterable, Sendable {
    case status = "status"
    case templateList = "template.list"
    case templateSchema = "template.schema"
    case themeList = "theme.list"
    case themeWrite = "theme.write"
    case themeDerive = "theme.derive"
    case themeDelete = "theme.delete"
    case themeValidate = "theme.validate"
    case documentCreate = "document.create"
    case documentRead = "document.read"
    case documentWrite = "document.write"
    case documentValidate = "document.validate"
    case documentInfo = "document.info"
    case documentOpen = "document.open"
    case documentExport = "document.export"
    case documentSetTheme = "document.setTheme"
    case documentSetShape = "document.setShape"
    case recentsList = "recents.list"
    case recentsClear = "recents.clear"
    case pickerShow = "picker.show"
}
