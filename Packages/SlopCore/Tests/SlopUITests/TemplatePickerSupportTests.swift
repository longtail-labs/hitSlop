import Foundation
import Testing
@_spi(TemplatePicker) import SlopUI

@Test
func templatePickerSelectionKeepsVisibleCurrentSelection() {
    let selectedID = TemplatePickerSupport.resolvedSelection(
        currentSelectionID: "resume",
        visibleTemplateIDs: ["invoice", "resume", "slide"]
    )

    #expect(selectedID == "resume")
}

@Test
func templatePickerSelectionFallsBackToFirstVisibleTemplate() {
    let selectedID = TemplatePickerSupport.resolvedSelection(
        currentSelectionID: "missing",
        visibleTemplateIDs: ["invoice", "resume", "slide"]
    )

    #expect(selectedID == "invoice")
}

@Test
func templatePickerSelectionReturnsNilWhenNothingIsVisible() {
    let selectedID = TemplatePickerSupport.resolvedSelection(
        currentSelectionID: "resume",
        visibleTemplateIDs: []
    )

    #expect(selectedID == nil)
}

@Test
func templatePickerPreviewAspectRatioUsesTemplateMetadataDimensions() {
    let portrait = TemplateMetadata(width: 440, height: 620)
    let landscape = TemplateMetadata(width: 960, height: 540)
    let square = TemplateMetadata(width: 360, height: 360)

    #expect(TemplatePickerSupport.previewAspectRatio(for: portrait) == CGFloat(440.0 / 620.0))
    #expect(TemplatePickerSupport.previewAspectRatio(for: landscape) == CGFloat(960.0 / 540.0))
    #expect(TemplatePickerSupport.previewAspectRatio(for: square) == 1)
}
