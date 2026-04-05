#!/bin/bash
# Comprehensive template test suite with realistic data generation
#
# Usage: scripts/test-templates.sh [output-dir] [variants]
#
# Arguments:
#   output-dir: Where to save results (default: /tmp/slop-visual-tests)
#   variants:   Number of data variants per template (default: 1)
#               1 = empty/defaults, 2 = minimal realistic, 3 = full realistic
#
# Requires:
#   - hitSlop app running
#   - slop CLI on PATH (~/.hitslop/bin/slop)
#   - uv (Python runner): curl -LsSf https://astral.sh/uv/install.sh | sh
#
set -euo pipefail

SLOP="${SLOP:-$HOME/.hitslop/bin/slop}"
OUT="${1:-/tmp/slop-visual-tests}"
VARIANTS="${2:-1}"
UV="${UV:-uv}"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Create output directories
mkdir -p "$OUT/slop" "$OUT/png" "$OUT/pdf" "$OUT/schemas"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Slop Template Test Suite"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check dependencies
echo -e "${CYAN}🔍 Checking dependencies...${NC}"
command -v "$SLOP" >/dev/null || { echo -e "${RED}✗${NC} slop CLI not found at $SLOP"; exit 1; }
echo -e "${GREEN}✓${NC} slop CLI found"

if ! $SLOP status >/dev/null 2>&1; then
    echo -e "${RED}✗${NC} hitSlop app not running"
    echo "  Please start the hitSlop app first"
    exit 1
fi
echo -e "${GREEN}✓${NC} hitSlop app running"

command -v "$UV" >/dev/null || {
    echo -e "${RED}✗${NC} uv not found (install: curl -LsSf https://astral.sh/uv/install.sh | sh)"
    exit 1
}
echo -e "${GREEN}✓${NC} uv found"

# Get project root (parent of scripts/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Check Python scripts exist
DATA_GEN="$PROJECT_ROOT/scripts/lib/slop-data-generator.py"
GALLERY_GEN="$PROJECT_ROOT/scripts/lib/generate-gallery.py"

if [ ! -f "$DATA_GEN" ]; then
    echo -e "${RED}✗${NC} Data generator not found at $DATA_GEN"
    exit 1
fi
echo -e "${GREEN}✓${NC} Data generator found"

if [ ! -f "$GALLERY_GEN" ]; then
    echo -e "${RED}✗${NC} Gallery generator not found at $GALLERY_GEN"
    exit 1
fi
echo -e "${GREEN}✓${NC} Gallery generator found"

echo ""

# Get all templates
echo -e "${CYAN}📋 Fetching template list...${NC}"
TEMPLATES=$("$SLOP" templates --json)
TEMPLATE_IDS=$(echo "$TEMPLATES" | "$UV" run python3 -c "
import json, sys
data = json.load(sys.stdin)
for t in data.get('templates', []):
    print(t['id'])
")

TOTAL=$(echo "$TEMPLATE_IDS" | wc -l | xargs)
echo -e "${GREEN}✓${NC} Found $TOTAL templates"
echo ""

# Progress tracking
PASS=0
FAIL=0
CURRENT=0
START_TIME=$(date +%s)

# Process each template
for tid in $TEMPLATE_IDS; do
    CURRENT=$((CURRENT + 1))
    echo -e "${BLUE}[$CURRENT/$TOTAL]${NC} 🎨 ${CYAN}$tid${NC}"

    # Get schema
    SCHEMA_FILE="$OUT/schemas/${tid}.json"
    if ! "$SLOP" schema "$tid" --json-schema > "$SCHEMA_FILE" 2>/dev/null; then
        echo -e "  ${RED}✗ FAIL${NC} (schema fetch failed)"
        FAIL=$((FAIL + 1))
        echo ""
        continue
    fi
    echo "  → Schema cached"

    # Generate test data variants
    VARIANT_SUCCESS=0
    for variant in $(seq 1 "$VARIANTS"); do
        SUFFIX=""
        [ "$VARIANTS" -gt 1 ] && SUFFIX="-v${variant}"

        SLOP_FILE="$OUT/slop/${tid}${SUFFIX}.slop"
        PNG_FILE="$OUT/png/${tid}${SUFFIX}.png"
        PDF_FILE="$OUT/pdf/${tid}${SUFFIX}.pdf"

        # Generate test data
        if ! TEST_DATA=$("$UV" run python3 "$DATA_GEN" "$SCHEMA_FILE" "$variant" 2>/dev/null); then
            echo -e "  ${RED}✗ FAIL${NC} (data generation failed for variant $variant)"
            FAIL=$((FAIL + 1))
            continue
        fi
        echo "  → Generated test data (variant $variant)"

        # Create document
        if ! "$SLOP" create "$tid" "$SLOP_FILE" --data "$TEST_DATA" 2>/dev/null; then
            echo -e "  ${RED}✗ FAIL${NC} (create failed for variant $variant)"
            FAIL=$((FAIL + 1))
            continue
        fi

        # Validate
        if ! "$SLOP" validate "$SLOP_FILE" 2>/dev/null; then
            echo -e "  ${YELLOW}⚠ WARN${NC} (validation failed for variant $variant)"
        fi

        # Export PNG
        if ! "$SLOP" export "$SLOP_FILE" --format png --output "$PNG_FILE" --scale 2 2>/dev/null; then
            echo -e "  ${RED}✗ FAIL${NC} (PNG export failed for variant $variant)"
            FAIL=$((FAIL + 1))
            continue
        fi

        # Export PDF
        if ! "$SLOP" export "$SLOP_FILE" --format pdf --output "$PDF_FILE" 2>/dev/null; then
            echo -e "  ${YELLOW}⚠ WARN${NC} (PDF export failed for variant $variant)"
        fi

        VARIANT_SUCCESS=$((VARIANT_SUCCESS + 1))
    done

    if [ "$VARIANT_SUCCESS" -eq "$VARIANTS" ]; then
        echo -e "  ${GREEN}✓ PASS${NC} (all $VARIANTS variants)"
        PASS=$((PASS + 1))
    else
        echo -e "  ${YELLOW}⚠ PARTIAL${NC} ($VARIANT_SUCCESS/$VARIANTS variants succeeded)"
        [ "$VARIANT_SUCCESS" -eq 0 ] && FAIL=$((FAIL + 1))
    fi
    echo ""
done

# Generate HTML gallery
echo -e "${CYAN}📸 Generating visual gallery...${NC}"
if "$UV" run python3 "$GALLERY_GEN" "$OUT" > "$OUT/index.html"; then
    echo -e "${GREEN}✓${NC} Gallery created"
else
    echo -e "${YELLOW}⚠${NC} Gallery generation failed"
fi
echo ""

# Calculate elapsed time
END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Test Results"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "  ${GREEN}✓ Passed:${NC}  $PASS templates"
echo -e "  ${RED}✗ Failed:${NC}  $FAIL templates"
echo -e "  ${BLUE}⏱ Time:${NC}    ${ELAPSED}s"
echo ""
echo -e "  ${CYAN}Output:${NC}    $OUT/"
echo -e "  ${CYAN}Gallery:${NC}   file://$OUT/index.html"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Open gallery in browser
if command -v open >/dev/null 2>&1; then
    open "$OUT/index.html"
fi
