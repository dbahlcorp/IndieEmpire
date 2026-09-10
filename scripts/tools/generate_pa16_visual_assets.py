"""Author the PA.16 SVG families and their deterministic runtime manifest.

The output deliberately uses a compact shared visual grammar. Each catalog item
gets an authored file and stable mapping, while related concepts reuse motifs in
the same way an icon font would. Run from the repository root.
"""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
INK, DEEP, TEAL = "#263c40", "#254a50", "#315f65"
SKY, CREAM, PAPER = "#4f91a2", "#fff7df", "#f8e8c8"
ORANGE, GOLD, GREEN, RED = "#e98d48", "#f0b34f", "#4f956f", "#b94e48"


def data_ids(name: str) -> list[str]:
    payload = json.loads((ROOT / "data" / f"{name}.json").read_text(encoding="utf-8"))
    return [str(row.get("id", row.get("key", ""))) for row in payload]


def save(relative: str, text: str) -> str:
    path = ROOT / relative
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text.strip() + "\n", encoding="utf-8")
    return "res://" + relative.replace("\\", "/")


def existing(relative: str) -> str:
    """Return a manifest path for art maintained outside this generator.

    PA.16B selectively replaces weak generated assets with reviewed, hand-authored
    SVGs. Keeping those mappings explicit prevents a coverage regeneration from
    destroying approved production art.
    """
    path = ROOT / relative
    if not path.exists():
        raise FileNotFoundError(f"Expected hand-authored asset: {relative}")
    return "res://" + relative.replace("\\", "/")


def svg64(body: str, title: str, bg: str = PAPER) -> str:
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" role="img" aria-label="{title}">
  <rect x="3" y="3" width="58" height="58" rx="15" fill="{bg}" stroke="{TEAL}" stroke-width="4"/>
  <g fill="none" stroke="{INK}" stroke-width="4" stroke-linecap="round" stroke-linejoin="round">{body}</g>
