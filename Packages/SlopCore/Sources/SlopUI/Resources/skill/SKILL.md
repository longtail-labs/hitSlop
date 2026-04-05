---
name: hitslop
description: Create and manage .slop documents — template-powered, themed, plain-text documents for any purpose.
allowed-tools: Bash(slop:*)
---

# hitSlop

hitSlop turns plain data into richly-themed documents. A `.slop` file is a tiny JSON file that references a template and stores your data — recipes, budgets, invoices, legal agreements, app screenshots, and more. 74+ built-in templates. 22 built-in themes. Create, read, write, and export from the CLI.

## Key Concepts

- **Documents (.slop)**: JSON files containing a templateID, data fields, and optional theme/windowShape overrides
- **Templates**: Define UI + schema. 74+ built-in, plus scripted (Lua) and external bundles
- **Themes**: JSON color/typography schemes at `~/.hitslop/themes/`
- **CLI**: `slop` command installed at `~/.hitslop/bin/slop`

## Built-in Templates

Use `slop schema <id>` to see available fields for any template.

### Productivity
- `com.hitslop.templates.todo-list` — Todo List
- `com.hitslop.templates.kanban` — Kanban Board
- `com.hitslop.templates.daily-planner` — Daily Planner
- `com.hitslop.templates.weekly-planner` — Weekly Planner
- `com.hitslop.templates.pomodoro` — Pomodoro Timer
- `com.hitslop.templates.study-timer` — Study Timer
- `com.hitslop.templates.goal-tracker` — Goal Tracker
- `com.hitslop.templates.okr-tracker` — OKR Tracker
- `com.hitslop.templates.project-tracker` — Project Tracker
- `com.hitslop.templates.meeting-notes` — Meeting Notes
- `com.hitslop.templates.team-standup` — Team Standup
- `com.hitslop.templates.weekly-review` — Weekly Review

### Finance
- `com.hitslop.templates.budget-tracker` — Budget Tracker
- `com.hitslop.templates.expense-tracker` — Expense Tracker
- `com.hitslop.templates.invoice` — Invoice
- `com.hitslop.templates.loan-calculator` — Loan Calculator
- `com.hitslop.templates.net-worth` — Net Worth
- `com.hitslop.templates.fire-calculator` — FIRE Calculator
- `com.hitslop.templates.debt-payoff-planner` — Debt Payoff Planner
- `com.hitslop.templates.side-hustle-tracker` — Side Hustle Tracker
- `com.hitslop.templates.financial-goals-simulator` — Financial Goals Simulator
- `com.hitslop.templates.tax-optimizer` — Tax Optimizer
- `com.hitslop.templates.investment-portfolio` — Investment Portfolio
- `com.hitslop.templates.portfolio-allocator` — Portfolio Allocator
- `com.hitslop.templates.subscription-tracker` — Subscription Tracker

### Health & Wellness
- `com.hitslop.templates.fitness-log` — Fitness Log
- `com.hitslop.templates.workout-planner` — Workout Planner
- `com.hitslop.templates.water-intake` — Water Intake
- `com.hitslop.templates.meal-planner` — Meal Planner
- `com.hitslop.templates.medication-schedule` — Medication Schedule
- `com.hitslop.templates.sleep-tracker` — Sleep Tracker
- `com.hitslop.templates.symptom-tracker` — Symptom Tracker

### Writing & Notes
- `com.hitslop.templates.simple-note` — Simple Note
- `com.hitslop.templates.markdown-editor` — Markdown Editor
- `com.hitslop.templates.sticky-notes` — Sticky Notes
- `com.hitslop.templates.brain-dump` — Brain Dump
- `com.hitslop.templates.gratitude-journal` — Gratitude Journal
- `com.hitslop.templates.decision-journal` — Decision Journal
- `com.hitslop.templates.writing-tracker` — Writing Tracker
- `com.hitslop.templates.daily-quote` — Daily Quote

### Education
- `com.hitslop.templates.flash-cards` — Flash Cards
- `com.hitslop.templates.grade-tracker` — Grade Tracker
- `com.hitslop.templates.class-schedule` — Class Schedule
- `com.hitslop.templates.reading-list` — Reading List

