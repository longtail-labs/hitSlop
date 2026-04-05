import Foundation
import Testing
@testable import SlopUI

private func makePreviewResolverTempRoot() -> URL {
    URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
}

private func writeEnvelope(
    _ envelope: SlopFileEnvelope,
    to packageURL: URL
) throws {
    try FileManager.default.createDirectory(at: packageURL, withIntermediateDirectories: true)

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(envelope)
    try data.write(to: packageURL.appendingPathComponent("slop.json"), options: .atomic)
}

@Test
func previewResolverPrefersPackagePreviewOverCache() throws {
    let rootURL = makePreviewResolverTempRoot()
    defer { try? FileManager.default.removeItem(at: rootURL) }

    let packageURL = rootURL.appendingPathComponent("sample").appendingPathExtension("slop")
    let previewsDirectory = rootURL.appendingPathComponent("previews", isDirectory: true)
    try FileManager.default.createDirectory(at: previewsDirectory, withIntermediateDirectories: true)

    let envelope = SlopFileEnvelope(
        templateID: "com.hitslop.tests.card",
        templateVersion: "1.0.0"
    )
    try writeEnvelope(envelope, to: packageURL)

    let packagePreviewURL = packageURL.appendingPathComponent("preview.png")
    let cachedPreviewURL = previewsDirectory.appendingPathComponent("com.hitslop.tests.card@1.0.0.png")
    try Data("package".utf8).write(to: packagePreviewURL, options: .atomic)
    try Data("cache".utf8).write(to: cachedPreviewURL, options: .atomic)

    let resolvedURL = SlopPreviewAssetResolver.resolvePreviewURL(
        for: packageURL,
        previewsDirectory: previewsDirectory
    )

    #expect(resolvedURL == packagePreviewURL)
}

@Test
func previewResolverFallsBackToCachedPreview() throws {
    let rootURL = makePreviewResolverTempRoot()
    defer { try? FileManager.default.removeItem(at: rootURL) }

    let packageURL = rootURL.appendingPathComponent("sample").appendingPathExtension("slop")
    let previewsDirectory = rootURL.appendingPathComponent("previews", isDirectory: true)
    try FileManager.default.createDirectory(at: previewsDirectory, withIntermediateDirectories: true)

    let envelope = SlopFileEnvelope(
        templateID: "com.hitslop.tests.card",
        templateVersion: "1.0.0"
    )
    try writeEnvelope(envelope, to: packageURL)

    let cachedPreviewURL = previewsDirectory.appendingPathComponent("com.hitslop.tests.card@1.0.0.png")
    try Data("cache".utf8).write(to: cachedPreviewURL, options: .atomic)

    let resolvedURL = SlopPreviewAssetResolver.resolvePreviewURL(
        for: packageURL,
        previewsDirectory: previewsDirectory
    )

    #expect(resolvedURL == cachedPreviewURL)
}

@Test
func previewResolverReturnsNilWhenNoPreviewAssetExists() throws {
    let rootURL = makePreviewResolverTempRoot()
    defer { try? FileManager.default.removeItem(at: rootURL) }

    let packageURL = rootURL.appendingPathComponent("sample").appendingPathExtension("slop")
    let previewsDirectory = rootURL.appendingPathComponent("previews", isDirectory: true)
    try FileManager.default.createDirectory(at: previewsDirectory, withIntermediateDirectories: true)

    let envelope = SlopFileEnvelope(
        templateID: "com.hitslop.tests.card",
        templateVersion: "1.0.0"
    )
    try writeEnvelope(envelope, to: packageURL)

    let resolvedURL = SlopPreviewAssetResolver.resolvePreviewURL(
        for: packageURL,
        previewsDirectory: previewsDirectory
    )

    #expect(resolvedURL == nil)
}
