# hitSlop Lua Scripted Templates (v4)

## 1. Overview

Scripted templates are a second template tier that sits alongside compiled Swift bundles (Tier 1) and built-in templates (Tier 0). A scripted template is a plain Lua file plus a `template.json` manifest. No Xcode project, no compilation, no code signing.

The three tiers:

| Tier | What it is | Key trait |
|------|-----------|-----------|
| 0 | Built-in template compiled into the app binary | Zero-cost to resolve, always available |
| 1 | Compiled `.bundle` loaded at runtime | Full Swift + SwiftUI, needs Xcode build |
| 2 | Lua `.lua` script interpreted at runtime | No compilation, sandboxed, declarative layout |

A Tier 2 template produces a `LayoutNode` tree from Lua. The host renders that tree as SwiftUI views using `ScriptedTemplateRenderer`. This means scripted templates cannot use arbitrary SwiftUI — they can only compose the fixed set of layout constructors the host exposes into Lua.

The tradeoff is intentional: give up SwiftUI expressiveness in exchange for zero build tooling, portable scripts, and a sandboxed execution model.

## 2. Template Contract

A Lua script must return a table with up to four functions:

```lua
local template = {}

function template.schema()    -- returns schema table
function template.metadata()  -- returns metadata table
function template.layout(data, theme, context)  -- returns LayoutNode
function template.onAction(name, data) -- returns modified data table

return template
```

Only `layout` is required. `schema` and `metadata` default to empty if absent. `onAction` is optional and only needed if the template uses buttons.

The third `context` argument is optional for backwards compatibility. Existing scripts that still declare `template.layout(data, theme)` continue to work. When present, `context.renderTarget` is one of `"interactive"`, `"pdfExport"`, or `"imageExport"`.

The script can either `return template` at the end or set a global named `template`. The engine tries the return value first.

### Minimal complete example: Counter

```lua
local template = {}

function template.schema()
    return {
        sections = {{
            title = "Counter",
            fields = {
                { key = "title", label = "Title", kind = "string", defaultValue = "My Counter" },
                { key = "count", label = "Count", kind = "number", defaultValue = 0 },
                { key = "step",  label = "Step",  kind = "number", defaultValue = 1 },
            }
        }}
    }
end

function template.metadata()
    return {
        width = 220, height = 280,
        windowShape = { type = "roundedRect", value = 20 },
        alwaysOnTop = true,
    }
end

function template.layout(data, theme, context)
    return VStack(20, {
        Text(data.title, { font = "title2", weight = "bold", color = theme.foreground }),
        Spacer(),
        Text(tostring(math.floor(data.count)), {
            font = "largeTitle", weight = "bold", color = theme.accent,
        }),
        Spacer(),
        HideInExport(
            HStack(12, {
                Button("-", "decrement", { style = "bordered" }),
                Button("+", "increment", { style = "bordered" }),
            })
        ),
    })
end

function template.onAction(name, data)
    if name == "increment" then
        data.count = data.count + data.step
    elseif name == "decrement" then
        data.count = data.count - data.step
    end
    return data
end

return template
```

## 3. Layout Constructors

The host registers global Lua functions that create `LayoutNode` userdata values. Scripts compose these to build view trees. All constructor arguments are positional.

### Layout

| Constructor | Signature | Notes |
|-------------|-----------|-------|
| `VStack` | `(spacing, { children })` | Vertical stack |
| `HStack` | `(spacing, { children })` | Horizontal stack |
| `ZStack` | `({ children })` | Overlay stack |
| `ScrollView` | `(child)` or `(axes, child)` | axes: `"vertical"`, `"horizontal"`, `"both"` |
| `Padding` | `(amount, child)` or `(edges, amount, child)` | edges: `"all"`, `"horizontal"`, `"vertical"`, `"top"`, `"bottom"`, `"leading"`, `"trailing"` |
| `Frame` | `({ width?, height?, alignment? }, child)` | alignment: `"center"`, `"leading"`, `"trailing"`, `"top"`, `"bottom"`, `"topLeading"`, `"topTrailing"`, `"bottomLeading"`, `"bottomTrailing"` |
| `Background` | `(color, cornerRadius, child)` | color is a hex string |

### Display

