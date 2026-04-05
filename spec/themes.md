# Themes

Themes define the visual appearance of `.slop` documents — colors, typography, spacing, and shadows. They are stored as JSON files with the `.theme` extension.

## File Format

A `.theme` file is a JSON object with the following properties:

```json
{
  "displayName": "Studio Noir",
  "group": "Dark",
  "background": "#0a0a0a",
  "foreground": "#e8e6e3",
  "secondary": "#8e8e93",
  "accent": "#5fc0e8",
  "surface": "#1c1c1e",
  "divider": "#38383a"
}
```

### Core Colors (required for valid theme)

| Property | Description | Example |
|----------|-------------|---------|
| `background` | Window/page background | `"#0a0a0a"` |
| `foreground` | Primary text color | `"#e8e6e3"` |
| `secondary` | Secondary/muted text | `"#8e8e93"` |
| `accent` | Interactive elements, highlights | `"#5fc0e8"` |
| `surface` | Card/panel backgrounds | `"#1c1c1e"` |
| `divider` | Separator lines | `"#38383a"` |

### Semantic Colors (auto-derived if omitted)

| Property | Description | Default Derivation |
|----------|-------------|-------------------|
| `success` | Positive states | Green variant |
| `warning` | Caution states | Orange variant |
| `error` | Error states | Red variant |
| `muted` | De-emphasized elements | Lighter secondary |
| `border` | Component borders | Slightly lighter divider |

### Typography

| Property | Default | Description |
|----------|---------|-------------|
| `titleFontFamily` | System | Font family for titles (24pt, bold) |
| `bodyFontFamily` | System | Font family for body text (14pt, regular) |
| `monoFontFamily` | Menlo | Font family for monospace text (12pt, medium) |
| `titleWeight` | `"bold"` | Title font weight |
| `bodyWeight` | `"regular"` | Body font weight |
| `headingFontFamily` | titleFontFamily | Heading font (17pt, semibold) |
| `headingWeight` | titleWeight | Heading weight fallback |
| `subheadingFontFamily` | bodyFontFamily | Subheading font (15pt, medium) |
| `subheadingWeight` | bodyWeight | Subheading weight fallback |
| `captionFontFamily` | bodyFontFamily | Caption font (12pt, regular) |
| `captionWeight` | `"regular"` | Caption weight |

Weight values: `"ultralight"`, `"thin"`, `"light"`, `"regular"`, `"medium"`, `"semibold"`, `"bold"`, `"heavy"`, `"black"`.

### Spacing

| Property | Default | Description |
|----------|---------|-------------|
| `spacingScale` | `1.0` | Multiplier for all spacing values |

Base spacing values (multiplied by `spacingScale`):
- XS: 4pt
- SM: 8pt
- MD: 12pt
- LG: 16pt
- XL: 24pt

### Other Properties

| Property | Default | Description |
|----------|---------|-------------|
| `cornerRadius` | `16` | Default corner radius for shaped elements |
| `shadowColor` | black | Shadow color (hex) |
| `shadowOpacity` | varies | Shadow opacity override |

Shadows come in three sizes: SM (radius 2, y 1), MD (radius 4, y 2), LG (radius 8, y 4).

## Discovery

Themes are loaded from multiple sources in priority order:

1. **Package-local**: Theme file inside the `.slop` package directory
2. **User themes**: `~/.hitslop/themes/<id>.theme`
3. **Bundled themes**: Shipped with the app in the resource bundle

## Theme Catalog

The `ThemeCatalog` organizes 22 built-in themes into 11 groups:

| Group | Themes |
|-------|--------|
| Dark | studio-noir, signal-grid, terminal-core, midnight-ink |
| Light | paper-ledger |
| Minimal | minimal-mono, slate-gray |
| Professional | corporate-blue |
| Cool | ocean-glass, arctic-frost, lavender-haze |
| Warm | sunset-poster, ember-glow, rose-garden |
| Nature | forest-club |
| Vibrant | neon-nights, frutiger-aero, xbox-dashboard |
| Playful | playroom, candy-shop |
| Retro | retro-terminal |
| Accessibility | high-contrast |

## Resolution

Theme resolution uses `ThemeCatalog.resolveTheme(id, packageURL)`:

1. Check for a theme file inside the document's package directory
2. Check user themes at `~/.hitslop/themes/`
3. Check bundled themes in the app resource bundle
4. Returns the first match, or nil

## Derivation

`ThemeDeriver.derive(accent:, isDark:)` generates a complete theme from a single accent color using LCH color space calculations. It automatically derives harmonious background, foreground, secondary, surface, divider, and semantic colors.

The CLI exposes this via `slop themes derive`.

## Runtime

At runtime, a `ThemeFile` is converted to a `SlopTheme` value type and injected into the SwiftUI environment via `@Environment(\.slopTheme)`. Templates access theme properties through this environment value.

```swift
@Environment(\.slopTheme) var theme

// In template body:
Text("Hello")
    .foregroundColor(theme.foreground)
    .font(theme.bodyFont)
```
