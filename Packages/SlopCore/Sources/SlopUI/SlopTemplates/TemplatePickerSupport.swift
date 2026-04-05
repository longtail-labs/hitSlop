import Foundation

@_spi(TemplatePicker)
public enum TemplatePickerSupport {
    public static func previewAspectRatio(for metadata: TemplateMetadata) -> CGFloat {
        guard metadata.width > 0, metadata.height > 0 else {
            return 1
        }

        return metadata.width / metadata.height
    }

    public static func resolvedSelection(
        currentSelectionID: String?,
        visibleTemplateIDs: [String]
    ) -> String? {
        guard !visibleTemplateIDs.isEmpty else {
            return nil
        }

        if let currentSelectionID, visibleTemplateIDs.contains(currentSelectionID) {
            return currentSelectionID
        }

        return visibleTemplateIDs.first
    }
}
