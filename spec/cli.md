# CLI Reference

The `slop` command-line interface manages documents, templates, and themes. It communicates with the running hitSlop app via JSON-RPC 2.0 over a Unix socket.

## Installation

The CLI is installed automatically when the app launches. It creates a symlink:

```
~/.hitslop/bin/slop → /path/to/hitSlop.app/Contents/MacOS/hitSlop
```

Add `~/.hitslop/bin` to your `PATH` to use `slop` directly:

```bash
export PATH="$HOME/.hitslop/bin:$PATH"
```

CLI mode is activated when the process name is `slop` (via the symlink) or when `--cli` is passed.

## Commands

### Document Operations

#### `slop create`

Create a new `.slop` document.

```
slop create <templateID> [outputPath]
```

| Argument/Option | Type | Required | Description |
|----------------|------|----------|-------------|
| `templateID` | string | yes | Template identifier |
| `outputPath` | string | no | Output file path |
| `--data` | string | no | Initial data as JSON |
| `--theme` | string | no | Theme name to apply |
| `--open` | flag | no | Open in app after creation |

```bash
slop create com.hitslop.templates.budget-tracker ~/Documents/Budget.slop
slop create com.hitslop.templates.budget-tracker Budget.slop \
  --data '{"title":"Q1 2024","budget":5000}' \
  --theme studio-noir --open
```

#### `slop read`

Read and display document data.

```
slop read <path>
```

| Option | Type | Description |
|--------|------|-------------|
| `--raw` | flag | Show raw JSON envelope (no schema resolution) |
| `--field` | string | Show single field value |

```bash
slop read Budget.slop
slop read Budget.slop --field title
slop read Budget.slop --raw
```

#### `slop write`

Update document fields.

```
slop write <path>
```

| Option | Type | Description |
|--------|------|-------------|
| `--field` | string (repeatable) | Set field as `key=value` |
| `--data` | string | Merge JSON data |
| `--theme` | string | Change theme |

```bash
slop write Budget.slop --field title="Q2 2024" --field budget=6000
slop write Budget.slop --data '{"spent":3200,"remaining":1800}'
slop write Budget.slop --theme midnight-ink
```

#### `slop validate`

Validate a document against its template schema.

```
slop validate <path>
```

Outputs "Valid" or lists validation errors. Exits with failure code if invalid.

#### `slop info`

Show document metadata.

```
slop info <path>
```

Displays: template ID, name, version, field count, and current theme.

#### `slop open`

Open a document in the app.

```
slop open <path>
```

#### `slop export`

Export a document to PDF or PNG.

```
slop export <path>
```

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `--format` | string | `png` | Output format: `pdf` or `png` |
| `--output` | string | auto | Output file path |
| `--theme` | string | none | Override theme for export |
| `--scale` | int | `2` | PNG scale factor |

```bash
slop export Budget.slop --format pdf --output report.pdf
slop export Budget.slop --format png --scale 3 --theme paper-ledger
```

### Template Management

#### `slop templates`

List installed templates.

```
slop templates [--json]
```

Shows: id, name, version, type (built-in / scripted / external). Use `--json` for machine-readable output.

```bash
slop templates
slop templates --json | jq '.[] | select(.type == "scripted")'
```

#### `slop schema`

Print a template's data schema.

```
slop schema <templateID>
```

| Option | Type | Description |
|--------|------|-------------|
| `--json-schema` | flag | Output as JSON Schema format |
| `--fields` | flag | Show fields-only table |

```bash
slop schema com.hitslop.templates.budget-tracker
slop schema com.hitslop.templates.budget-tracker --fields
```

### Theme Management

#### `slop themes list`

List available themes.

```
slop themes list [--json]
```

Shows: id, name, group, source (bundled / user).

#### `slop themes create`

Create a theme from explicit colors.

```
slop themes create <id>
```

| Option | Type | Required | Description |
|--------|------|----------|-------------|
| `--background` | string | yes | Background color (hex) |
| `--foreground` | string | yes | Foreground/text color (hex) |
| `--secondary` | string | yes | Secondary text color (hex) |
| `--accent` | string | yes | Accent color (hex) |
| `--surface` | string | yes | Surface/card color (hex) |
| `--divider` | string | yes | Divider color (hex) |
| `--display-name` | string | no | Human-readable name |
| `--group` | string | no | Theme group (default: "Other") |
| `--json` | flag | no | Output as JSON instead of saving |

