import Foundation

/// Base class for @objc entry points in template bundles.
/// Bundle.principalClass requires an ObjC-visible class.
///
/// Template authors subclass this with a 3-line entry point:
/// ```swift
/// @objc(InvoiceEntryPoint)
/// public final class InvoiceEntryPoint: SlopTemplateEntryPoint {
///     @objc override public class func templateType() -> AnyObject.Type {
///         InvoiceTemplate.self
///     }
/// }
/// ```
open class SlopTemplateEntryPoint: NSObject {
    /// Override to return your template's concrete type (conforming to AnySlopTemplate).
    @objc open class func templateType() -> AnyObject.Type {
        fatalError("Subclasses must override templateType()")
    }
}
