import SwiftSyntax
import SwiftSyntaxMacros

/// Implementation of the @SlopTemplate macro.
/// Generates an AnySlopTemplate class and @objc entry point as peers,
/// and injects an init(store:) as a member.
public struct SlopTemplateMacro {}

// MARK: - Argument Parsing

private struct DataPropertyInfo {
    let propertyName: String
    let typeName: String
}

private func findTemplateDataProperty(in structDecl: StructDeclSyntax) throws -> DataPropertyInfo {
    for member in structDecl.memberBlock.members {
        guard let varDecl = member.decl.as(VariableDeclSyntax.self),
              let binding = varDecl.bindings.first,
              let pattern = binding.pattern.as(IdentifierPatternSyntax.self)
        else { continue }

        for attr in varDecl.attributes {
            guard let attrSyntax = attr.as(AttributeSyntax.self),
                  let baseName = attributeBaseName(attrSyntax),
                  baseName == "TemplateData" || baseName == "TemplateState"
            else { continue }

            let typeName = binding.typeAnnotation?.type.description
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            return DataPropertyInfo(
                propertyName: pattern.identifier.text,
                typeName: typeName
            )
        }
    }

    throw MacroError("@SlopTemplate requires a property annotated with @TemplateData or @TemplateState")
}

private func extractLabeledArgs(from node: AttributeSyntax) -> [String: String] {
    guard let args = node.arguments?.as(LabeledExprListSyntax.self) else { return [:] }
    var result: [String: String] = [:]
    for arg in args {
        guard let label = arg.label?.text else { continue }
        result[label] = arg.expression.description.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    return result
}

// MARK: - PeerMacro

extension SlopTemplateMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            throw MacroError("@SlopTemplate can only be applied to structs")
        }

        let viewName = structDecl.name.text
        let args = extractLabeledArgs(from: node)

        guard let id = args["id"] else {
            throw MacroError("@SlopTemplate requires 'id' argument")
        }
        guard let name = args["name"] else {
            throw MacroError("@SlopTemplate requires 'name' argument")
        }

        let dataInfo = try findTemplateDataProperty(in: structDecl)

        let version = args["version"] ?? "\"1.0.0\""
        let description = args["description"] ?? "nil"
        let minimumHostVersion = args["minimumHostVersion"] ?? "\"1.0.0\""
        let width = args["width"] ?? "400"
        let height = args["height"] ?? "600"
        let shape = args["shape"] ?? ".roundedRect(radius: 16)"
        let theme = args["theme"] ?? "nil"
        let alwaysOnTop = args["alwaysOnTop"] ?? "true"
        let titleBarHidden = args["titleBarHidden"] ?? "true"

        // Support both 'category' (singular) and 'categories' (array)
        let categoriesExpr: String
        if let categories = args["categories"] {
            categoriesExpr = categories
        } else if let category = args["category"] {
            categoriesExpr = "[\(category)]"
        } else {
            categoriesExpr = "[]"
        }

        // Build minSize expression
        let minSizeExpr: String
        if let minWidth = args["minWidth"], let minHeight = args["minHeight"] {
            minSizeExpr = "CGSize(width: \(minWidth), height: \(minHeight))"
        } else {
            minSizeExpr = "nil"
        }

        let className = "\(viewName)_SlopTemplate"
        let entryPointName = "\(viewName)_EntryPoint"

        let templateClass: DeclSyntax = """
        public final class \(raw: className): AnySlopTemplate {
            public static let templateID = \(raw: id)
            public static let name = \(raw: name)
            public static let templateDescription: String? = \(raw: description)
            public static let version = \(raw: version)
            public static let minimumHostVersion = \(raw: minimumHostVersion)
            public static let schema = \(raw: dataInfo.typeName).schema
            public static let metadata = TemplateMetadata(
                width: \(raw: width),
                height: \(raw: height),
                minSize: \(raw: minSizeExpr),
                windowShape: \(raw: shape),
                theme: \(raw: theme),
                alwaysOnTop: \(raw: alwaysOnTop),
                titleBarHidden: \(raw: titleBarHidden),
                categories: \(raw: categoriesExpr)
            )

            private let store: RawTemplateStore

            public init(rawStore: RawTemplateStore) {
                self.store = rawStore
            }

            @MainActor
            public func body() -> AnyView {
                AnyView(\(raw: viewName)(store: store))
            }
        }
        """

        let entryPoint: DeclSyntax = """
        @objc(\(raw: entryPointName))
        public final class \(raw: entryPointName): SlopTemplateEntryPoint {
            @objc override public class func templateType() -> AnyObject.Type {
                \(raw: className).self
            }
        }
        """

        return [templateClass, entryPoint]
    }
}

// MARK: - MemberMacro

extension SlopTemplateMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let structDecl = declaration.as(StructDeclSyntax.self) else { return [] }

        let dataInfo = try findTemplateDataProperty(in: structDecl)

        // Don't inject if user already defined init(store:)
        let hasStoreInit = structDecl.memberBlock.members.contains { member in
            guard let initDecl = member.decl.as(InitializerDeclSyntax.self) else { return false }
            return initDecl.signature.parameterClause.parameters.contains { param in
                param.firstName.text == "store"
            }
        }

        if hasStoreInit { return [] }

        let initDecl: DeclSyntax = """
        init(store: RawTemplateStore) {
            self._\(raw: dataInfo.propertyName) = TemplateState(store: store)
        }
        """

        return [initDecl]
    }
}
