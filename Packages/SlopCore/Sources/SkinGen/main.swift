import Foundation

let scriptDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let outputDir = scriptDir
    .deletingLastPathComponent()  // Sources
    .appendingPathComponent("SlopUI/Resources/skins")

print("SkinGen: writing to \(outputDir.path)")
SkinRenderer.generateAll(to: outputDir)
print("SkinGen: done!")
