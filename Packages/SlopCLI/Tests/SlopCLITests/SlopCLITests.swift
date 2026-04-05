import Testing
import Foundation
@testable import SlopCLI

// MARK: - PathResolver Tests

@Test
func absolutePathPassesThrough() {
    let resolved = resolvePath("/tmp/foo.slop")
    #expect(resolved == "/tmp/foo.slop")
}

@Test
func tildePrefixExpands() {
    let resolved = resolvePath("~/test.slop")
    #expect(!resolved.contains("~"))
    #expect(resolved.hasSuffix("/test.slop"))
    #expect(resolved.hasPrefix("/"))
}

@Test
func relativePathPrependsCurrentDirectory() {
    let resolved = resolvePath("test.slop")
    let cwd = FileManager.default.currentDirectoryPath
    #expect(resolved.hasPrefix(cwd))
    #expect(resolved.hasSuffix("test.slop"))
}

// MARK: - CLIError Tests

@Test
func appNotRunningHasDescription() {
    let error = CLIError.appNotRunning
    #expect(error.errorDescription != nil)
    #expect(error.errorDescription!.contains("not running"))
}

@Test
func serverErrorIncludesMessage() {
    let error = CLIError.serverError("connection refused")
    #expect(error.errorDescription?.contains("connection refused") == true)
}
