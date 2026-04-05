# Slop Template Testing Scripts

## Overview

This directory contains scripts for comprehensive template testing and visual gallery generation.

## Quick Start

```bash
# 1. Start the hitSlop app first
# 2. Run the test suite
./scripts/test-templates.sh

# 3. View the gallery (opens automatically)
open /tmp/slop-visual-tests/index.html
```

## Scripts

### `test-templates.sh`

Main test runner that generates realistic test data for all templates, exports to PNG/PDF, and creates a visual gallery.

**Usage:**
```bash
./scripts/test-templates.sh [output-dir] [variants]
```

**Arguments:**
- `output-dir`: Where to save results (default: `/tmp/slop-visual-tests`)
- `variants`: Number of data variants per template (default: `1`)
  - `1` = Empty/defaults only
  - `2` = Minimal realistic data
  - `3` = Full realistic data (recommended for visual testing)

**Examples:**
```bash
# Basic test with default data
./scripts/test-templates.sh

# Full test with 3 variants per template
./scripts/test-templates.sh /tmp/slop-visual-tests 3

# Quick test to custom location
./scripts/test-templates.sh ~/Desktop/template-test 1
```

**Requirements:**
- hitSlop app running
- `slop` CLI installed (`~/.hitslop/bin/slop`)
- `uv` Python runner: `curl -LsSf https://astral.sh/uv/install.sh | sh`

### `lib/slop-data-generator.py`

Generates realistic test data from JSON schemas.

**Usage:**
```bash
uv run python3 scripts/lib/slop-data-generator.py <schema-file> <variant>
```

**Field Types Supported:**
- string, richText, number, integer, boolean
- color (generates hex colors)
- date, date-time
- enumeration (picks from options)
- array (generates 2-5 items)
- object/record (recursive generation)
- file (placeholder paths)

**Smart Defaults:**
The generator uses contextual field names to create realistic data:
- `title` → "Q2 Product Planning", "Sprint Review", etc.
- `name` → "Sarah Chen", "Marcus Rodriguez", etc.
- `email` → Valid email addresses
- `amount` → Realistic monetary values
- `category` → Common categories
- `date` → Recent dates (last 30 days)

### `lib/generate-gallery.py`

Creates an HTML gallery from PNG exports.

**Usage:**
```bash
uv run python3 scripts/lib/generate-gallery.py <output-dir> > index.html
```

**Features:**
- Responsive grid layout
- Handles multiple variants
- Links to PDF and SLOP files
- Template statistics
- Mobile-friendly design

## Output Structure

```
/tmp/slop-visual-tests/
├── schemas/                    # Template JSON schemas
│   ├── com.hitslop.templates.budget-tracker.json
│   └── ...
├── slop/                       # Generated .slop files
│   ├── com.hitslop.templates.budget-tracker.slop
│   ├── com.hitslop.templates.todo-list-v1.slop
│   └── ...
├── png/                        # PNG exports (2x scale)
│   ├── com.hitslop.templates.budget-tracker.png
│   └── ...
├── pdf/                        # PDF exports
│   ├── com.hitslop.templates.budget-tracker.pdf
│   └── ...
└── index.html                  # Visual gallery (opens in browser)
```

## Testing Workflow

### After Making Component Changes

When you modify SlopKit components (like fixing text wrapping), run this workflow:

1. **Start hitSlop app** (if not running)

2. **Run full test suite:**
   ```bash
   ./scripts/test-templates.sh /tmp/slop-visual-tests 2
   ```

3. **Review gallery:**
   - Opens automatically in browser
   - Look for layout issues, text overflow, alignment problems
   - Check that data looks realistic
   - Verify all templates render correctly

4. **Check specific templates:**
   ```bash
   # Re-test a specific template with more data
   slop create com.hitslop.templates.budget-tracker \
       /tmp/test.slop \
       --data "$(uv run python3 scripts/lib/slop-data-generator.py \
                 /tmp/slop-visual-tests/schemas/com.hitslop.templates.budget-tracker.json 3)"

   slop export /tmp/test.slop --format png --output /tmp/test.png --scale 2
   open /tmp/test.png
   ```

### Debugging Data Generation

Test data generation for a single template:

```bash
# 1. Get schema
slop schema com.hitslop.templates.invoice --json-schema > /tmp/invoice-schema.json

# 2. Generate variants
uv run python3 scripts/lib/slop-data-generator.py /tmp/invoice-schema.json 1  # minimal
uv run python3 scripts/lib/slop-data-generator.py /tmp/invoice-schema.json 2  # realistic
uv run python3 scripts/lib/slop-data-generator.py /tmp/invoice-schema.json 3  # full

# 3. Validate JSON
uv run python3 scripts/lib/slop-data-generator.py /tmp/invoice-schema.json 3 | python3 -m json.tool
```

## Success Criteria

A successful test run should show:

- ✅ All templates create without errors
- ✅ Schema validation passes
- ✅ PNG exports render at 2x scale
- ✅ PDF exports complete
- ✅ Data looks realistic (not empty defaults)
- ✅ No text truncation or overflow
- ✅ Proper layout and spacing
- ✅ Colors are varied and appropriate

## Troubleshooting

**"slop CLI not found"**
- Make sure hitSlop app is built and `~/.hitslop/bin/slop` symlink exists
- Check: `ls -la ~/.hitslop/bin/slop`

**"hitSlop app not running"**
- Start the hitSlop.app from Xcode or Applications
- Verify: `~/.hitslop/bin/slop status`

**"uv not found"**
- Install uv: `curl -LsSf https://astral.sh/uv/install.sh | sh`
- Or use system Python: edit script to use `python3` instead of `uv run python3`

**"Data generation failed"**
- Check schema file exists and is valid JSON
- Run manually: `uv run python3 scripts/lib/slop-data-generator.py <schema> 2`
- Look for Python errors in output

**"Export failed"**
- Check disk space
- Verify output directory is writable
- Try exporting a single template manually

## Extending the Data Generator

To add smarter data generation for specific templates:

1. **Add field patterns** in `slop-data-generator.py`:
   ```python
   FIELD_PATTERNS = {
       "invoiceNumber": ["INV-2026-001", "INV-2026-002"],
       "clientName": ["Acme Corp", "TechStart Inc"],
       # ... more patterns
   }
   ```

2. **Add custom logic** in `smart_string_value()` or `smart_number_value()`

3. **Test with schema:**
   ```bash
   uv run python3 scripts/lib/slop-data-generator.py <schema> 3
   ```

## Performance

Typical run times (74 templates, M1 Mac):

- **1 variant**: ~2-3 minutes
- **2 variants**: ~4-5 minutes
- **3 variants**: ~6-8 minutes

Most time is spent in PDF/PNG export rendering.