</svg>'''


MOTIFS = {
    "space": f'<circle cx="32" cy="32" r="10" fill="{SKY}"/><path d="M12 38c8 9 31 9 40-4"/><path d="M46 13l2 6 6 2-6 2-2 6-2-6-6-2 6-2z" fill="{GOLD}"/>',
    "fantasy": f'<path d="M19 48l16-32 10 31-13-7z" fill="{ORANGE}"/><path d="M17 49h31"/><circle cx="36" cy="27" r="3" fill="{CREAM}"/>',
    "combat": f'<path d="M16 48l30-30 4 4-30 30z" fill="{SKY}"/><path d="M14 40l10 10M38 16l10 10"/><path d="M19 15l30 30"/>',
    "mystery": f'<circle cx="27" cy="28" r="12" fill="{SKY}"/><path d="M36 37l13 13"/><path d="M22 28h10M27 23v10"/>',
    "nature": f'<path d="M14 43c20 3 31-10 36-27-20-1-35 9-36 27z" fill="{GREEN}"/><path d="M17 47c8-10 17-17 29-25"/>',
    "city": f'<path d="M14 49V27h12v22M26 49V16h15v33M41 49V31h9v18" fill="{SKY}"/><path d="M10 49h44M31 22v4m0 7v4"/>',
    "machine": f'<circle cx="32" cy="32" r="10" fill="{SKY}"/><path d="M32 12v8m0 24v8M12 32h8m24 0h8M18 18l6 6m16 16 6 6m0-28-6 6M24 40l-6 6"/><circle cx="32" cy="32" r="3" fill="{CREAM}"/>',
    "social": f'<circle cx="24" cy="25" r="7" fill="{ORANGE}"/><circle cx="42" cy="28" r="6" fill="{SKY}"/><path d="M11 48c2-10 9-14 16-14s14 4 16 14M36 39c8-2 14 2 17 9"/>',
    "music": f'<path d="M26 19v27M26 22l22-5v24"/><circle cx="19" cy="47" r="7" fill="{ORANGE}"/><circle cx="41" cy="42" r="7" fill="{SKY}"/>',
    "vehicle": f'<path d="M13 40l6-13h27l6 13v8H12z" fill="{ORANGE}"/><circle cx="21" cy="48" r="5" fill="{CREAM}"/><circle cx="44" cy="48" r="5" fill="{CREAM}"/><path d="M19 40h28"/>',
    "history": f'<path d="M17 17h30v35H17z" fill="{GOLD}"/><path d="M24 17v35M30 25h11m-11 8h11m-11 8h8"/>',
    "water": f'<path d="M12 26c7-7 13 7 20 0s13 7 20 0M12 38c7-7 13 7 20 0s13 7 20 0M17 49c6-5 11 5 17 0"/><path d="M32 12c-5 7-9 11-9 16" fill="{SKY}"/>',
    "sport": f'<circle cx="32" cy="32" r="18" fill="{CREAM}"/><path d="M32 14v36M14 32h36M19 20c8 8 18 16 26 24M45 20c-8 8-18 16-26 24"/>',
    "food": f'<path d="M15 35h34c-1 11-8 16-17 16s-16-5-17-16z" fill="{ORANGE}"/><path d="M12 35h40M25 28c-4-6 4-7 0-13m12 13c-4-6 4-7 0-13"/>',
    "magic": f'<path d="M18 49l25-31 4 4-25 31z" fill="{SKY}"/><path d="M17 15l2 6 6 2-6 2-2 6-2-6-6-2 6-2zM45 39l1.5 4.5L51 45l-4.5 1.5L45 51l-1.5-4.5L39 45l4.5-1.5z" fill="{GOLD}"/>',
    "code": f'<path d="M25 20L13 32l12 12M39 20l12 12-12 12M36 14l-8 36"/><circle cx="32" cy="32" r="3" fill="{SKY}"/>',
    "audio": f'<path d="M14 28h10l12-10v28L24 36H14z" fill="{SKY}"/><path d="M43 25c5 4 5 10 0 14M48 19c10 8 10 18 0 26"/>',
    "network": f'<circle cx="16" cy="39" r="6" fill="{SKY}"/><circle cx="48" cy="39" r="6" fill="{ORANGE}"/><circle cx="32" cy="17" r="6" fill="{GREEN}"/><path d="M20 34l8-12m8 0 8 12M22 39h20"/>',
    "world": f'<circle cx="32" cy="32" r="19" fill="{SKY}"/><path d="M13 32h38M32 13c-10 10-10 28 0 38m0-38c10 10 10 28 0 38"/>',
    "person": f'<circle cx="32" cy="22" r="9" fill="{ORANGE}"/><path d="M15 51c2-13 9-19 17-19s15 6 17 19" fill="{SKY}"/>',
}


def motif_for(identifier: str) -> str:
    checks = [
        (("space", "alien", "virtual", "neural"), "space"),
        (("fantasy", "dragon", "fairy", "myth", "viking", "samurai", "magic", "occult", "vampire", "ghost"), "fantasy"),
        (("military", "combat", "shooter", "battle", "weapon", "stealth"), "combat"),
        (("detect", "crime", "heist", "mafia", "horror", "zombie", "mystery"), "mystery"),
        (("farm", "wildlife", "jungle", "arctic", "dinosaur", "weather"), "nature"),
        (("city", "business", "building", "base_build"), "city"),
        (("robot", "machine", "physics", "engine", "pipeline", "renderer", "shader", "lighting", "component", "system"), "machine"),
        (("social", "companion", "cooperative", "multiplayer", "matchmaking"), "social"),
        (("music", "audio", "voice"), "music"),
        (("racing", "automotive", "aviation", "rail", "vehicle"), "vehicle"),
        (("history", "archaeology", "egypt", "treasure", "western", "pirate"), "history"),
        (("sea", "sail", "fluid"), "water"),
        (("sport", "fighting"), "sport"),
        (("cook",), "food"),
        (("procedural", "particle", "mocap", "animation", "inverse"), "magic"),
        (("code", "script", "ai", "data", "telemetry", "localization", "mod", "hot_reload"), "code"),
        (("online", "network", "netcode", "server", "crossplay", "anti_cheat", "lan"), "network"),
        (("world", "open_world", "sandbox", "level", "tile", "stream"), "world"),
        (("character", "dialogue", "accessibility", "facial"), "person"),
    ]
    for needles, motif in checks:
        if any(needle in identifier for needle in needles):
            return motif
    return list(MOTIFS)[sum(map(ord, identifier)) % len(MOTIFS)]


def author_family(family: str, identifiers: list[str], directory: str, existing: dict[str, str] | None = None) -> dict[str, str]:
    result = dict(existing or {})
    for identifier in identifiers:
        if identifier in result:
            continue
        motif = motif_for(identifier)
        result[identifier] = save(f"{directory}/{identifier}.svg", svg64(MOTIFS[motif], identifier.replace("_", " ")))
    return result


def platform_svg(identifier: str, index: int) -> str:
    kind = index % 6
    if kind == 0:
        body = f'<rect x="11" y="15" width="30" height="27" rx="3" fill="{SKY}"/><path d="M17 21h18v14H17zM16 51h31M26 42v9"/><rect x="44" y="22" width="9" height="25" rx="2" fill="{ORANGE}"/>'
    elif kind == 1:
        body = f'<rect x="9" y="22" width="46" height="25" rx="7" fill="{ORANGE}"/><circle cx="21" cy="35" r="7" fill="{CREAM}"/><path d="M17 35h8m-4-4v8M43 31h1m5 7h1"/>'
    elif kind == 2:
        body = f'<rect x="16" y="10" width="32" height="44" rx="8" fill="{SKY}"/><rect x="21" y="16" width="22" height="25" rx="2" fill="{CREAM}"/><path d="M27 48h10M13 28h3m32 0h3"/>'
    elif kind == 3:
        body = f'<path d="M11 22h42l-5 29H16z" fill="{SKY}"/><path d="M19 28h26v13H19zM25 17h14M22 47h20"/><circle cx="32" cy="34" r="4" fill="{ORANGE}"/>'
    elif kind == 4:
        body = f'<path d="M12 42c3-15 11-22 20-22s17 7 20 22l-7 7-9-8h-8l-9 8z" fill="{ORANGE}"/><path d="M20 33h9m-4-4v9M41 31h1m5 5h1"/>'
    else:
        body = f'<path d="M16 12h32l7 20-7 20H16L9 32z" fill="{SKY}"/><circle cx="32" cy="32" r="10" fill="{CREAM}"/><path d="M32 22v20M22 32h20"/>'
    return svg64(body, identifier.replace("_", " "), CREAM)


def award_svg(identifier: str, index: int) -> str:
    marks = {
        "goty": '<path d="M32 18l4 8 9 1-7 6 2 9-8-4-8 4 2-9-7-6 9-1z"/>',
        "best_rpg": '<path d="M20 41l23-23 4 4-23 23zM18 35l11 11M38 16l11 11"/>',
        "best_action": '<path d="M19 20l26 24M45 20L19 44"/><circle cx="32" cy="32" r="6"/>',
        "best_strategy": '<path d="M20 42h24M23 38h18l-2-15-7-6-7 6zM27 30h10"/>',
        "best_simulation": '<circle cx="32" cy="31" r="12"/><path d="M32 16v7m0 16v7M17 31h7m16 0h7"/>',
        "best_technology": '<path d="M20 40V29m12 11V22m12 18V16M16 45h32"/>',
        "best_visuals": '<path d="M16 32c8-11 24-11 32 0-8 11-24 11-32 0z"/><circle cx="32" cy="32" r="6"/>',
        "best_narrative": '<path d="M24 40c13-5 18-13 18-22-11 2-18 9-18 22zm0 0-5 8M29 34l10-10"/>',
        "most_innovative": '<path d="M20 42l24-24M19 18l3 7 7 3-7 3-3 7-3-7-7-3 7-3z"/>',
        "best_indie": '<path d="M21 39V23l11-6 11 6v16l-11 7zM26 31h12M32 25v12"/>',
    }
    mark = marks.get(identifier, '<circle cx="32" cy="31" r="12"/>')
    body = f'<path d="M19 12h26v12c0 10-5 17-13 20-8-3-13-10-13-20z" fill="{GOLD}"/><path d="M19 18h-8c0 10 5 15 12 15m22-15h8c0 10-5 15-12 15M27 44v7m-9 0h28"/>{mark}'
    return svg64(body, identifier.replace("_", " "), CREAM)


def empty_svg(identifier: str, index: int) -> str:
    motif = MOTIFS[["history", "city", "machine", "social", "world", "magic", "space", "nature"][index % 8]]
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 192 128" role="img" aria-label="{identifier.replace('_', ' ')}">
  <path d="M24 101c24-14 121-18 146 0" fill="none" stroke="{SKY}" stroke-width="5" stroke-linecap="round" opacity=".35"/>
  <rect x="50" y="21" width="92" height="84" rx="18" fill="{PAPER}" stroke="{TEAL}" stroke-width="4"/>
  <g transform="translate(64 31)" fill="none" stroke="{INK}" stroke-width="4" stroke-linecap="round" stroke-linejoin="round">{motif}</g>
  <circle cx="153" cy="31" r="8" fill="{ORANGE}"/><path d="M149 31h8M153 27v8" stroke="{CREAM}" stroke-width="3" stroke-linecap="round"/>
</svg>'''


