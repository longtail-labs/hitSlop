# Architecture

hitSlop is a macOS document viewer for HyperClay template documents. Each `.slop` document is a tiny JSON package that references a centrally-installed template by ID. Templates define the UI and data schema; documents store user data.

## Document Model

A `.slop` file is a directory (package) containing `slop.json` plus optional sidecar files. The manifest references a template by reverse-DNS ID and stores user data as key-value pairs:

```
MyBudget.slop/
  slop.json        ← templateID, version, data, theme, windowShape
  content.md       ← sidecar file (optional, for file-kind fields)
```

See [Documents](documents.md) for the full format specification.

## Three-Tier Template System

Templates provide the schema, metadata, and UI for documents. There are three tiers:

| Tier | Type | Location | Key Trait |
|------|------|----------|-----------|
| 0 | Built-in | Compiled into app binary | Always available, zero discovery cost |
| 1 | Bundle | `~/.hitslop/templates/<id>/<ver>/Template.bundle` | Full Swift/SwiftUI, requires Xcode build |
| 2 | Lua Script | `~/.hitslop/templates/<id>/<ver>/script.lua` | No compilation, sandboxed, declarative layout |

All tiers produce a `template.json` manifest declaring `id`, `name`, `version`, `metadata`, and `schema`. The registry scans all tiers at startup. See [Templates](templates.md) for details.

## Loading Pipeline

```
.slop package on disk
  │
  ├─ Read slop.json → SlopFileEnvelope (raw JSON)
  │
  ├─ Resolve template by (templateID, templateVersion)
  │     Registry checks: built-in → bundles → scripts
  │
  ├─ Decode envelope with schema → SlopFile (typed FieldValue data)
  │
  ├─ Merge schema defaults into data (defaults fill missing keys)
  │
  ├─ Create RawTemplateStore with merged values
  │
  └─ Instantiate template → inject store → body() → window
```

## Data Flow

```
User interaction
  │
  ├─ Input bindings update RawTemplateStore directly
  │
  ├─ Store.persist handler fires → dataDidChange()
  │     ├─ Push undo snapshot
  │     └─ Debounced write to disk (300ms)
  │
  ├─ File watcher detects external changes → reloadFromDisk()
  │     ├─ Re-decode envelope
  │     ├─ Merge with schema defaults
  │     └─ externalUpdate() on store
  │
  └─ Template body re-renders via @ObservedObject on store
```

Undo/redo is stack-based with a 100-level limit. Each undo snapshot is a complete copy of the data dictionary.

## Key Directories

| Path | Contents |
|------|----------|
| `~/.hitslop/templates/` | Installed template bundles and Lua scripts |
| `~/.hitslop/themes/` | User-authored theme JSON files |
| `~/.hitslop/skins/` | PNG bitmap window skins |
| `~/.hitslop/bin/slop` | CLI symlink to app executable |
| `~/.hitslop/slop.sock` | IPC Unix socket (when app is running) |
| `~/.hitslop/slop.pid` | PID file (when app is running) |

## Theme System

Themes are JSON files defining colors, typography, and spacing. The app ships 22 built-in themes organized into 11 groups. Users can create custom themes or derive new ones from a single accent color. Themes are resolved per-document: the document's `theme` field overrides the template default. See [Themes](themes.md).

## Window System

Documents render in borderless `ShapedWindow` instances. Window shape is determined by the template metadata or document override:

- **roundedRect(radius)** — CAShapeLayer mask
- **circle / capsule** — Vector path mask
- **skin(filename)** — PNG bitmap with alpha-channel hit testing

The top 28pt of each window is a drag bar for window movement. Interactive controls in the drag bar region still receive events. See [Skins](skins.md).

## CLI and IPC

The `slop` CLI communicates with the running app via JSON-RPC 2.0 over a Unix socket at `~/.hitslop/slop.sock`. Commands cover document CRUD, template/theme management, and app control. See [CLI](cli.md).

## Source Layout

| Package | Path | Purpose |
|---------|------|---------|
| SlopKit | `Packages/SlopKit/` | Schema types, macros, protocol, UI components |
| SlopCore | `Packages/SlopCore/` | SlopUI (host integration), SlopAI (Firebase) |
| SlopTemplates | `Packages/SlopTemplates/` | Built-in template implementations |
| SlopCLI | `Packages/SlopCLI/` | CLI commands (ArgumentParser) |
| SlopIPC | `Packages/SlopIPC/` | IPC protocol types and transport |
| App Shell | `hitSlop/hitSlop/` | Thin Xcode app wrapper |
