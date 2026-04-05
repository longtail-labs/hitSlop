# Skins

Window skins allow templates to use arbitrary bitmap shapes instead of standard rounded rectangles. A skin is a PNG image whose alpha channel defines the window shape and hit-testing region.

## Window Shapes

The `WindowShape` enum defines all possible window shapes:

| Shape | Value | Description |
|-------|-------|-------------|
| `roundedRect` | corner radius (number) | Standard rounded rectangle |
| `circle` | none | Circular window (diameter = min(width, height)) |
| `capsule` | none | Pill/stadium shape |
| `path` | SVG path string | Custom vector path |
| `skin` | filename (string) | PNG bitmap skin |

Shapes are specified in template metadata or overridden per-document in `slop.json`:

```json
{ "windowShape": { "type": "roundedRect", "value": 16 } }
{ "windowShape": { "type": "skin", "value": "player-skin.png" } }
```

## Skin Files

Skin PNG files are stored alongside the template or in `~/.hitslop/skins/`. The image serves two purposes:

1. **Background layer**: The full-color image is rendered as the window background
2. **Hit-test mask**: The alpha channel determines which pixels are clickable

### Requirements

- Format: PNG with alpha channel
- Size: Determines window size in points (at 1x scale)
- Alpha threshold: Pixels with alpha > 25 (out of 255) are considered clickable

## SkinLoader

`SkinLoader.load(from:)` processes a PNG into a `SkinImage`:

1. Load `NSImage` from file URL
2. Extract `CGImage` from the NSImage
3. Render the image into an alpha-only `CGContext` (8-bit grayscale, `alphaOnly`)
4. Store the resulting byte array as `alphaData`

```swift
public struct SkinImage {
    let cgImage: CGImage       // Full-color image for display
    let size: NSSize           // Window size in points
    let alphaData: Data        // Alpha channel bytes (width × height)
    let alphaWidth: Int        // Pixel width of alpha data
    let alphaHeight: Int       // Pixel height of alpha data
}
```

## ShapedWindow

`ShapedWindow` is a borderless `NSWindow` subclass that supports both vector and bitmap shapes.

### Vector Path Initialization

```swift
ShapedWindow(shape: NSBezierPath, size: NSSize)
```

- Creates a borderless, transparent window
- Applies a `CAShapeLayer` mask to the content view
- Hit testing uses `CGPath.contains(point)`

### Bitmap Skin Initialization

```swift
ShapedWindow(skin: SkinImage)
```

- Creates a borderless, transparent window sized to the skin image
- Renders the skin image as a `CALayer` background
- Uses the skin image as a `CALayer` mask for visual clipping
- Hit testing uses alpha data lookup

### Hit Testing

The window's content view (`ShapedContentView`) overrides `hitTest(_:)`:

**Bitmap mode**: Maps the click point to pixel coordinates in the alpha data array. If the alpha value at that pixel is > 25, the click passes through to subviews. Otherwise, it falls through to windows below.

**Vector mode**: Uses `CGPath.contains(point)` to determine if the click is inside the shape path.

### Drag Bar

The top 28pt of the window is a drag bar:

- Mouse-down events in this region initiate window dragging via `performDrag(with:)`
- If the click hits an interactive control (any `NSControl` in the responder chain), the event is passed through normally
- The drag bar height is configurable via `ShapedWindow.dragBarHeight`