def era_svg(identifier: str, index: int) -> str:
    colors = ["#b88743", "#d56f45", "#7866a6", "#4f91a2", "#e98d68"]
    props = [
        '<rect x="565" y="340" width="84" height="58" rx="5"/><path d="M578 353h58v32h-58zM607 398v20M585 418h45"/><rect x="665" y="369" width="38" height="24" rx="3"/>',
        '<rect x="554" y="344" width="76" height="55" rx="5"/><path d="M565 354h54v31h-54zM592 399v19"/><path d="M649 380h63v34h-63zM660 389h16m-8-8v16m25-8h2"/>',
        '<rect x="548" y="335" width="73" height="54" rx="5"/><rect x="635" y="335" width="73" height="54" rx="5"/><path d="M557 344h55v34h-55M644 344h55v34h-55M622 374h13"/><circle cx="679" cy="407" r="16"/>',
        '<rect x="553" y="337" width="102" height="59" rx="5"/><path d="M564 348h80v37h-80M604 396v21M579 417h50"/><path d="M670 363h32v34h-32zM676 372h20m-20 8h20"/>',
        '<path d="M554 389h96l-10-56h-76z"/><path d="M575 349h54v26h-54M601 389v24M577 413h49"/><rect x="669" y="340" width="30" height="58" rx="7"/><circle cx="684" cy="389" r="2"/>',
    ]
    color = colors[index]
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 768 512" role="img" aria-label="{identifier.replace('_', ' ')} office technology">
  <path d="M520 451c57-24 157-24 212 0" fill="{color}" opacity=".12"/>
  <g fill="{CREAM}" stroke="{INK}" stroke-width="5" stroke-linecap="round" stroke-linejoin="round">{props[index]}</g>
  <circle cx="719" cy="420" r="10" fill="{color}"/><circle cx="690" cy="424" r="6" fill="{color}" opacity=".7"/>
