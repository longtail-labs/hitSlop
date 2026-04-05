import Foundation
import SlopUI

enum CLIInstaller {
    private static let home = FileManager.default.homeDirectoryForCurrentUser

    private static let binDir = home.appendingPathComponent(".hitslop/bin")
    private static let symlinkPath = binDir.appendingPathComponent("slop")

    private static let claudeDir = home.appendingPathComponent(".claude")
    private static let hooksDir = claudeDir.appendingPathComponent("hooks")
    private static let detectHookFile = hooksDir.appendingPathComponent("slop-detect.sh")

    // Canonical skill location — agent-neutral, symlinked into agent-specific dirs
    private static let canonicalSkillDir = home.appendingPathComponent(".hitslop/skills/hitslop")
    private static let skillFile = canonicalSkillDir.appendingPathComponent("SKILL.md")

    // Agent-specific skill directories that get symlinked to canonical
    private static let agentSkillLinks: [URL] = [
        home.appendingPathComponent(".claude/skills/hitslop"),
        home.appendingPathComponent(".agents/skills/hitslop"),
    ]

    // MARK: - CLI Symlink

    static func install() {
        let fm = FileManager.default
        try? fm.createDirectory(at: binDir, withIntermediateDirectories: true)

        guard let executableURL = Bundle.main.executableURL else {
            NSLog("CLIInstaller: cannot determine executable path")
            return
        }

        let linkPath = symlinkPath.path
        let targetPath = executableURL.path

        if let existing = try? fm.destinationOfSymbolicLink(atPath: linkPath),
           existing == targetPath {
            return
        }

        try? fm.removeItem(atPath: linkPath)

        do {
            try fm.createSymbolicLink(atPath: linkPath, withDestinationPath: targetPath)
            NSLog("CLIInstaller: installed slop CLI at \(linkPath)")
        } catch {
            NSLog("CLIInstaller: failed to create symlink: \(error)")
        }
    }

    // MARK: - Skill

    static func installSkill() {
        let content = SlopBundledResources.skillContent ?? fallbackSkillContent
        let fm = FileManager.default

        // Content already current — just ensure symlinks
        if let existing = try? String(contentsOf: skillFile, encoding: .utf8),
           existing == content {
            ensureSkillSymlinks()
            return
        }

        try? fm.createDirectory(at: canonicalSkillDir, withIntermediateDirectories: true)

        do {
            try content.write(to: skillFile, atomically: true, encoding: .utf8)
            NSLog("CLIInstaller: installed skill at \(skillFile.path)")
        } catch {
            NSLog("CLIInstaller: failed to write skill file: \(error)")
        }

        ensureSkillSymlinks()
    }

    private static func ensureSkillSymlinks() {
        let fm = FileManager.default
        let target = canonicalSkillDir.path

        for linkURL in agentSkillLinks {
            let linkPath = linkURL.path
            let parentDir = linkURL.deletingLastPathComponent()

            // Already a correct symlink?
            if let dest = try? fm.destinationOfSymbolicLink(atPath: linkPath),
               dest == target { continue }

            // Remove existing (real dir or stale symlink)
            if fm.fileExists(atPath: linkPath) {
                try? fm.removeItem(atPath: linkPath)
            }

            try? fm.createDirectory(at: parentDir, withIntermediateDirectories: true)

            do {
                try fm.createSymbolicLink(atPath: linkPath, withDestinationPath: target)
                NSLog("CLIInstaller: symlinked \(linkPath) → \(target)")
            } catch {
                NSLog("CLIInstaller: failed to symlink \(linkPath): \(error)")
            }
        }
    }

    // MARK: - Shell PATH

    static func installShellPath() {
        let fm = FileManager.default
        let envFile = home.appendingPathComponent(".hitslop/env")
        let envContent = "# hitSlop CLI\nexport PATH=\"$HOME/.hitslop/bin:$PATH\"\n"

        // Always overwrite ~/.hitslop/env — it's our file
        try? envContent.write(to: envFile, atomically: true, encoding: .utf8)

        let sourceLine = ". \"$HOME/.hitslop/env\""

        for rc in [".zshrc", ".bashrc"] {
            let rcFile = home.appendingPathComponent(rc)
            let rcPath = rcFile.path

            if rc == ".zshrc" && !fm.fileExists(atPath: rcPath) {
                // macOS always uses zsh — create .zshrc if missing
                let initial = "\n# Added by hitSlop\n\(sourceLine)\n"
                try? initial.write(toFile: rcPath, atomically: true, encoding: .utf8)
                continue
            }

            guard fm.fileExists(atPath: rcPath),
                  let contents = try? String(contentsOfFile: rcPath, encoding: .utf8)
            else { continue }

            if contents.contains(".hitslop/env") { continue }

            let snippet = "\n\n# Added by hitSlop\n\(sourceLine)\n"
            guard let data = snippet.data(using: .utf8),
                  let handle = FileHandle(forWritingAtPath: rcPath)
            else { continue }
            handle.seekToEndOfFile()
            handle.write(data)
            handle.closeFile()
        }
    }