| Constructor | Signature | Notes |
|-------------|-----------|-------|
| `Text` | `(content, { style? })` | Style table documented below |
| `Image` | `(systemName, { size?, color? })` | SF Symbol name |
| `Divider` | `()` | Horizontal rule |
| `Spacer` | `(minLength?)` | Flexible space |
| `ProgressBar` | `(value, total, { color? })` | Linear progress indicator |
| `ColorDot` | `(hex, size)` | Filled circle |

### Input

| Constructor | Signature | Notes |
|-------------|-----------|-------|
| `TextField` | `(fieldKey, placeholder)` | Binds to string field in store |
| `NumberField` | `(fieldKey)` | Binds to number field in store |
| `Toggle` | `(fieldKey, label)` | Binds to bool field in store |
| `Picker` | `(fieldKey, { options })` | Each option: `{ value = "...", label = "..." }` |
| `Slider` | `(fieldKey, min, max, step?)` | Binds to number field in store |
| `Button` | `(label, action, { style? })` | style: `"default"`, `"bordered"`, `"borderedProminent"`, `"plain"` |

### Control / Data

| Constructor | Signature | Notes |
|-------------|-----------|-------|
| `ForEach` | `(arrayFieldKey, builderFn)` | Builder receives `(item, 1-based-index)`, must return a LayoutNode |
| `If` | `(condition, thenNode, elseNode?)` | Conditional rendering |
| `HideInExport` | `(child)` | Renders only during interactive/live display |
| `OnlyInExport` | `(child)` | Renders only during PDF/image export |

### TextStyle Table

The second argument to `Text()` is an optional table with these keys:

| Key | Values | Default |
|-----|--------|---------|
| `font` | `"largeTitle"`, `"title"`, `"title2"`, `"title3"`, `"headline"`, `"subheadline"`, `"body"`, `"callout"`, `"footnote"`, `"caption"`, `"caption2"` | `"body"` |
| `weight` | `"ultraLight"`, `"thin"`, `"light"`, `"regular"`, `"medium"`, `"semibold"`, `"bold"`, `"heavy"`, `"black"` | `"regular"` |
| `color` | Hex string (e.g. `"#ff0000"`) or `nil` for theme foreground | `nil` |
| `alignment` | `"leading"`, `"center"`, `"trailing"` | `"leading"` |
| `lineLimit` | Integer or `nil` for unlimited | `nil` |

## 4. Schema Declaration

Lua scripts declare their schema by returning a table from `template.schema()`. The structure mirrors the host's `Schema` / `SchemaSection` / `FieldDescriptor` types.

```lua
function template.schema()
    return {
        sections = {
            {
                title = "Section Name",
                fields = {
                    { key = "fieldKey", label = "Display Name", kind = "string", defaultValue = "hello" },
                    { key = "count",    label = "Count",        kind = "number", defaultValue = 0 },
                }
            }
        }
    }
end
```

### Field descriptor keys

| Key | Type | Required | Description |
|-----|------|----------|-------------|
| `key` | string | yes | Storage key in the `.slop` data dictionary |
| `label` | string | yes | Display name for inspectors |
| `kind` | string | yes | One of the FieldKind values below |
| `defaultValue` | any | no | Initial value when creating a new document |
| `options` | array | no | For `enumeration` kind: `{ { value = "a", label = "A" }, ... }` |
| `itemSchema` | table | no | For `array` kind: nested `{ fields = { ... } }` describing each item |

### FieldKind values

| Kind | Lua defaultValue type | Notes |
|------|----------------------|-------|
| `"string"` | string | |
| `"richText"` | string | |
| `"number"` | number | |
| `"bool"` | boolean | |
| `"color"` | string | Hex format, e.g. `"#4a90d9"` |
| `"date"` | number | Unix timestamp |
| `"image"` | string | Image reference |
| `"enumeration"` | string | Must also provide `options` |
| `"array"` | table | Empty `{}` for default; must provide `itemSchema` |
| `"record"` | table | String-keyed table |

### Nested schemas

Array fields support nested item schemas for structured items:

