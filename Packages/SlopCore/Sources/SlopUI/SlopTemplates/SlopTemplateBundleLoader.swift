import AppKit
import SlopKit

/// Loads a compiled template from a `.bundle` directory.
@MainActor
public struct SlopTemplateBundleLoader {

    /// Result of loading a template bundle.
    public struct LoadedTemplate {
        public let templateType: any AnySlopTemplate.Type
        public let bundle: Bundle
    }

    public enum LoadError: Error, LocalizedError {
        case bundleNotFound(URL)
        case bundleLoadFailed(URL)
        case noPrincipalClass(URL)
        case invalidEntryPoint(URL)
        case invalidTemplateType(URL)
        case manifestMismatch(URL)

        public var errorDescription: String? {
            switch self {
            case .bundleNotFound(let url):
                return "Template bundle not found at \(url.path)"
            case .bundleLoadFailed(let url):
                return "Failed to load template bundle at \(url.path)"
            case .noPrincipalClass(let url):
                return "No principal class in bundle at \(url.path)"
            case .invalidEntryPoint(let url):
                return "Principal class is not a SlopTemplateEntryPoint in \(url.path)"
            case .invalidTemplateType(let url):
                return "Template type does not conform to AnySlopTemplate in \(url.path)"
            case .manifestMismatch(let url):
                return "Loaded template bundle did not match its manifest at \(url.path)"
            }
        }
    }

    /// Load a template from a `.bundle` URL directly.
    public static func load(
        bundleURL: URL,
        expectedManifest: TemplateManifest? = nil
    ) throws -> LoadedTemplate {
        guard let bundle = Bundle(url: bundleURL) else {
            throw LoadError.bundleNotFound(bundleURL)
        }

        guard bundle.load() else {
            throw LoadError.bundleLoadFailed(bundleURL)
        }

        guard let principalClass = bundle.principalClass else {
            throw LoadError.noPrincipalClass(bundleURL)
        }

        guard let entryPointType = principalClass as? SlopTemplateEntryPoint.Type else {
            throw LoadError.invalidEntryPoint(bundleURL)
        }

        let rawTemplateType: any AnyObject.Type = entryPointType.templateType()
        guard let templateType = rawTemplateType as? any AnySlopTemplate.Type else {
            throw LoadError.invalidTemplateType(bundleURL)
        }

        if let expectedManifest {
            guard templateType.templateID == expectedManifest.id,
                  templateType.version == expectedManifest.version
            else {
                throw LoadError.manifestMismatch(bundleURL)
            }
        }

        return LoadedTemplate(
            templateType: templateType,
            bundle: bundle
        )
    }
}
