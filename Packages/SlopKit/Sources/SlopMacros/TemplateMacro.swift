import Foundation
import SwiftSyntax
import SwiftSyntaxMacros

/// Implementation of the @SlopData macro.
/// Generates TemplateDataProtocol conformance: schema, init(from:), toFieldValues().
public struct SlopDataMacro {}

func attributeBaseName(_ attribute: AttributeSyntax) -> String? {
    if let identType = attribute.attributeName.as(IdentifierTypeSyntax.self) {
        return identType.name.text
    }
    if let memberType = attribute.attributeName.as(MemberTypeSyntax.self) {
        return memberType.name.text
    }
    return nil
}

// MARK: - Shared Helpers

struct FieldInfo {
    let name: String
    let label: String
    let typeName: String
    let isOptional: Bool
    let defaultExpr: String?
    let constraintsExpr: String
    let optionsExpr: String?
    let hintExpr: String?
    let editorExpr: String?
    let sectionTitle: String?
    let isArray: Bool
    let arrayElementType: String?
}

func extractFields(from members: MemberBlockItemListSyntax) -> [FieldInfo] {
    var fields: [FieldInfo] = []
    var currentSection: String?

    for member in members {
        guard let varDecl = member.decl.as(VariableDeclSyntax.self),
              let binding = varDecl.bindings.first,
              let pattern = binding.pattern.as(IdentifierPatternSyntax.self)
        else { continue }

        if binding.accessorBlock != nil { continue }

        let propertyName = pattern.identifier.text

        for attr in varDecl.attributes {
            guard let attrSyntax = attr.as(AttributeSyntax.self)
            else { continue }

            if attributeBaseName(attrSyntax) == "Section",
               let args = attrSyntax.arguments?.as(LabeledExprListSyntax.self),
               let firstArg = args.first {
                currentSection = firstArg.expression.description
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            }
        }

        var label: String?
        var constraintsExpr = "[]"
        var optionsExpr: String?
        var hintExpr: String?
        var editorExpr: String?

        for attr in varDecl.attributes {
            guard let attrSyntax = attr.as(AttributeSyntax.self),
                  attributeBaseName(attrSyntax) == "Field",
                  let args = attrSyntax.arguments?.as(LabeledExprListSyntax.self)
            else { continue }

            if let firstArg = args.first {
                label = firstArg.expression.description
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            }

            for arg in args {
                switch arg.label?.text {
                case "constraints":
                    constraintsExpr = arg.expression.description
                case "options":
                    optionsExpr = arg.expression.description
                case "hint":
                    hintExpr = arg.expression.description
                case "editor":
                    editorExpr = arg.expression.description
                default:
                    break
                }
            }
        }

        guard let fieldLabel = label else { continue }

        let rawType = binding.typeAnnotation?.type.description
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let isOptional = rawType.hasSuffix("?")
        let baseType = isOptional ? String(rawType.dropLast()) : rawType
        let isArray = baseType.hasPrefix("[") && baseType.hasSuffix("]")
        let arrayElementType = isArray
            ? String(baseType.dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
            : nil

        fields.append(FieldInfo(
            name: propertyName,
            label: fieldLabel,
            typeName: baseType,
            isOptional: isOptional,
            defaultExpr: binding.initializer?.value.description.trimmingCharacters(in: .whitespacesAndNewlines),
            constraintsExpr: constraintsExpr,
            optionsExpr: optionsExpr,
            hintExpr: hintExpr,
            editorExpr: editorExpr,
            sectionTitle: currentSection,
            isArray: isArray,
            arrayElementType: arrayElementType
        ))

        currentSection = nil
    }

    return fields
}

func isPrimitiveType(_ typeName: String) -> Bool {
    switch typeName {
    case "String", "Double", "Int", "Float", "CGFloat", "Bool", "HexColor", "Date", "TemplateImage":
        return true
    default:
        return false
    }
}

func fieldKindExpr(for field: FieldInfo) -> String {
    if field.optionsExpr != nil {
        return ".enumeration"
    }
    if field.isArray {
        return ".array"
    }
    switch field.typeName {
    case "String":
        return ".string"
    case "Double", "Int", "Float", "CGFloat":
        return ".number"
    case "Bool":
        return ".bool"
    case "HexColor":
        return ".color"
    case "Date":
        return ".date"
    case "TemplateImage":
        return ".image"
    default:
        return ".record"
    }
}

func primitiveFieldKindExpr(for typeName: String?) -> String? {
    guard let typeName else { return nil }
    switch typeName {
    case "String":
        return ".string"
    case "Double", "Int", "Float", "CGFloat":
        return ".number"
    case "Bool":
        return ".bool"
    case "HexColor":
        return ".color"
    case "Date":
        return ".date"
    case "TemplateImage":
        return ".image"
    default:
        return nil
    }
}

func fieldValueExpr(for valueExpr: String, typeName: String) -> String {
    switch typeName {
    case "String":
        return ".string(\(valueExpr))"
    case "Double", "Float", "CGFloat":
        return ".number(Double(\(valueExpr)))"
    case "Int":
        return ".number(Double(\(valueExpr)))"
    case "Bool":
        return ".bool(\(valueExpr))"
    case "HexColor":
        return ".color(\(valueExpr).hex)"
    case "Date":
        return ".date(\(valueExpr))"
    case "TemplateImage":
        return ".image(\(valueExpr).path)"
    default:
        return ".record(\(valueExpr).toFieldValues())"
    }
}

func defaultValueExpr(for field: FieldInfo) -> String {
    guard let defaultExpr = field.defaultExpr, defaultExpr != "nil" else {
        return field.isArray ? ".array([])" : ".null"
    }

    if field.isArray {
        if defaultExpr == "[]" {
            return ".array([])"
        }
        let elementType = field.arrayElementType ?? "Never"
        return ".array((\(defaultExpr)).map { \(fieldValueExpr(for: "$0", typeName: elementType)) })"
    }

    switch field.typeName {
    case "String":
        return ".string(\(defaultExpr))"
    case "Double", "Float", "CGFloat":
        return ".number(Double(\(defaultExpr)))"
    case "Int":
        return ".number(Double(\(defaultExpr)))"
    case "Bool":
        return ".bool(\(defaultExpr))"
    case "HexColor":
        return ".color(HexColor(\(defaultExpr)).hex)"
    case "Date":
        return ".date(\(defaultExpr))"
    case "TemplateImage":
        return ".image(\(defaultExpr).path)"
    default:
        return ".record(\(defaultExpr).toFieldValues())"
    }
}

func optionsExpr(for field: FieldInfo) -> String? {
    guard let optionsExpr = field.optionsExpr else { return nil }
    return "(\(optionsExpr)).map { EnumOption(value: $0, label: $0) }"
}

func schemaExpr(forArrayElementType typeName: String?) -> String? {
    guard let typeName else { return nil }
    guard !isPrimitiveType(typeName) else { return nil }
    return "\(typeName).schema"
}

func schemaExpr(forRecordType typeName: String, isArray: Bool, optionsExpr: String?) -> String? {
    guard optionsExpr == nil, !isArray, !isPrimitiveType(typeName) else { return nil }
    return "\(typeName).schema"
}

func optionalInitExpr(for field: FieldInfo, key: String) -> String {
    if field.isArray {
        let elementType = field.arrayElementType ?? "Never"
        switch elementType {
        case "String":
            return "values[\"\(key)\"]?.asArray.map { $0.compactMap(\\.asString) }"
        case "Double", "Float", "CGFloat":
            return "values[\"\(key)\"]?.asArray.map { $0.compactMap(\\.asNumber) }"
        case "Int":
            return "values[\"\(key)\"]?.asArray.map { $0.compactMap { $0.asNumber.map(Int.init) } }"
        case "Bool":
            return "values[\"\(key)\"]?.asArray.map { $0.compactMap(\\.asBool) }"
        case "HexColor":
            return "values[\"\(key)\"]?.asArray.map { $0.compactMap { $0.asString.map(HexColor.init) } }"
        case "Date":
            return "values[\"\(key)\"]?.asArray.map { $0.compactMap(\\.asDate) }"
        case "TemplateImage":
            return "values[\"\(key)\"]?.asArray.map { $0.compactMap { $0.asString.map(TemplateImage.init) } }"
        default:
            return """
            values["\(key)"]?.asArray.map { items in
                        items.compactMap { item in
                            guard let rec = item.asRecord else { return nil }
                            return \(elementType)(from: rec)
                        }
                    }
            """
        }
    }

    switch field.typeName {
    case "String":
        return "values[\"\(key)\"]?.asString"
    case "Double", "Float", "CGFloat":
        return "values[\"\(key)\"]?.asNumber"
    case "Int":
        return "values[\"\(key)\"]?.asNumber.map(Int.init)"
    case "Bool":
        return "values[\"\(key)\"]?.asBool"
    case "HexColor":
        return "values[\"\(key)\"]?.asString.map(HexColor.init)"
    case "Date":
        return "values[\"\(key)\"]?.asDate"
    case "TemplateImage":
        return "values[\"\(key)\"]?.asString.map(TemplateImage.init)"
    default:
        return "values[\"\(key)\"]?.asRecord.map(\(field.typeName).init(from:))"
    }
}

func nonOptionalInitExpr(for field: FieldInfo, key: String) -> String {
    let defaultExpr = field.defaultExpr

    if field.isArray {
        let elementType = field.arrayElementType ?? "Never"
        switch elementType {
        case "String":
            return "(values[\"\(key)\"]?.asArray ?? []).compactMap(\\.asString)"
        case "Double", "Float", "CGFloat":
            return "(values[\"\(key)\"]?.asArray ?? []).compactMap(\\.asNumber)"
        case "Int":
            return "(values[\"\(key)\"]?.asArray ?? []).compactMap { $0.asNumber.map(Int.init) }"
        case "Bool":
            return "(values[\"\(key)\"]?.asArray ?? []).compactMap(\\.asBool)"
        case "HexColor":
            return "(values[\"\(key)\"]?.asArray ?? []).compactMap { $0.asString.map(HexColor.init) }"
        case "Date":
            return "(values[\"\(key)\"]?.asArray ?? []).compactMap(\\.asDate)"
        case "TemplateImage":
            return "(values[\"\(key)\"]?.asArray ?? []).compactMap { $0.asString.map(TemplateImage.init) }"
        default:
            return """
            (values["\(key)"]?.asArray ?? []).compactMap { item in
                        guard let rec = item.asRecord else { return nil }
                        return \(elementType)(from: rec)
                    }
            """
        }
    }

    switch field.typeName {
    case "String":
        return "values[\"\(key)\"]?.asString ?? \(defaultExpr ?? "\"\"")"
    case "Double", "Float", "CGFloat":
        return "values[\"\(key)\"]?.asNumber ?? Double(\(defaultExpr ?? "0"))"
    case "Int":
        return "Int(values[\"\(key)\"]?.asNumber ?? Double(\(defaultExpr ?? "0")))"
    case "Bool":
        return "values[\"\(key)\"]?.asBool ?? \(defaultExpr ?? "false")"
    case "HexColor":
        return "HexColor(values[\"\(key)\"]?.asString ?? \((defaultExpr ?? "\"#808080\"")))"
    case "Date":
        return "values[\"\(key)\"]?.asDate ?? \(defaultExpr ?? "Date()")"
    case "TemplateImage":
        return "values[\"\(key)\"]?.asString.map(TemplateImage.init) ?? \(defaultExpr ?? "TemplateImage(\"\")")"
    default:
        return "values[\"\(key)\"]?.asRecord.map(\(field.typeName).init(from:)) ?? \(defaultExpr ?? "\(field.typeName)()")"
    }
}