</svg>'''


def main() -> None:
    legacy_genres = ["action", "adventure", "rpg", "strategy", "simulation", "puzzle", "racing", "shooter"]
    pa16b_genres = ["battle_royale", "fighting", "horror", "immersive_vr", "mmo", "neural_sim", "sandbox"]
    genres_existing = {
        **{name: existing(f"assets/ui/genres/{name}.svg") for name in legacy_genres},
        **{name: existing(f"assets/icons/genres/{name}.svg") for name in pa16b_genres},
    }
    legacy_platforms = ["microstar_64", "ibm_compatible", "famiclone", "pocket_play", "mega16", "playbox32"]
    platforms_existing = {
        **{name: existing(f"assets/ui/platforms/{name}.svg") for name in legacy_platforms},
        **{
            name: existing(f"assets/platforms/hardware/{name}.svg")
            for name in data_ids("platforms")
            if name not in legacy_platforms
        },
    }
    families: dict[str, dict[str, str]] = {}
    families["genres"] = author_family("genres", data_ids("genres"), "assets/icons/genres", genres_existing)
    families["themes"] = author_family("themes", data_ids("themes"), "assets/icons/themes")
    families["technologies"] = author_family("technologies", data_ids("technologies"), "assets/icons/technologies")
    families["features"] = author_family("features", data_ids("game_features"), "assets/icons/features")

    families["platforms"] = dict(platforms_existing)
    for index, identifier in enumerate(data_ids("platforms")):
        if identifier not in families["platforms"]:
            families["platforms"][identifier] = save(f"assets/platforms/hardware/{identifier}.svg", platform_svg(identifier, index))

    ui_motifs = {
        "research": "magic", "engines": "machine", "finance": "history", "statistics": "city",
        "awards": "sport", "milestones": "history", "franchises": "world", "records": "history",
        "release": "space", "development": "code", "settings": "machine", "calendar": "history",
        "contracts": "history", "training": "person", "publishers": "social", "marketing": "network",
        "money": "history", "revenue": "city", "expenses": "combat", "profit": "nature",
        "fans": "social", "reputation": "sport", "technology": "machine", "employees": "social",
        "payroll": "history", "stress": "combat", "morale": "nature", "energy": "magic",
        "bugs": "mystery", "sales": "city", "reviews": "history", "market": "vehicle",
        "platform": "machine", "office": "city", "risk": "combat", "time": "history",
        "deadline": "history",
    }
    families["ui"] = {identifier: save(f"assets/icons/ui/{identifier}.svg", svg64(MOTIFS[motif], identifier)) for identifier, motif in ui_motifs.items()}
    statuses = ["locked", "active", "queued", "complete", "warning", "failed", "paused", "trending", "low_runway", "financial_trouble", "critical", "insolvent"]
    families["statuses"] = {
        identifier: existing(f"assets/icons/statuses/{identifier}.svg")
        for identifier in statuses
    }

    families["awards"] = {
        identifier: existing(f"assets/awards/trophies/{identifier}.svg")
        for identifier in data_ids("awards")
    }

    empties = ["games", "staff", "contracts", "finances", "records", "research", "franchises", "awards", "engines", "sales_history", "news"]
    families["empty_states"] = {
        identifier: existing(f"assets/backgrounds/empty_states/{identifier}.svg")
        for identifier in empties
    }
    eras = ["era_1980s", "era_1990s", "era_2000s", "era_2010s", "era_2020s"]
    families["eras"] = {identifier: save(f"assets/offices/era_overlays/{identifier}.svg", era_svg(identifier, index)) for index, identifier in enumerate(eras)}

    milestones = [
        "first_game", "first_100k_sales", "first_employee", "first_office",
        "first_1m_sales", "first_8_review", "first_9_review", "first_award",
        "first_goty", "first_franchise", "first_custom_engine", "ten_employees",
    ]
    families["milestones"] = {
        identifier: existing(f"assets/icons/milestones/{identifier}.svg")
        for identifier in milestones
    }
    families["award_presentation"] = {
        "nominee": save("assets/awards/badges/nominee.svg", svg64(MOTIFS["magic"], "award nominee")),
        "winner": save("assets/awards/badges/winner.svg", award_svg("goty", 0)),
        "ceremony": save("assets/awards/ceremony/stage.svg", empty_svg("awards ceremony stage", 6)),
    }

    fallbacks = {}
    for family in ["genres", "themes", "technologies", "features", "platforms", "ui", "statuses", "awards", "milestones", "award_presentation"]:
        fallback = save(f"assets/icons/fallbacks/{family}.svg", svg64(MOTIFS["magic"], f"unknown {family}"))
        fallbacks[family] = fallback
    fallbacks["empty_states"] = families["empty_states"]["records"]
    fallbacks["eras"] = families["eras"]["era_1980s"]

    manifest = {
        "schema_version": 1,
        "generated_by": "scripts/tools/generate_pa16_visual_assets.py",
        "families": families,
        "fallbacks": fallbacks,
    }
    save("data/asset_manifest.json", json.dumps(manifest, indent=2, sort_keys=True))
    print(f"Authored {sum(len(v) for v in families.values())} mappings across {len(families)} families")


if __name__ == "__main__":
    main()