```lua
local BudgetItem = {
    fields = {
        { key = "name",   label = "Name",   kind = "string", defaultValue = "" },
        { key = "amount", label = "Amount", kind = "number", defaultValue = 0 },
    }
}

-- In the schema:
{ key = "items", label = "Items", kind = "array", defaultValue = {}, itemSchema = BudgetItem }
```

This contrasts with the v3 compiled approach where schemas are generated by `@Template` / `@Record` macros at build time. In Lua, the schema is declared as a plain data structure and parsed at load time by `parseSchema` in `LuaBridge.swift`.

## 5. Metadata Declaration

`template.metadata()` returns a table describing the window and display properties.

```lua
function template.metadata()
    return {
        width = 360,
        height = 520,
        windowShape = { type = "roundedRect", value = 16 },
        theme = "cool",
        alwaysOnTop = true,
        category = "finance",
    }
end
```

### Metadata keys

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `width` | number | 400 | Window width in points |
| `height` | number | 600 | Window height in points |
| `windowShape` | table | `roundedRect(16)` | See shape types below |
| `theme` | string | nil | Theme name override |
| `alwaysOnTop` | boolean | true | Float above other windows |
| `category` | string | nil | Template gallery category |

### Window shape types

```lua
{ type = "roundedRect", value = 20 }   -- corner radius
{ type = "circle" }                     -- diameter = min(width, height)
{ type = "capsule" }                    -- pill shape
{ type = "path", value = "M0 0..." }   -- SVG path (declared, not fully implemented)
{ type = "skin", value = "skin.png" }  -- bitmap window skin
```

## 6. Actions

Button taps dispatch string action names to `template.onAction(name, data)`. The function receives the action name and a snapshot of the current data as a Lua table. It returns the modified table, which the host writes back to the store.

```lua
function template.onAction(name, data)
    if name == "increment" then
        data.count = data.count + data.step
    elseif name == "addCategory" then
        if not data.categories then data.categories = {} end
        table.insert(data.categories, { name = "New", color = "#4a90d9", items = {} })
    end
    return data
end
```

Key properties:

1. Stateless. Each call receives a fresh snapshot. The Lua script holds no mutable state between calls.
2. The returned table completely replaces the data in the store. Omitted keys are removed.
3. If `onAction` is not defined, button taps are silently ignored.
4. If it returns `nil` (or a non-table), the store is not updated.

## 7. Data Flow

### FieldValue to Lua type mapping

| FieldValue | Lua type | Notes |
|------------|----------|-------|
| `.string(s)` | string | |
| `.number(n)` | number | |
| `.bool(b)` | boolean | |
| `.color(hex)` | string | Hex string like `"#ff0000"` |
| `.date(d)` | number | Unix timestamp (`timeIntervalSince1970`) |
| `.image(ref)` | string | |
| `.array(items)` | table (ipairs) | 1-indexed sequential table |
| `.record(dict)` | table (pairs) | String-keyed table |
| `.null` | nil | |

The reverse mapping uses a heuristic: a Lua table with `rawlen > 0` or no string keys is treated as an array; otherwise it is treated as a record.

### Render cycle

```text
RawTemplateStore.values changes
  |
  v
@ObservedObject triggers SwiftUI update
  |
  v
ScriptedTemplateBody.buildLayout()
  |
  v
LuaTemplateEngine.callLayout(store, theme, renderTarget)
  |
  v
pushFieldValue(store.values) --> Lua data table
ThemeProxy(theme) ---------> Lua theme table
renderTarget -------------> Lua context.renderTarget
  |
  v
Lua: template.layout(data, theme, context)
  |
  v
LayoutNode tree returned as userdata
  |
  v
ScriptedTemplateRenderer.renderNode(root)
  |
  v
SwiftUI view tree
```

### Theme table

The theme is passed as a flat table of six hex color strings:

```lua
theme.foreground  -- "#1a1a1a"
theme.background  -- "#ffffff"
theme.secondary   -- "#8e8e93"
theme.accent      -- "#007aff"
theme.surface     -- "#f2f2f7"
theme.divider     -- "#c6c6c8"
```

These are converted from the host's `SlopTheme` via `ThemeProxy`. The values depend on which theme the user has selected.

### Render context table

The optional third `context` argument currently exposes export state:

```lua
context.renderTarget  -- "interactive", "pdfExport", or "imageExport"
```