    // MARK: - Hook

    static func installHook() {
        let fm = FileManager.default
        let content = SlopBundledResources.detectHookContent ?? fallbackDetectHook

        // Check if hook file already exists with current content
        if fm.fileExists(atPath: detectHookFile.path),
           let existing = try? String(contentsOf: detectHookFile, encoding: .utf8),
           existing == content {
            // File is current — still ensure settings.json is wired
            registerHookInSettings()
            return
        }

        try? fm.createDirectory(at: hooksDir, withIntermediateDirectories: true)

        do {
            try content.write(to: detectHookFile, atomically: true, encoding: .utf8)
            try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: detectHookFile.path)
            NSLog("CLIInstaller: installed detect hook at \(detectHookFile.path)")
        } catch {
            NSLog("CLIInstaller: failed to write detect hook: \(error)")
            return
        }

        registerHookInSettings()
    }

    // MARK: - Settings Registration

    private static func registerHookInSettings() {
        let settingsPath = claudeDir.appendingPathComponent("settings.json")
        let fm = FileManager.default

        var settings: [String: Any] = [:]
        if fm.fileExists(atPath: settingsPath.path),
           let data = try? Data(contentsOf: settingsPath),
           let existing = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            settings = existing
        }

        var hooks = settings["hooks"] as? [String: Any] ?? [:]

        let didUpdate = addHookIfNeeded(
            to: &hooks,
            event: "UserPromptSubmit",
            hookPath: detectHookFile.path,
            identifier: "slop-detect.sh"
        )

        guard didUpdate else { return }
        settings["hooks"] = hooks

        do {
            let jsonData = try JSONSerialization.data(
                withJSONObject: settings,
                options: [.prettyPrinted, .sortedKeys]
            )
            try jsonData.write(to: settingsPath)
            NSLog("CLIInstaller: registered hook in \(settingsPath.path)")
        } catch {
            NSLog("CLIInstaller: failed to update settings.json: \(error)")
        }
    }

    private static func addHookIfNeeded(
        to hooks: inout [String: Any],
        event: String,
        hookPath: String,
        identifier: String
    ) -> Bool {
        var eventHooks = hooks[event] as? [[String: Any]] ?? []

        let hookExists = eventHooks.contains { matcher in
            guard let matcherHooks = matcher["hooks"] as? [[String: Any]] else { return false }
            return matcherHooks.contains { hook in
                guard let command = hook["command"] as? String else { return false }
                return command.contains(identifier)
            }
        }

        guard !hookExists else { return false }

        eventHooks.append([
            "hooks": [
                [
                    "type": "command",
                    "command": hookPath,
                ]
            ]
        ])
        hooks[event] = eventHooks
        return true
    }

    // MARK: - Fallbacks

    private static let fallbackSkillContent = """
        ---
        name: hitslop
        description: Create and manage .slop documents — template-powered, themed, plain-text documents for any purpose.
        allowed-tools: Bash(slop:*)
        ---

        # hitSlop

        Create, read, write, and export .slop documents via the CLI. 74+ built-in templates, 22 themes.

        ```bash
        slop --help                    # Full help
        slop templates                 # List templates
        slop create <templateID> path  # Create document
        slop read path                 # Read document
        slop write path --field k=v    # Update fields
        slop export path --format pdf  # Export
        slop themes list               # List themes
        ```
        """

    private static let fallbackDetectHook = """
        #!/bin/bash
        detected=false
        shopt -s nullglob
        slops=(*.slop)
        if [ ${#slops[@]} -gt 0 ]; then detected=true; fi
        if [ "$detected" = false ] && [ -f "slop.json" ]; then detected=true; fi
        if [ "$detected" = false ]; then
            dir="$(pwd)"
            while [ "$dir" != "/" ]; do
                case "$dir" in *.slop) [ -f "$dir/slop.json" ] && detected=true && break;; esac
                dir="$(dirname "$dir")"
            done
        fi
        if [ "$detected" = true ]; then
            echo "This directory contains .slop documents. Run /hitslop to load the skill."
        fi
        exit 0
        """
}
