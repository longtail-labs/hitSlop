#!/usr/bin/env python3
"""
Generate HTML gallery from PNG exports.

Usage:
    generate-gallery.py <output-dir>

Creates index.html with grid of all template PNGs.
"""

import sys
import os
from pathlib import Path
from datetime import datetime

def generate_gallery(output_dir: str) -> str:
    """Create index.html with grid of all template PNGs"""
    png_dir = Path(output_dir) / "png"
    pdf_dir = Path(output_dir) / "pdf"
    slop_dir = Path(output_dir) / "slop"

    if not png_dir.exists():
        return f"<html><body><h1>Error: {png_dir} not found</h1></body></html>"

    pngs = sorted(png_dir.glob("*.png"))

    # Group by template (handle variants)
    templates = {}
    for png in pngs:
        # Extract base template name (before -v suffix if present)
        stem = png.stem
        if "-v" in stem:
            base_name = stem.rsplit("-v", 1)[0]
            variant = stem.rsplit("-v", 1)[1]
        else:
            base_name = stem
            variant = None

        if base_name not in templates:
            templates[base_name] = []
        templates[base_name].append({
            'png': png.name,
            'stem': stem,
            'variant': variant
        })

    total_templates = len(templates)
    total_variants = sum(len(variants) for variants in templates.values())

    html = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Slop Template Gallery - {total_templates} Templates</title>
    <style>
        * {{
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }}

        body {{
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
            background: #f5f5f7;
            padding: 20px;
            line-height: 1.5;
        }}

        .header {{
            max-width: 1400px;
            margin: 0 auto 40px;
            text-align: center;
        }}

        h1 {{
            font-size: 2.5rem;
            font-weight: 700;
            color: #1d1d1f;
            margin-bottom: 12px;
        }}

        .subtitle {{
            font-size: 1.1rem;
            color: #6e6e73;
            margin-bottom: 8px;
        }}

        .timestamp {{
            font-size: 0.9rem;
            color: #86868b;
        }}

        .stats {{
            display: flex;
            gap: 24px;
            justify-content: center;
            margin-top: 20px;
        }}

        .stat {{
            background: white;
            padding: 12px 24px;
            border-radius: 8px;
            box-shadow: 0 1px 3px rgba(0,0,0,0.08);
        }}

        .stat-value {{
            font-size: 1.5rem;
            font-weight: 600;
            color: #1d1d1f;
        }}

        .stat-label {{
            font-size: 0.85rem;
            color: #6e6e73;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }}

        .grid {{
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(320px, 1fr));
            gap: 24px;
            max-width: 1400px;
            margin: 0 auto;
        }}

        .card {{
            background: white;
            border-radius: 12px;
            box-shadow: 0 2px 8px rgba(0,0,0,0.08);
            overflow: hidden;
            transition: transform 0.2s, box-shadow 0.2s;
        }}

        .card:hover {{
            transform: translateY(-4px);
            box-shadow: 0 4px 16px rgba(0,0,0,0.12);
        }}

        .card-image {{
            position: relative;
            background: #f5f5f7;
            padding: 16px;
            border-bottom: 1px solid #e5e5e7;
        }}

        .card-image img {{
            width: 100%;
            height: auto;
            border-radius: 6px;
            display: block;
        }}

        .variant-badge {{
            position: absolute;
            top: 8px;
            right: 8px;
            background: rgba(0,0,0,0.7);
            color: white;
            padding: 4px 10px;
            border-radius: 12px;
            font-size: 0.75rem;
            font-weight: 500;
        }}

        .card-content {{
            padding: 16px;
        }}

        .card-title {{
            font-size: 0.95rem;
            font-weight: 600;
            color: #1d1d1f;
            margin-bottom: 8px;
            word-break: break-word;
        }}

        .card-meta {{
            display: flex;
            gap: 12px;
            font-size: 0.85rem;
        }}

        .card-meta a {{
            color: #007aff;
            text-decoration: none;
            transition: color 0.2s;
        }}

        .card-meta a:hover {{
            color: #0051d5;
            text-decoration: underline;
        }}

        .variants {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(100px, 1fr));
            gap: 8px;
            margin-top: 12px;
        }}

        .variant-link {{
            background: #f5f5f7;
            padding: 6px 12px;
            border-radius: 6px;
            text-align: center;
            font-size: 0.8rem;
            color: #1d1d1f;
            text-decoration: none;
            transition: background 0.2s;
        }}

        .variant-link:hover {{
            background: #e5e5e7;
        }}

        @media (max-width: 768px) {{
            .grid {{
                grid-template-columns: 1fr;
            }}

            h1 {{
                font-size: 2rem;
            }}

            .stats {{
                flex-direction: column;
                gap: 12px;
            }}
        }}
    </style>
</head>
<body>
    <div class="header">
        <h1>🎨 Slop Template Gallery</h1>
        <div class="subtitle">Visual test suite for all templates</div>
        <div class="timestamp">Generated {datetime.now().strftime("%B %d, %Y at %I:%M %p")}</div>
        <div class="stats">
            <div class="stat">
                <div class="stat-value">{total_templates}</div>
                <div class="stat-label">Templates</div>
            </div>
            <div class="stat">
                <div class="stat-value">{total_variants}</div>
                <div class="stat-label">Total Renders</div>
            </div>
        </div>
    </div>

    <div class="grid">
"""

    # Generate cards for each template
    for base_name in sorted(templates.keys()):
        variants = templates[base_name]

        # Use first variant for preview
        preview = variants[0]

        # Check if files exist
        pdf_exists = (pdf_dir / f"{preview['stem']}.pdf").exists()
        slop_exists = (slop_dir / f"{preview['stem']}.slop").exists()

        # Template display name (remove package prefix)
        display_name = base_name.replace("com.hitslop.templates.", "")

        html += f"""
        <div class="card">
            <div class="card-image">
                <a href="png/{preview['png']}" target="_blank">
                    <img src="png/{preview['png']}" alt="{display_name}" loading="lazy">
                </a>
"""

        if preview['variant']:
            html += f"""
                <span class="variant-badge">v{preview['variant']}</span>
"""

        html += f"""
            </div>
            <div class="card-content">
                <div class="card-title">{display_name}</div>
                <div class="card-meta">
"""

        if pdf_exists:
            html += f"""
                    <a href="pdf/{preview['stem']}.pdf" target="_blank">PDF</a>
"""

        if slop_exists:
            html += f"""
                    <a href="slop/{preview['stem']}.slop" target="_blank">SLOP</a>
"""

        html += """
                </div>
"""

        # Show variant links if multiple
        if len(variants) > 1:
            html += """
                <div class="variants">
"""
            for v in variants:
                variant_label = f"v{v['variant']}" if v['variant'] else "default"
                html += f"""
                    <a href="png/{v['png']}" class="variant-link" target="_blank">{variant_label}</a>
"""
            html += """
                </div>
"""

        html += """
            </div>
        </div>
"""

    html += """
    </div>
</body>
</html>
"""

    return html


def main():
    if len(sys.argv) < 2:
        print("Usage: generate-gallery.py <output-dir>", file=sys.stderr)
        sys.exit(1)

    output_dir = sys.argv[1]
    gallery_html = generate_gallery(output_dir)
    print(gallery_html)


if __name__ == "__main__":
    main()
