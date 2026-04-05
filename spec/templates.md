# Templates

Templates define the UI, data schema, and display metadata for `.slop` documents. hitSlop supports three tiers of templates.

## Three-Tier System

| Tier | Type | Discovery | Advantages |
|------|------|-----------|-----------|
| 0 | Built-in | Compiled into app binary | Always available, fastest resolution |
| 1 | Bundle | `.bundle` at `~/.hitslop/templates/` | Full Swift/SwiftUI, hot-swappable |
| 2 | Lua Script | `script.lua` at `~/.hitslop/templates/` | No compilation, sandboxed |

All tiers share the same `template.json` manifest format and produce the same `AnySlopTemplate` protocol at runtime.

## Template Manifest (template.json)

Every installed template has a `template.json` manifest:

```json
{
  "id": "com.hitslop.templates.budget-tracker",
  "name": "Budget Tracker",
  "description": "Track income and expenses",
  "version": "1.0.0",
  "minimumHostVersion": "1.0.0",
  "bundleFile": "Template.bundle",
  "metadata": {
    "width": 360,
    "height": 520,
    "windowShape": { "type": "roundedRect", "value": 16 },
    "alwaysOnTop": true,
    "titleBarHidden": true,
    "category": "finance"
  },
  "schema": {
    "sections": [{
      "title": "Budget",
      "fields": [
        { "key": "title", "label": "Title", "kind": "string", "required": true,
          "defaultValue": { "type": "string", "value": "My Budget" }, "constraints": [] },
        { "key": "budget", "label": "Budget", "kind": "number", "required": true,
          "defaultValue": { "type": "number", "value": 0 }, "constraints": [] }
      ]
    }]
  }
}
```

### Manifest Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | yes | Reverse-DNS identifier |
| `name` | string | yes | Human-readable display name |
| `description` | string | no | Short description for gallery |
| `version` | string | yes | Semantic version |
| `minimumHostVersion` | string | yes | Minimum app version required |
| `bundleFile` | string | no | Filename of compiled `.bundle` (Tier 1) |
| `scriptFile` | string | no | Filename of Lua script (Tier 2) |
| `previewFile` | string | no | Gallery preview image filename |
| `metadata` | object | yes | Window and display properties |
| `schema` | object | yes | Data schema definition |

A manifest has either `bundleFile` (Tier 1) or `scriptFile` (Tier 2), never both. Built-in templates (Tier 0) generate their manifest from the compiled type.

### Metadata Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `width` | number | 400 | Window width in points |
| `height` | number | 600 | Window height in points |
| `windowShape` | object | roundedRect(16) | Window shape definition |
| `alwaysOnTop` | bool | true | Float above other windows |
| `titleBarHidden` | bool | true | Hide native title bar |
| `category` | string | nil | Gallery category |

## Tier 0: Built-in Templates

Built-in templates are Swift structs compiled directly into the app binary. They are registered in `BuiltInTemplateRegistry` and are always available.

Each template uses the `@SlopTemplate` macro which generates:
- An `AnySlopTemplate` class (`{ViewName}_SlopTemplate`)
- An `@objc` entry point (`{ViewName}_EntryPoint`)

Template data is declared with `@TemplateData` (alias for `@TemplateState`) and uses `@Field` property wrappers with `@Section` grouping.

## Tier 1: Compiled Bundles

Bundle templates are compiled Swift packages distributed as `.bundle` files:

```
~/.hitslop/templates/com.hitslop.templates.example/1.0.0/
  template.json       ← manifest with bundleFile
  Template.bundle/    ← compiled macOS bundle
    Contents/
      Info.plist      ← principal class declaration
      MacOS/
        template      ← compiled binary
```

The bundle's principal class must conform to `SlopTemplateEntryPoint`. The host loads the bundle at runtime via `SlopTemplateBundleLoader`.

## Tier 2: Lua Scripts

Scripted templates are Lua files interpreted at runtime:

```
~/.hitslop/templates/user.counter/1.0.0/
  template.json       ← manifest with scriptFile
  script.lua          ← Lua source
  preview.png         ← optional gallery preview
```

The manifest uses `scriptFile` instead of `bundleFile`. See [Lua Templates](templates-lua.md) for the complete scripting reference.

## Registry

`SlopTemplateRegistry` discovers all installed templates at startup by scanning:

1. **Built-in**: `BuiltInTemplateRegistry.allTemplates` (compiled types)
2. **External**: `~/.hitslop/templates/<id>/<version>/template.json` (bundles and scripts)

Each discovered template is stored as an `Entry` containing:
- Template ID, name, version
- Manifest and schema
- Paths to bundle or script (or built-in type reference)
- Whether it's scripted (`isScripted`)

### Resolution

`registry.resolve(templateID, version)` returns the matching `Entry` or nil. Resolution checks built-in templates first, then external installations.

### Instantiation

The window branches on entry type to instantiate the template:

```
entry.builtInType != nil?  →  Direct instantiation (Tier 0)
entry.scriptURL != nil?    →  ScriptedTemplate.create() (Tier 2)
entry.bundleURL != nil?    →  SlopTemplateBundleLoader.load() (Tier 1)
```

The instantiated template receives a `RawTemplateStore` and produces a SwiftUI `body()` view for rendering.

## Schema

The schema defines the document's data structure as sections containing field descriptors:

```json
{
  "sections": [{
    "title": "Section Name",
    "fields": [
      { "key": "fieldKey", "label": "Display Name", "kind": "string",
        "required": true, "defaultValue": { "type": "string", "value": "" },
        "constraints": [] }
    ]
  }]
}
```

### Field Kinds

| Kind | Default Value Type | Description |
|------|-------------------|-------------|
| `string` | string | Plain text |
| `richText` | string | Rich text content |
| `number` | number | Numeric value |
| `bool` | boolean | True/false toggle |
| `color` | string | Hex color (e.g. `"#4a90d9"`) |
| `date` | number | Unix timestamp |
| `image` | string | Image reference |
| `enumeration` | string | One of listed options |
| `array` | array | Ordered list with item schema |
| `record` | object | String-keyed map |
| `file` | string | Sidecar file reference |

### Template ID Convention

Template IDs use reverse-DNS format:
- Built-in: `com.hitslop.templates.<name>`
- User-created: `user.<name>` or custom domain