Use this when export markup needs to differ from the live UI. For simple cases, prefer `HideInExport(...)` and `OnlyInExport(...)` so scripts can hide buttons, text fields, sliders, and other live controls without duplicating an entire layout.

### Input bindings

Input constructors (`TextField`, `NumberField`, `Toggle`, `Picker`, `Slider`) bind directly to the `RawTemplateStore` by field key. They read and write values through SwiftUI `Binding`s at render time. These do not go through Lua — the renderer creates native bindings against the store.

`Button` is the only input that routes through Lua via `onAction`.

For export output, the host renders the same layout tree with `context.renderTarget` set to `"pdfExport"` or `"imageExport"`. Inputs are still valid nodes, but export-facing scripts should usually wrap interactive controls with `HideInExport(...)` or branch on `context.renderTarget` to produce a non-interactive export view.

## 8. Sandbox

The Lua state is created with a restricted standard library:

- **Whitelisted modules**: `string`, `table`, `math`
- **Removed globals**: `dofile`, `loadfile`, `load`, `collectgarbage`
- **Not loaded**: `io`, `os`, `debug`, `package`

An instruction-count hook fires every 10,000 VM instructions. If the cumulative count exceeds 10,000,000 instructions in a single call (`schema`, `metadata`, `layout`, or `onAction`), the engine throws `executionLimitExceeded`. The counter resets before each call.

Each `LuaTemplateEngine` instance owns a single `LuaState` for the lifetime of that template. The state is created at load time and closed on deinit.

## 9. Installed Layout

Scripted templates are installed at:

```
~/.hitslop/templates/<template-id>/<version>/
    template.json      manifest (required)
    script.lua         Lua source (required, name matches scriptFile)
    preview.png        gallery preview (optional)
```

### template.json for a scripted template

```json
{
  "id": "user.counter",
  "name": "Counter",
  "version": "1.0.0",
  "minimumHostVersion": "1.0.0",
  "scriptFile": "script.lua",
  "metadata": {
    "width": 220,
    "height": 280,
    "windowShape": { "type": "roundedRect", "value": 20 },
    "alwaysOnTop": true,
    "titleBarHidden": true
  },
  "schema": {
    "sections": [{
      "title": "Counter",
      "fields": [
        { "key": "title", "label": "Title", "kind": "string", "required": true,
          "defaultValue": { "type": "string", "value": "My Counter" }, "constraints": [] },
        { "key": "count", "label": "Count", "kind": "number", "required": true,
          "defaultValue": { "type": "number", "value": 0 }, "constraints": [] }
      ]
    }]
  }
}
```

The key difference from a Tier 1 manifest is `scriptFile` instead of `bundleFile`. The `TemplateManifest.isScripted` property checks for this:

```swift
public var isScripted: Bool { scriptFile != nil }
```

The schema and metadata in `template.json` are the source of truth for the host. The Lua `schema()` and `metadata()` functions are currently called at load time but not used for host-level decisions like inspector building — the manifest JSON is.

## 10. Host Integration

The scripted template system plugs into the existing v3 architecture at two points.

### Registry (discovery)

`SlopTemplateRegistry.readEntry` checks for `scriptFile` in the manifest. If present, it creates an `Entry` with `scriptURL` set and `bundleURL` nil. The entry's `isScripted` flag comes from the manifest.

```text
template.json has scriptFile?
  |
  yes --> Entry(scriptURL: ..., bundleURL: nil)
  no  --> Entry(scriptURL: nil, bundleURL: ...)
```

### Window (instantiation)

`SlopTemplateWindow.init` branches on the entry type:

```text
entry.builtInType != nil?  -->  direct instantiation (Tier 0)
entry.scriptURL != nil?    -->  ScriptedTemplate.create(scriptPath:manifest:rawStore:) (Tier 2)
entry.bundleURL != nil?    -->  SlopTemplateBundleLoader.load (Tier 1)
```

`ScriptedTemplate` conforms to `AnySlopTemplate`. Its `body()` returns a `ScriptedTemplateBody` view that calls `LuaTemplateEngine.callLayout` on each render and passes the resulting `LayoutNode` to `ScriptedTemplateRenderer`.

### Rendering pipeline

