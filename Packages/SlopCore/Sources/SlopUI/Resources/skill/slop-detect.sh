#!/bin/bash
# hitSlop detection hook for Claude Code
# Injects context when .slop documents are nearby or we're inside a .slop package

detected=false

# Check 1: *.slop items in current directory
shopt -s nullglob
slops=(*.slop)
if [ ${#slops[@]} -gt 0 ]; then
    detected=true
fi

# Check 2: slop.json in current directory (we're inside a .slop package)
if [ "$detected" = false ] && [ -f "slop.json" ]; then
    detected=true
fi

# Check 3: walk up ancestors looking for a directory ending in .slop that contains slop.json
if [ "$detected" = false ]; then
    dir="$(pwd)"
    while [ "$dir" != "/" ]; do
        case "$dir" in
            *.slop)
                if [ -f "$dir/slop.json" ]; then
                    detected=true
                    break
                fi
                ;;
        esac
        dir="$(dirname "$dir")"
    done
fi

if [ "$detected" = true ]; then
    cat << 'EOF'
This directory contains .slop documents.

Run `/hitslop` to load the hitSlop skill for managing these documents via the `slop` CLI.

The slop CLI can create, read, write, validate, and export .slop documents, manage templates and themes.
Quick reference: `slop --help`
EOF
fi

exit 0
