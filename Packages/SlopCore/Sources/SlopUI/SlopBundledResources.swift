import Foundation

public enum SlopBundledResources {
    public static var templatesDirectoryURL: URL? {
        Bundle.module.url(forResource: "templates", withExtension: nil)
    }

    public static var themesDirectoryURL: URL? {
        Bundle.module.url(forResource: "themes", withExtension: nil)
    }

    public static var skinsDirectoryURL: URL? {
        Bundle.module.url(forResource: "skins", withExtension: nil)
    }

    public static var skillDirectoryURL: URL? {
        Bundle.module.url(forResource: "skill", withExtension: nil)
    }

    public static var skillContent: String? {
        guard let url = skillDirectoryURL?.appendingPathComponent("SKILL.md"),
              let content = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        return content
    }

    public static var detectHookContent: String? {
        guard let url = skillDirectoryURL?.appendingPathComponent("slop-detect.sh"),
              let content = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        return content
    }
}
