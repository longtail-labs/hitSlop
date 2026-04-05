import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct SlopMacroPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        SlopDataMacro.self,
        SlopTemplateMacro.self,
    ]
}