### Lifestyle
- `com.hitslop.templates.recipe` — Recipe Card
- `com.hitslop.templates.habit-tracker` — Habit Tracker
- `com.hitslop.templates.home-inventory` — Home Inventory
- `com.hitslop.templates.cleaning-schedule` — Cleaning Schedule
- `com.hitslop.templates.trip-planner` — Trip Planner
- `com.hitslop.templates.packing-list` — Packing List
- `com.hitslop.templates.party-planner` — Party Planner
- `com.hitslop.templates.wedding-planner` — Wedding Planner
- `com.hitslop.templates.contact-crm` — Contact CRM
- `com.hitslop.templates.watch-list` — Watch List
- `com.hitslop.templates.media-review` — Media Review
- `com.hitslop.templates.mood-logger` — Mood Logger
- `com.hitslop.templates.world-clock` — World Clock
- `com.hitslop.templates.unit-converter` — Unit Converter
- `com.hitslop.templates.countdown` — Countdown

### Creative & Design
- `com.hitslop.templates.color-palette` — Color Palette
- `com.hitslop.templates.appstore-screenshot` — App Store Screenshot
- `com.hitslop.templates.slide` — Slide
- `com.hitslop.templates.social-post-preview` — Social Post Preview
- `com.hitslop.templates.ai-gallery` — AI Gallery
- `com.hitslop.templates.content-review-board` — Content Review Board
- `com.hitslop.templates.prompt-lab` — Prompt Lab

### Legal
- `com.hitslop.templates.nda` — NDA
- `com.hitslop.templates.service-agreement` — Service Agreement
- `com.hitslop.templates.contractor-agreement` — Contractor Agreement
- `com.hitslop.templates.lease-agreement` — Lease Agreement
- `com.hitslop.templates.estate-will` — Estate Will

### Other
- `com.hitslop.templates.resume` — Resume
- `com.hitslop.templates.spreadsheet` — Spreadsheet

## Document Management

### Create a new document
```bash
slop create <templateID> [output-path]
```
Options:
- `--data '{"key":"value"}'` - Set initial data as JSON
- `--theme <theme-name>` - Apply theme (e.g., "studio-noir", "paper-ledger")
- `--open` - Open in app after creation

Examples:
```bash
# Create a budget tracker
slop create com.hitslop.templates.budget-tracker ~/Documents/Budget.slop

# Create with initial data and theme
slop create com.hitslop.templates.budget-tracker Budget.slop \
  --data '{"title":"Q1 2024","budget":5000}' \
  --theme studio-noir \
  --open
```

### Read document data
```bash
slop read <path>
```
Options:
- `--raw` - Show raw JSON (no schema resolution)
- `--field <key>` - Show single field value

Examples:
```bash
slop read Budget.slop
slop read Budget.slop --field title
slop read Budget.slop --raw
```

### Write/update document
```bash
slop write <path> [options]
```
Options:
- `--field <key>=<value>` - Set field (repeatable)
- `--data <json>` - Merge JSON data
- `--theme <name>` - Change theme

Examples:
```bash
# Update fields
slop write Budget.slop --field title="Q2 2024" --field budget=6000

# Merge JSON
slop write Budget.slop --data '{"spent":3200,"remaining":1800}'

# Change theme
slop write Budget.slop --theme midnight-ink
```

### Validate document
```bash
slop validate <path>
```
Checks data against template schema. Returns "Valid" or error details.

### Document info
```bash
slop info <path>
```
Shows: template ID, name, version, field count, current theme.

### Open in app
```bash
slop open <path>
```
Launches hitSlop.app and opens the document.

### Export document
```bash
slop export <path> [options]
```
Options:
- `--format <pdf|png>` - Export format (default: png)
- `--output <path>` - Output file path
- `--theme <name>` - Override theme for export
- `--scale <number>` - PNG scale factor (default: 2)

Examples:
```bash
slop export Budget.slop --format pdf --output report.pdf
slop export Budget.slop --format png --scale 3 --theme paper-ledger
```

## Template Management

### List templates
```bash
slop templates [--json]
```
Shows: id, name, version, type (built-in/scripted/external).

Examples:
```bash
slop templates
slop templates --json | jq '.[] | select(.type == "scripted")'
```

### Show template schema
```bash
slop schema <templateID> [options]
```
Options:
- `--json-schema` - Output as JSON Schema format
- `--fields` - Show fields-only table

Examples:
```bash
slop schema com.hitslop.templates.budget-tracker
slop schema com.hitslop.templates.budget-tracker --json-schema
slop schema com.hitslop.templates.budget-tracker --fields
```

## Theme Management

### List themes
```bash
slop themes list [--json]
```
Shows: id, name, group, source (bundled/user).

22 built-in themes:
- **Dark**: studio-noir, signal-grid, terminal-core, midnight-ink
- **Light**: paper-ledger
- **Minimal**: minimal-mono, slate-gray
- **Professional**: corporate-blue
- **Cool**: ocean-glass, arctic-frost, lavender-haze
- **Warm**: sunset-poster, ember-glow, rose-garden
- **Nature**: forest-club
- **Vibrant**: neon-nights, frutiger-aero, xbox-dashboard
- **Playful**: playroom, candy-shop
- **Retro**: retro-terminal
- **Accessibility**: high-contrast