func generateInitFromValues(fields: [FieldInfo]) -> String {
    fields.map { field in
        let key = field.name
        if field.isOptional {
            return "        self.\(key) = \(optionalInitExpr(for: field, key: key))"
        }
        return "        self.\(key) = \(nonOptionalInitExpr(for: field, key: key))"
    }
    .joined(separator: "\n")
}

func optionalEncodeExpr(for field: FieldInfo, key: String) -> String {
    if field.isArray {
        let elementType = field.arrayElementType ?? "Never"
        return "\(key).map { .array($0.map { \(fieldValueExpr(for: "$0", typeName: elementType)) }) } ?? .null"
    }

    switch field.typeName {
    case "String":
        return "\(key).map(FieldValue.string) ?? .null"
    case "Double", "Float", "CGFloat":
        return "\(key).map(FieldValue.number) ?? .null"
    case "Int":
        return "\(key).map { .number(Double($0)) } ?? .null"
    case "Bool":
        return "\(key).map(FieldValue.bool) ?? .null"
    case "HexColor":
        return "\(key).map { .color($0.hex) } ?? .null"
    case "Date":
        return "\(key).map(FieldValue.date) ?? .null"
    case "TemplateImage":
        return "\(key).map { .image($0.path) } ?? .null"
    default:
        return "\(key).map { .record($0.toFieldValues()) } ?? .null"
    }
}