```bash
slop themes create my-theme \
  --background "#0a0e27" --foreground "#e8e6e3" \
  --accent "#5fc0e8" --secondary "#8e8e93" \
  --surface "#1c1c1e" --divider "#38383a" \
  --display-name "Midnight Ocean" --group Dark
```

Saves to `~/.hitslop/themes/<id>.theme`.

#### `slop themes derive`

Derive a complete theme from a single accent color.

```
slop themes derive <id>
```

| Option | Type | Required | Description |
|--------|------|----------|-------------|
| `--accent` | string | yes | Accent color (hex) |
| `--light` | flag | no | Generate light theme (default: dark) |
| `--display-name` | string | no | Human-readable name |
| `--group` | string | no | Theme group |
| `--json` | flag | no | Output as JSON instead of saving |

```bash
slop themes derive ocean-dark --accent "#5fc0e8"
slop themes derive sunset-light --accent "#ff8c42" --light --group Warm
```

#### `slop themes validate`

Validate a theme file.

```
slop themes validate <path> [--json]
```

Checks JSON structure and color values. Reports issues or confirms validity.

#### `slop themes delete`

Delete a user theme.

```
slop themes delete <id>
```

Removes `~/.hitslop/themes/<id>.theme`. Only works for user-created themes.

### App Control

#### `slop status`

Check if the hitSlop app is running.

```
slop status
```

Shows PID and version if running, or reports not running.

#### `slop version`

Print version information.

```
slop version
```

Queries the running app for its version. If not running, reports unknown.

#### `slop identify`

Show configuration paths.

```
slop identify
```

Displays: socket path, PID file, config dir, templates dir, themes dir, CLI bin path.

#### `slop picker`

Show the template picker window in the app.

```
slop picker
```

### Recent Documents

#### `slop recents`

List recently opened documents.

```
slop recents [--json] [--clear]
```

- Default: numbered list of file paths
- `--json`: JSON array output
- `--clear`: clear the recents list

## IPC Protocol

The CLI communicates via JSON-RPC 2.0 over a Unix socket at `~/.hitslop/slop.sock`.

### Methods

| Method | Description |
|--------|-------------|
| `status` | App status (running, PID, version) |
| `template.list` | List installed templates |
| `template.schema` | Get template schema |
| `theme.list` | List available themes |
| `theme.write` | Create/save a theme |
| `theme.derive` | Derive theme from accent color |
| `theme.delete` | Delete a user theme |
| `theme.validate` | Validate a theme file |
| `document.create` | Create a new document |
| `document.read` | Read document data |
| `document.write` | Update document fields |
| `document.validate` | Validate against schema |
| `document.info` | Get document metadata |
| `document.open` | Open document in app |
| `document.export` | Export to PDF/PNG |
| `document.setTheme` | Change document theme |
| `document.setShape` | Change window shape |
| `recents.list` | List recent documents |
| `recents.clear` | Clear recents |
| `picker.show` | Show template picker |

## Common Workflows

### Create and populate a document

```bash
# Find a template
slop templates | grep budget

# Check its schema
slop schema com.hitslop.templates.budget-tracker --fields

# Create with initial data
slop create com.hitslop.templates.budget-tracker Budget.slop \
  --data '{"title":"Q1 2024","budget":5000}' --theme studio-noir

# Open it
slop open Budget.slop
```

### Update and export

```bash
slop write Budget.slop --field spent=3200
slop validate Budget.slop
slop export Budget.slop --format pdf --output Q1-Report.pdf
```

### Create a custom theme

```bash
slop themes derive my-brand --accent "#7c3aed" --group Professional
slop write Budget.slop --theme my-brand
slop info Budget.slop
```

### Batch export

```bash
for doc in *.slop; do
  slop export "$doc" --format pdf --output "${doc%.slop}.pdf"
done
```

## Error Handling

Most commands require the running app for IPC. If the app is not running:

- Commands that need app state will fail with "hitSlop app is not running"
- Some commands work offline: `themes create`, `themes delete`, `identify`
- Check status with `slop status`

All commands support `--help` for usage details.