### Create theme
```bash
slop themes create <id> --background <hex> --foreground <hex> [options]
```
Options:
- `--background <hex>` - Background color (required)
- `--foreground <hex>` - Foreground/text color (required)
- `--secondary <hex>` - Secondary color (required)
- `--accent <hex>` - Accent color (required)
- `--surface <hex>` - Surface/card color (required)
- `--divider <hex>` - Divider line color (required)
- `--display-name <name>` - Human-readable name
- `--group <group>` - Theme group (Dark/Light/etc)
- `--json` - Output created theme as JSON

Creates theme at `~/.hitslop/themes/<id>.theme`.

Examples:
```bash
slop themes create my-theme \
  --background "#0a0e27" \
  --foreground "#e8e6e3" \
  --accent "#5fc0e8" \
  --secondary "#8e8e93" \
  --surface "#1c1c1e" \
  --divider "#38383a" \
  --display-name "Midnight Ocean" \
  --group Dark
```

### Derive theme from accent color
```bash
slop themes derive <id> --accent <hex> [options]
```
Options:
- `--accent <hex>` - Accent color (required)
- `--light` - Generate light theme (default: dark)
- `--display-name <name>` - Human-readable name
- `--group <group>` - Theme group
- `--json` - Output theme as JSON

Auto-generates harmonious colors using LCH color space.

Examples:
```bash
# Derive dark theme from blue accent
slop themes derive ocean-dark --accent "#5fc0e8"

# Derive light theme from orange accent
slop themes derive sunset-light --accent "#ff8c42" --light --group Warm
```

### Validate theme file
```bash
slop themes validate <path> [--json]
```
Checks theme JSON structure and color values.

### Delete theme
```bash
slop themes delete <id>
```
Removes user theme from `~/.hitslop/themes/`.

## App Control

### Check app status
```bash
slop status
```
Shows if hitSlop is running (PID, version) or not.

### Version info
```bash
slop version
```
Prints app version (queries running app if available).

### Show paths
```bash
slop identify
```
Displays:
- Socket path: `~/.hitslop/slop.sock`
- PID file: `~/.hitslop/slop.pid`
- Templates: `~/.hitslop/templates/`
- Themes: `~/.hitslop/themes/`
- CLI: `~/.hitslop/bin/slop`

### Show template picker
```bash
slop picker
```
Opens the template picker window in the app.

## Recent Documents

### List recent documents
```bash
slop recents [--json] [--clear]
```
- Default: numbered list of recently opened .slop files
- `--json` - Output as JSON array
- `--clear` - Clear recents list

## Common Workflows

### Create a document from scratch
```bash
# 1. Find a template
slop templates | grep budget

# 2. See what fields it has
slop schema com.hitslop.templates.budget-tracker --fields

# 3. Create document with initial data
slop create com.hitslop.templates.budget-tracker Budget.slop \
  --data '{"title":"Q1 2024","budget":5000,"spent":0}' \
  --theme studio-noir

# 4. Open it
slop open Budget.slop
```

### Update and export
```bash
# Update fields
slop write Budget.slop --field spent=3200

# Validate data
slop validate Budget.slop

# Export PDF
slop export Budget.slop --format pdf --output Q1-Report.pdf
```

### Create a custom theme
```bash
# Derive from accent color
slop themes derive my-brand --accent "#7c3aed" --group Professional

# Apply to document
slop write Budget.slop --theme my-brand

# Verify it worked
slop info Budget.slop
```

### Batch operations
```bash
# Export all slops in a directory to PDF
for doc in *.slop; do
  slop export "$doc" --format pdf --output "${doc%.slop}.pdf"
done
```

## Configuration Paths

- **Templates**: `~/.hitslop/templates/<id>/<version>/`
- **Themes**: `~/.hitslop/themes/<id>.theme`
- **CLI**: `~/.hitslop/bin/slop` (add to PATH)
- **Socket**: `~/.hitslop/slop.sock` (IPC communication)

## Error Handling

Most commands require the app to be running. If you get "app not running" errors:
```bash
# Check status
slop status

# If not running, some commands (themes create/delete, identify) work offline
# Others need the app launched
```

## Notes

- Template IDs use reverse-DNS format: `com.hitslop.templates.<name>`
- Themes can be overridden per-document (doesn't affect template default)
- Window shapes can be: roundedRect, circle, capsule, skin (PNG bitmap)
- All CLI commands support `--help` for detailed usage
- IPC uses JSON-RPC 2.0 over Unix socket for app communication