```text
┌─────────────────────────────────────────────────────────┐
│ ScriptedTemplate : AnySlopTemplate                      │
│                                                          │
│   body() -> AnyView                                     │
│     └─ ScriptedTemplateBody                             │
│          ├─ @ObservedObject store: RawTemplateStore     │
│          ├─ engine: LuaTemplateEngine                   │
│          │    ├─ callLayout(store, theme) -> LayoutNode  │
│          │    └─ callOnAction(name, store) -> data?      │
│          └─ ScriptedTemplateRenderer                    │
│               └─ renderNode(LayoutNode) -> AnyView      │
└─────────────────────────────────────────────────────────┘
```

Everything else — the `ShapedWindow`, hover toolbar, inspector panel, undo/redo, file watching, theme injection — works identically to Tier 0 and Tier 1 templates. The scripted template system only replaces the template body rendering.

## 11. Current Limitations

These are current architectural constraints of the Lua scripted template system:

1. **No hot reload.** Changing the `.lua` file on disk requires closing and reopening the document. The `LuaState` is created once at load time.

2. **No async or networking.** The sandbox does not expose `io`, `os`, coroutines, or any HTTP primitives. Templates cannot fetch remote data.

3. **No custom drawing.** Templates can only compose the fixed set of layout constructors. There is no Canvas, Path, or custom shape support.

4. **ForEach uses offset identity.** `ScriptedTemplateRenderer` renders `ForEach` items keyed by array offset (`id: \.offset`), not stable IDs. This means list animations and state preservation across reorders do not work correctly.

5. **Full tree rebuild on every render.** Each `callLayout` invocation runs the entire Lua `layout()` function and produces a new `LayoutNode` tree. There is no diffing or incremental update.

6. **AnyView type erasure.** The recursive `renderNode` function returns `AnyView` at every level, which limits SwiftUI's ability to optimize view identity and transitions.

7. **Single-threaded.** `LuaTemplateEngine` is `@MainActor`. Layout computation blocks the main thread.

8. **No template-to-template communication.** Each scripted template runs in its own isolated `LuaState`.

9. **Dual schema source.** The manifest JSON and the Lua `schema()` function both describe the schema. The host uses the manifest JSON for inspectors and data decoding; the Lua function is called but its result is not currently used by the host. This means the two can drift out of sync.

10. **Instruction limit is per-call, not per-frame.** A template that calls `layout()` frequently (e.g. during slider dragging) gets a fresh 10M instruction budget each time.

## Source Files

| File | Role |
|------|------|
| `Packages/SlopCore/Sources/SlopUI/ScriptedTemplates/LuaBridge.swift` | FieldValue conversion, layout constructors, schema/metadata parsing |
| `Packages/SlopCore/Sources/SlopUI/ScriptedTemplates/LuaTemplateEngine.swift` | Lua state lifecycle, sandbox setup, call dispatching |
| `Packages/SlopCore/Sources/SlopUI/ScriptedTemplates/ScriptedTemplate.swift` | `AnySlopTemplate` conformance, factory method |
| `Packages/SlopCore/Sources/SlopUI/ScriptedTemplates/ScriptedTemplateRenderer.swift` | `LayoutNode` to SwiftUI recursive renderer |
| `Packages/SlopCore/Sources/SlopUI/ScriptedTemplates/DataProxy.swift` | Store bridge (currently used for snapshot access) |
| `Packages/SlopCore/Sources/SlopUI/ScriptedTemplates/ThemeProxy.swift` | Theme to hex string conversion |
| `Packages/SlopKit/Sources/SlopKit/Layout/LayoutNode.swift` | `LayoutNode` enum definition |
| `Packages/SlopKit/Sources/SlopKit/Layout/TextStyle.swift` | `TextStyle` struct and enums |
| `Packages/SlopKit/Sources/SlopKit/Metadata/TemplateManifest.swift` | `scriptFile` field on manifest |
| `Packages/SlopCore/Sources/SlopUI/SlopTemplates/SlopTemplateRegistry.swift` | Tier 2 discovery branch |
| `Packages/SlopCore/Sources/SlopUI/SlopTemplates/SlopTemplateWindow.swift` | Tier 2 instantiation branch |
