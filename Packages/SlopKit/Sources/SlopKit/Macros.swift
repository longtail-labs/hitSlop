import Foundation

// MARK: - Macro Declarations

/// Generates TemplateDataProtocol conformance for a data struct.
/// Adds: static schema, init(from:), toFieldValues().
/// Use on both top-level template data structs and nested record types.
@attached(extension, conformances: TemplateDataProtocol, names: named(schema), named(init(from:)), named(toFieldValues))
@attached(member, names: named(init))
@attached(memberAttribute)
public macro SlopData() = #externalMacro(module: "SlopMacros", type: "SlopDataMacro")

/// Unified template macro — annotate a View struct to generate AnySlopTemplate class + entry point.
///
/// Replaces the manual boilerplate of: template class, root view, and @objc entry point.
///
/// ```swift
/// @SlopTemplate(
///     id: "com.hitslop.templates.budget-tracker",
///     name: "Budget Tracker",
///     description: "Track income, spending, and category totals at a glance.",
///     version: "2.0.0",
///     width: 360, height: 600,
///     shape: .roundedRect(radius: 16),
///     theme: "rose",
///     categories: ["finance"]
/// )
/// struct BudgetView: View {
///     @TemplateData var data: BudgetData
///     var body: some View { ... }
/// }
/// ```
///
/// Generates:
/// - `BudgetView_SlopTemplate` class conforming to `AnySlopTemplate`
/// - `BudgetView_EntryPoint` class subclassing `SlopTemplateEntryPoint`
/// - `init(store:)` injected into the view struct
@attached(peer, names: suffixed(_SlopTemplate), suffixed(_EntryPoint))
@attached(member, names: named(init))
public macro SlopTemplate(
    id: String,
    name: String,
    description: String? = nil,
    version: String = "1.0.0",
    minimumHostVersion: String = "1.0.0",
    width: CGFloat = 400,
    height: CGFloat = 600,
    minWidth: CGFloat? = nil,
    minHeight: CGFloat? = nil,
    shape: WindowShape = .roundedRect(radius: 16),
    theme: String? = nil,
    alwaysOnTop: Bool = true,
    titleBarHidden: Bool = true,
    categories: [String] = []
) = #externalMacro(module: "SlopMacros", type: "SlopTemplateMacro")

// MARK: - Property Wrappers

/// Marks a property as a template field with a human-readable title.
/// Used by the @SlopData macro to generate schema and serialization.
@propertyWrapper
public struct Field<Value>: @unchecked Sendable {
    public var wrappedValue: Value
    public let label: String
    public let constraints: [Constraint]
    public let options: [String]?
    public let hint: String?
    public let editor: FieldEditor

    public init(
        wrappedValue: Value,
        _ label: String,
        constraints: [Constraint] = [],
        options: [String]? = nil,
        hint: String? = nil,
        editor: FieldEditor = .automatic
    ) {
        self.wrappedValue = wrappedValue
        self.label = label
        self.constraints = constraints
        self.options = options
        self.hint = hint
        self.editor = editor
    }

    /// Convenience for enum-like fields with predefined options.
    public init(
        wrappedValue: Value,
        _ label: String,
        options: [String],
        hint: String? = nil,
        editor: FieldEditor = .enumeration
    ) {
        self.wrappedValue = wrappedValue
        self.label = label
        self.constraints = []
        self.options = options
        self.hint = hint
        self.editor = editor
    }

    /// Convenience for fields with a single constraint.
    public init(
        wrappedValue: Value,
        _ label: String,
        _ constraint: Constraint,
        hint: String? = nil,
        editor: FieldEditor = .automatic
    ) {
        self.wrappedValue = wrappedValue
        self.label = label
        self.constraints = [constraint]
        self.options = nil
        self.hint = hint
        self.editor = editor
    }
}

/// Groups fields under a section header in the inspector.
/// Attach to the first field in a section.
@propertyWrapper
public struct Section<Value>: @unchecked Sendable {
    public var wrappedValue: Value

    public init(wrappedValue: Value, _ title: String) {
        self.wrappedValue = wrappedValue
    }
}