func nonOptionalEncodeExpr(for field: FieldInfo, key: String) -> String {
    if field.isArray {
        let elementType = field.arrayElementType ?? "Never"
        return ".array(\(key).map { \(fieldValueExpr(for: "$0", typeName: elementType)) })"
    }

    switch field.typeName {
    case "String":
        return ".string(\(key))"
    case "Double", "Float", "CGFloat":
        return ".number(Double(\(key)))"
    case "Int":
        return ".number(Double(\(key)))"
    case "Bool":
        return ".bool(\(key))"
    case "HexColor":
        return ".color(\(key).hex)"
    case "Date":
        return ".date(\(key))"
    case "TemplateImage":
        return ".image(\(key).path)"
    default:
        return ".record(\(key).toFieldValues())"
    }
}

func generateToFieldValues(fields: [FieldInfo]) -> String {
    var lines = ["        var result: [String: FieldValue] = [:]"]

    for field in fields {
        let key = field.name
        let expr = field.isOptional
            ? optionalEncodeExpr(for: field, key: key)
            : nonOptionalEncodeExpr(for: field, key: key)
        lines.append("        result[\"\(key)\"] = \(expr)")
    }

    lines.append("        return result")
    return lines.joined(separator: "\n")
}

func fieldDescriptorExpr(for field: FieldInfo) -> String {
    var parts: [String] = [
        "key: \"\(field.name)\"",
        "label: \"\(field.label)\"",
        "kind: \(fieldKindExpr(for: field))",
        "required: \(!field.isOptional)",
        "defaultValue: \(defaultValueExpr(for: field))"
    ]

    if let hintExpr = field.hintExpr {
        parts.append("hint: \(hintExpr)")
    }

    parts.append("constraints: \(field.constraintsExpr)")

    if let optionsExpr = optionsExpr(for: field) {
        parts.append("options: \(optionsExpr)")
    }

    if let arrayItemKindExpr = primitiveFieldKindExpr(for: field.arrayElementType) {
        parts.append("arrayItemKind: \(arrayItemKindExpr)")
    }

    if let itemSchemaExpr = schemaExpr(forArrayElementType: field.arrayElementType) {
        parts.append("itemSchema: \(itemSchemaExpr)")
    }

    if let recordSchemaExpr = schemaExpr(forRecordType: field.typeName, isArray: field.isArray, optionsExpr: field.optionsExpr) {
        parts.append("recordSchema: \(recordSchemaExpr)")
    }

    if let editorExpr = field.editorExpr {
        parts.append("editor: \(editorExpr)")
    }

    return "                FieldDescriptor(\(parts.joined(separator: ", ")))"
}

