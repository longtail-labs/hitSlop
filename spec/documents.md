# Documents

A `.slop` document is a macOS package (directory) that references a template by ID and stores user data as key-value pairs.

## Package Structure

```
MyDocument.slop/
  slop.json         ← required: document manifest
  content.md        ← optional: sidecar file for file-kind fields
  notes.txt         ← optional: additional sidecar files
```

The package directory uses the `.slop` extension. The primary manifest is always `slop.json`. Sidecar files are created automatically for schema fields with `kind: "file"`.

## slop.json Format

### SlopFileEnvelope (raw JSON on disk)

```json
{
  "templateID": "com.hitslop.templates.budget-tracker",
  "templateVersion": "1.0.0",
  "data": {
    "title": "Q1 Budget",
    "budget": 5000,
    "items": [
      { "name": "Rent", "amount": 1200 }
    ]
  },
  "theme": "studio-noir",
  "alwaysOnTop": true,
  "windowShape": { "type": "roundedRect", "value": 16 }
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `templateID` | string | yes | Reverse-DNS template identifier |
| `templateVersion` | string | yes | Semantic version of the template |
| `data` | object | yes | User data as raw JSON values |
| `theme` | string | no | Theme ID override (e.g. `"studio-noir"`) |
| `alwaysOnTop` | bool | no | Override template's always-on-top setting |
| `windowShape` | object | no | Override window shape (see below) |

### Window Shape

```json
{ "type": "roundedRect", "value": 16 }
{ "type": "circle" }
{ "type": "capsule" }
{ "type": "path", "value": "M0 0 L100 0..." }
{ "type": "skin", "value": "player-skin.png" }
```

## Loading Flow

1. **Read**: `SlopFile.loadEnvelope(from:)` reads `slop.json` → `SlopFileEnvelope`
2. **Resolve template**: Registry looks up `(templateID, templateVersion)` across all tiers
3. **Decode**: `SlopFile(envelope:schema:)` converts raw `JSONValue` to typed `FieldValue` using the template's schema for type hints
4. **Merge defaults**: Schema default values fill any keys missing from the document data
5. **Store creation**: `RawTemplateStore` initialized with merged values, wired to persistence

## SlopFile (typed model)

After schema resolution, the document is represented as a `SlopFile` with typed data:

```swift
public struct SlopFile {
    var templateID: String
    var templateVersion: String
    var data: [String: FieldValue]
    var theme: String?
    var alwaysOnTop: Bool?
    var windowShape: WindowShape?
}
```

## Data Types (FieldValue)

| FieldValue Case | JSON Representation | Description |
|-----------------|-------------------|-------------|
| `.string(s)` | `"hello"` | Text value |
| `.number(n)` | `42` or `3.14` | Numeric value |
| `.bool(b)` | `true` / `false` | Boolean |
| `.color(hex)` | `"#4a90d9"` | Hex color string |
| `.date(d)` | `1704067200` | Unix timestamp |
| `.image(ref)` | `"photo.png"` | Image reference |
| `.array(items)` | `[...]` | Ordered list of FieldValue |
| `.record(dict)` | `{...}` | String-keyed FieldValue map |
| `.null` | `null` | Absent value |

## Persistence

The document model (`SlopTemplateDocumentModel`) manages two-way sync between the in-memory store and the file on disk.

### Writes

When the user edits data through the template UI:

1. Input binding updates `RawTemplateStore`
2. Store's persist handler calls `dataDidChange(_:)`
3. Previous values are pushed to the undo stack
4. Redo stack is cleared
5. A debounced write is scheduled (300ms delay)
6. `persistToDisk()` encodes `SlopFile` → `SlopFileEnvelope` → JSON and writes atomically

After writing, a 500ms suppression window prevents the file watcher from triggering a reload of our own write.

### File Watching

A `DispatchSource` file system watcher monitors `slop.json` for external changes (e.g. CLI writes, text editor edits):

1. File event detected (write/delete/rename)
2. 100ms debounce to coalesce rapid events
3. `reloadFromDisk()` re-reads and re-decodes the envelope
4. If data differs from current state, the store is updated via `externalUpdate()`
5. The watcher is restarted (handles atomic-replace writes)

### Sidecar Files

Schema fields with `kind: "file"` get companion sidecar files inside the package:

- Text sidecars (e.g. markdown content) are read/written as UTF-8 strings
- Binary sidecars (e.g. images) are read/written as raw `Data`
- Each sidecar has its own file watcher and 500ms write debounce
- Sidecar persistence is managed by `SidecarStore`

## Undo / Redo

- Stack-based with a maximum of 100 levels
- Each snapshot is a complete copy of the data dictionary
- Undo pops the last snapshot, pushes current data to redo stack
- Redo pops the next snapshot, pushes current data to undo stack
- Both trigger `externalUpdate()` on the store and debounced persistence
- External file changes push an undo entry but clear the redo stack
