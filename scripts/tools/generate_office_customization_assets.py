"""Generate Indie Empire's modular office-remodel SVG asset library."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
COMPONENTS = ROOT / "assets" / "offices" / "components"
THEMES = ROOT / "assets" / "offices" / "themes"
ICONS = ROOT / "assets" / "ui" / "remodel"

STYLES = {
    "cozy_startup": {"accent": "#e8a34c", "dark": "#75452f", "light": "#fff1d0", "screen": "#8fc7bd"},
    "eco_studio": {"accent": "#6f9b6a", "dark": "#315f65", "light": "#dcf3d7", "screen": "#a8d8bd"},
    "neon_workshop": {"accent": "#48e8ef", "dark": "#28345d", "light": "#dbefff", "screen": "#ef5bd5"},
    "executive_walnut": {"accent": "#d7ae55", "dark": "#4c2e25", "light": "#f0d2b0", "screen": "#77a6a1"},
}

SHAPES = {
    "walls": '<path d="M26 62 128 18l102 44v116l-102 52-102-52Z" fill="{light}" stroke="{dark}" stroke-width="8"/><path d="M128 20v208M26 62l102 50 102-50" stroke="{dark}" stroke-width="5" opacity=".55"/>',
    "flooring": '<path d="m25 131 103-55 104 55-104 57Z" fill="{accent}" stroke="{dark}" stroke-width="8"/><path d="m49 131 79-40 80 40-80 42Z" fill="none" stroke="{light}" stroke-width="5" stroke-dasharray="12 8"/>',
    "desks": '<path d="m31 106 96-48 99 49-98 51Z" fill="{accent}" stroke="{dark}" stroke-width="8"/><path d="M48 116v76M208 116v76M89 143v70M168 143v70" stroke="{dark}" stroke-width="10"/><path d="m44 104 84 42 84-42" stroke="{light}" stroke-width="5" opacity=".55"/>',
    "seating": '<path d="M70 88q0-35 35-35h46q35 0 35 35v55H70Z" fill="{accent}" stroke="{dark}" stroke-width="8"/><path d="M57 131h142v55H57Z" fill="{accent}" stroke="{dark}" stroke-width="8"/><path d="M76 186v31m104-31v31" stroke="{dark}" stroke-width="10"/><path d="M90 75h76M78 157h100" stroke="{light}" stroke-width="5" opacity=".6"/>',
    "computers": '<path d="M45 42h166v121H45Z" fill="{dark}" stroke="{dark}" stroke-width="8"/><path d="M58 55h140v94H58Z" fill="{screen}"/><path d="M128 163v34M88 211h80" stroke="{dark}" stroke-width="12"/><path d="m83 99 24 18 55-44" stroke="{light}" stroke-width="8" fill="none"/><circle cx="174" cy="113" r="10" fill="{accent}"/>',
    "lighting": '<path d="M128 36v51" stroke="{dark}" stroke-width="10"/><path d="m72 113 25-48h62l25 48Z" fill="{accent}" stroke="{dark}" stroke-width="8"/><path d="M89 115c5 57 20 91 39 108 20-17 34-51 39-108Z" fill="{light}" opacity=".72"/><circle cx="128" cy="116" r="16" fill="{accent}"/>',
    "storage": '<rect x="51" y="30" width="154" height="197" rx="8" fill="{accent}" stroke="{dark}" stroke-width="8"/><path d="M51 94h154M51 160h154M128 30v197" stroke="{dark}" stroke-width="6"/><g fill="{light}"><circle cx="113" cy="63" r="6"/><circle cx="143" cy="63" r="6"/><rect x="74" y="113" width="43" height="25" rx="4"/><rect x="139" y="178" width="43" height="25" rx="4"/></g>',
    "lounge": '<path d="M42 94q0-29 29-29h114q29 0 29 29v80H42Z" fill="{accent}" stroke="{dark}" stroke-width="8"/><path d="M28 145h200v57H28Z" fill="{accent}" stroke="{dark}" stroke-width="8"/><path d="M61 202v24m134-24v24M128 68v132" stroke="{dark}" stroke-width="8"/><path d="M54 164h148" stroke="{light}" stroke-width="5" opacity=".55"/>',
    "plants": '<path d="M128 175c-4-62 4-104 31-137M126 139c-48-11-66-40-55-83 45 12 63 40 55 83ZM139 104c39-6 64-29 71-66-39 4-63 27-71 66Z" stroke="{dark}" stroke-width="8" fill="none"/><path d="M71 56c45 12 63 40 55 83-48-11-66-40-55-83ZM210 38c-39 4-63 27-71 66 39-6 64-29 71-66Z" fill="{accent}" stroke="{dark}" stroke-width="7"/><path d="M81 169h94l-13 62H94Z" fill="{light}" stroke="{dark}" stroke-width="8"/>',
    "decor": '<rect x="34" y="38" width="188" height="180" rx="10" fill="{light}" stroke="{dark}" stroke-width="8"/><path d="m128 66 20 40 44 7-32 31 8 44-40-21-40 21 8-44-32-31 44-7Z" fill="{accent}" stroke="{dark}" stroke-width="7"/>',
}

ICON_SHAPES = {
    "walls": '<path d="M4 20V7l8-4 8 4v13M12 3v17M4 7l8 4 8-4"/>',
    "flooring": '<path d="m3 13 9-5 9 5-9 5Z"/><path d="m6 14 6-3 6 3"/>',
    "desks": '<path d="M3 10h18v5H3ZM6 15v6m12-6v6"/>',
    "seating": '<path d="M6 12V8a3 3 0 0 1 3-3h6a3 3 0 0 1 3 3v4M4 11v7h16v-7M7 18v3m10-3v3"/>',
    "computers": '<rect x="3" y="3" width="18" height="13" rx="2"/><path d="M12 16v4m-5 1h10"/>',
    "lighting": '<path d="M9 3h6l3 7H6ZM12 10v11M8 21h8"/>',
    "storage": '<rect x="5" y="3" width="14" height="18" rx="1"/><path d="M5 9h14M5 15h14m-4-9h1m-1 6h1m-1 6h1"/>',
    "lounge": '<path d="M5 11V7a3 3 0 0 1 3-3h8a3 3 0 0 1 3 3v4M3 10v8h18v-8M6 18v3m12-3v3"/>',
    "plants": '<path d="M12 16V8m0 4c-4 0-7-2-7-6 4 0 7 2 7 6Zm0-2c4 0 7-2 7-6-4 0-7 2-7 6ZM7 16h10l-2 5H9Z"/>',
    "decor": '<rect x="4" y="3" width="16" height="18" rx="2"/><path d="m12 7 1.5 3 3.5.5-2.5 2.5.5 3.5-3-1.5-3 1.5.5-3.5L7 10.5l3.5-.5Z"/>',
}

CONTROL_SHAPES = {
    "place": '<path d="M4 4h6v6H4Zm10 0h6v6h-6ZM4 14h6v6H4Z"/><path d="M14 17h6m-3-3v6"/>',
    "move": '<path d="M12 2v20M2 12h20M12 2l-3 3m3-3 3 3M22 12l-3-3m3 3-3 3M12 22l-3-3m3 3 3-3M2 12l3-3m-3 3 3 3"/>',
    "rotate": '<path d="M20 7V3l-3 3a8 8 0 1 0 2 9"/>',
    "remove": '<path d="M4 7h16M9 7V4h6v3m-8 0 1 14h8l1-14M10 11v6m4-6v6"/>',
}

def svg(body: str, title: str, view="0 0 256 256") -> str:
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{view}" fill="none" role="img" aria-labelledby="title"><title id="title">{title}</title>{body}</svg>\n'

def icon(body: str, title: str) -> str:
    return svg(f'<g stroke="#315f65" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">{body}</g>', title, "0 0 24 24")

def write(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8", newline="\n")

def main() -> None:
    for style_id, colors in STYLES.items():
        for category, body in SHAPES.items():
            write(COMPONENTS / style_id / f"{category}.svg", svg(body.format(**colors), f"{style_id.replace('_', ' ').title()} {category}"))
        glow = f'<defs><radialGradient id="g"><stop stop-color="{colors["accent"]}" stop-opacity=".45"/><stop offset="1" stop-color="{colors["accent"]}" stop-opacity="0"/></radialGradient></defs><ellipse cx="384" cy="170" rx="330" ry="210" fill="url(#g)"/>'
        write(THEMES / f"{style_id}_atmosphere.svg", svg(glow, f"{style_id} atmosphere", "0 0 768 512"))
        front = f'<path d="M70 430h170l-18 54H88Z" fill="{colors["dark"]}" fill-opacity=".7"/><path d="M530 430h170l-18 54H548Z" fill="{colors["accent"]}" fill-opacity=".55"/>'
        write(THEMES / f"{style_id}_foreground.svg", svg(front, f"{style_id} foreground", "0 0 768 512"))
    for name, body in ICON_SHAPES.items():
        write(ICONS / f"category_{name}.svg", icon(body, f"{name} category"))
    for name, body in CONTROL_SHAPES.items():
        write(ICONS / f"control_{name}.svg", icon(body, f"{name} control"))

if __name__ == "__main__":
    main()