func buildSchemaSectionsCode(from fields: [FieldInfo]) -> String {
    var schemaSections: [String] = []
    var currentFields: [String] = []
    var currentSectionTitle = "General"

    for field in fields {
        if let section = field.sectionTitle {
            if !currentFields.isEmpty {
                let fieldsList = currentFields.joined(separator: ",\n")
                schemaSections.append(
                    "            SchemaSection(\"\(currentSectionTitle)\", fields: [\n\(fieldsList)\n            ])"
                )
                currentFields = []
            }
            currentSectionTitle = section
        }

        currentFields.append(fieldDescriptorExpr(for: field))
    }

    if !currentFields.isEmpty {
        let fieldsList = currentFields.joined(separator: ",\n")
        schemaSections.append(
            "            SchemaSection(\"\(currentSectionTitle)\", fields: [\n\(fieldsList)\n            ])"
        )
    }

    return schemaSections.joined(separator: ",\n")
}

// MARK: - ExtensionMacro

extension SlopDataMacro: ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            throw MacroError("@SlopData can only be applied to structs")
        }

        let typeName = structDecl.name.text
        let fields = extractFields(from: structDecl.memberBlock.members)
        let sectionsCode = buildSchemaSectionsCode(from: fields)
        let initBody = generateInitFromValues(fields: fields)
        let toFieldValuesBody = generateToFieldValues(fields: fields)

        let ext: DeclSyntax = """
        extension \(raw: typeName): TemplateDataProtocol {
            public static var schema: Schema {
                Schema(sections: [
        \(raw: sectionsCode)
                ])
            }

            public init(from values: [String: FieldValue]) {
        \(raw: initBody)
            }

            public func toFieldValues() -> [String: FieldValue] {
        \(raw: toFieldValuesBody)
            }
        }
        """

        return [ext.cast(ExtensionDeclSyntax.self)]
    }
}

// MARK: - MemberMacro

extension SlopDataMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let structDecl = declaration.as(StructDeclSyntax.self) else { return [] }

        let hasInit = structDecl.memberBlock.members.contains { member in
            member.decl.is(InitializerDeclSyntax.self)
        }

        if hasInit { return [] }
        return ["public init() {}"]
    }
}

// MARK: - MemberAttributeMacro

extension SlopDataMacro: MemberAttributeMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingAttributesFor member: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AttributeSyntax] {
        []
    }
}

// MARK: - Error

struct MacroError: Error, CustomStringConvertible {
    let description: String
    init(_ message: String) { self.description = message }
}
