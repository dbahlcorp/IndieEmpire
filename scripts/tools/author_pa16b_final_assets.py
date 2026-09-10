"""Author the remaining PA.16B visual families without touching approved art.

Themes use distinct object silhouettes, technologies use eight coherent branch
grammars with visible progression, features use concrete player-facing objects,
and era overlays distribute softly shaded props across room anchors.
"""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
INK, DEEP, TEAL = "#263c40", "#254a50", "#315f65"
SKY, CREAM, PAPER = "#4f91a2", "#fff7df", "#f8e8c8"
ORANGE, GOLD, GREEN, RED, PURPLE = "#e98d48", "#f0b34f", "#4f956f", "#b94e48", "#7866a6"


def save(relative: str, text: str) -> None:
    path = ROOT / relative
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text.strip() + "\n", encoding="utf-8")


def icon_svg(body: str, title: str, background: str = PAPER) -> str:
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" role="img" aria-label="{title}">
  <rect x="3" y="3" width="58" height="58" rx="15" fill="{background}" stroke="{TEAL}" stroke-width="4"/>
  <g fill="none" stroke="{INK}" stroke-width="4" stroke-linecap="round" stroke-linejoin="round">{body}</g>
</svg>'''


THEMES = {
    "space": f'<circle cx="29" cy="34" r="12" fill="{SKY}"/><path d="M10 39c10 8 32 7 44-5"/><path d="M46 12l2 5 5 2-5 2-2 5-2-5-5-2 5-2z" fill="{GOLD}"/>',
    "fantasy": f'<path d="M15 49h35L45 27l-7 6-6-16-7 16-7-6z" fill="{PURPLE}"/><path d="M26 49V37h12v12"/>',
    "military": f'<path d="M13 39h38v10H13zM20 28h21l8 11H16z" fill="{GREEN}"/><circle cx="23" cy="50" r="5"/><circle cx="42" cy="50" r="5"/><path d="M31 28V19h15"/>',
    "horror": f'<path d="M18 49V29c0-11 6-17 14-17s14 6 14 17v20l-7-5-7 5-7-5z" fill="{PURPLE}"/><path d="M25 28l4 4m10-4-4 4"/>',
    "pirates": f'<path d="M18 48l6-11m22 11-6-11"/><circle cx="32" cy="27" r="11" fill="{CREAM}"/><circle cx="27" cy="26" r="2" fill="{INK}"/><circle cx="37" cy="26" r="2" fill="{INK}"/><path d="M28 34h8M16 17l32 31m0-31L16 48"/>',
    "aliens": f'<path d="M17 26c3-13 27-13 30 0-3 15-10 23-15 23s-12-8-15-23z" fill="{SKY}"/><path d="M23 29c4-3 7-2 8 3-4 2-7 1-8-3zm18 0c-4-3-7-2-8 3 4 2 7 1 8-3z" fill="{INK}"/>',
    "western": f'<path d="M17 29c5-1 7-7 8-13h14c1 6 3 12 8 13-7 5-23 5-30 0z" fill="{ORANGE}"/><path d="M11 36c13 5 29 5 42 0M32 40v11"/><path d="M32 42l3 4 5 1-4 3-4 5-4-5-4-3 5-1z" fill="{GOLD}"/>',
    "detective": f'<circle cx="28" cy="27" r="13" fill="{SKY}"/><path d="M37 37l14 14M22 27h12M28 21v12"/>',
    "history": f'<path d="M17 16h31v34H17z" fill="{GOLD}"/><path d="M24 16v34M30 25h12m-12 8h12m-12 8h9"/>',
    "espionage": f'<path d="M14 26c11-11 25-11 36 0-11 14-25 14-36 0z" fill="{SKY}"/><circle cx="32" cy="26" r="6"/><path d="M18 46h28M23 40l-5 6m23-6 5 6"/>',
    "cyberpunk": f'<path d="M12 49V29h10v20m0 0V19h13v30m0 0V26h16v23" fill="{PURPLE}"/><path d="M10 49h44M28 13v12m0-6h8M42 32h7m-7 8h7" stroke="{SKY}"/>',
    "robots": f'<rect x="16" y="19" width="32" height="29" rx="7" fill="{SKY}"/><path d="M32 19v-7m-12 36v5m24-5v5M10 29h6m32 0h6"/><circle cx="25" cy="31" r="3" fill="{INK}"/><circle cx="39" cy="31" r="3" fill="{INK}"/><path d="M25 40h14"/>',
    "racing_theme": f'<path d="M12 42l7-15h26l7 15v7H12z" fill="{ORANGE}"/><circle cx="21" cy="49" r="5" fill="{CREAM}"/><circle cx="43" cy="49" r="5" fill="{CREAM}"/><path d="M22 27l5-8h10l5 8M18 42h28"/>',
    "sports": f'<circle cx="31" cy="32" r="18" fill="{CREAM}"/><path d="M31 14l6 9-6 7-7-7zm-17 18 10-2 5 8-5 10m25-16-10-2-5 8 5 10"/>',
    "crime": f'<path d="M20 48c-7-17-3-31 12-31s19 14 12 31"/><path d="M26 44c-4-11-2-20 6-20s10 9 6 20M31 29c-3 6-3 12-1 19m8-16c2 5 2 10 0 15" stroke="{RED}"/>',
    "dinosaurs": f'<path d="M15 45c3-13 12-24 26-29l8 8-8 6 6 5-8 4-6-5c-4 6-7 12-8 17z" fill="{GREEN}"/><circle cx="41" cy="23" r="2" fill="{INK}"/><path d="M12 51h39"/>',
    "superheroes": f'<path d="M32 12l17 7-4 20-13 13-13-13-4-20z" fill="{SKY}"/><path d="M24 33l8-14 8 14h-6v10h-4V33z" fill="{GOLD}"/>',
    "survival": f'<path d="M20 51c-5-11 4-16 8-22 4-6 1-12 1-12 12 6 18 15 14 25-3 8-15 13-23 9z" fill="{ORANGE}"/><path d="M28 49c-3-6 2-10 6-15 5 6 6 12 2 17"/>',
    "post_apocalypse": f'<path d="M12 49h40M17 49V31l9 4V22l9 5 7-11 5 33" fill="{RED}"/><path d="M23 43h5m8 0h5M14 18l36 34"/>',
    "zombies": f'<path d="M17 49l3-25 8-8 8 4 4 11 8 4-5 16" fill="{GREEN}"/><path d="M25 31l5 3m8-7-4 4M13 50h40"/><circle cx="27" cy="25" r="2" fill="{INK}"/>',
    "time_travel": f'<circle cx="32" cy="32" r="19" fill="{SKY}"/><path d="M32 20v13l9 6M16 20h9v9"/><path d="M19 22c-8 11-3 27 10 30" stroke="{ORANGE}"/>',
    "farming": f'<path d="M14 48h36V30L32 18 14 30z" fill="{ORANGE}"/><path d="M26 48V36h12v12M14 30L8 25m42 5 6-5"/><path d="M12 18c8 0 12 4 12 12-8 0-12-4-12-12z" fill="{GREEN}"/>',
    "city_building": f'<path d="M12 50V31h12v19m0 0V18h16v32m0 0V27h12v23" fill="{SKY}"/><path d="M9 50h46M29 25h6m-6 9h6m-6 9h6"/>',
    "medical": f'<path d="M22 13h20v11h10v20H42v10H22V44H12V24h10z" fill="{RED}"/><path d="M32 23v21M22 34h20" stroke="{CREAM}"/>',
    "business": f'<rect x="13" y="24" width="38" height="27" rx="4" fill="{GOLD}"/><path d="M24 24v-8h16v8M13 34h38M27 34v5h10v-5"/>',
    "steampunk": f'<circle cx="31" cy="33" r="13" fill="{GOLD}"/><path d="M31 13v7m0 26v7M11 33h7m26 0h8M17 19l5 5m18 18 5 5m0-28-5 5M22 42l-5 5"/><circle cx="31" cy="33" r="5"/><path d="M45 16h8v18" stroke="{ORANGE}"/>',
    "mythology": f'<path d="M15 49l17-35 17 35z" fill="{GOLD}"/><path d="M21 38h22M27 38V27h10v11M12 50h40"/><path d="M32 10l3 6 7 1-5 5" stroke="{PURPLE}"/>',
    "vikings": f'<path d="M19 26c-7-1-10-6-10-12 7 0 13 3 17 9m19 3c7-1 10-6 10-12-7 0-13 3-17 9"/><path d="M18 26h28v20c-8 7-20 7-28 0z" fill="{SKY}"/><path d="M25 35h14"/>',
    "samurai": f'<path d="M16 28h32l-7-12H23z" fill="{RED}"/><path d="M20 28v16c7 9 17 9 24 0V28M25 37h14M32 28v24"/>',
    "ancient_egypt": f'<path d="M10 50l22-38 22 38z" fill="{GOLD}"/><path d="M22 50l10-17 10 17M32 21v12"/>',
    "vampires": f'<path d="M15 21c10 5 24 5 34 0-2 18-7 29-17 33-10-4-15-15-17-33z" fill="{RED}"/><path d="M22 30l5 13 5-9 5 9 5-13" fill="{CREAM}"/>',
    "ghosts": f'<path d="M17 50V29c0-11 6-17 15-17s15 6 15 17v21l-8-6-7 6-7-6z" fill="{CREAM}"/><circle cx="26" cy="29" r="3" fill="{INK}"/><circle cx="38" cy="29" r="3" fill="{INK}"/>',
    "kaiju": f'<path d="M13 51l8-24 9-12 8 4 1 8 9 4 4 20z" fill="{GREEN}"/><path d="M20 30l-8-5m32 11 9-2M27 37l6 4 6-4"/><circle cx="34" cy="24" r="2" fill="{INK}"/>',
    "deep_sea": f'<path d="M12 41c10-10 18-10 27-2l12-9-2 15 3 8-14-7c-9 7-18 5-26-5z" fill="{SKY}"/><circle cx="24" cy="39" r="2" fill="{INK}"/><path d="M17 22c7-6 14-6 21 0M25 14c5-4 10-4 15 0"/>',
    "jungle": f'<path d="M16 51c1-18 7-29 16-38 9 9 15 20 16 38" fill="{GREEN}"/><path d="M32 17v34M14 32c7-3 12-2 18 4m18-4c-7-3-12-2-18 4"/><circle cx="43" cy="18" r="5" fill="{GOLD}"/>',
    "arctic": f'<path d="M10 49l15-25 8 12 7-18 14 31z" fill="{SKY}"/><path d="M20 32l5-8 5 7m6-4 4-9 6 11" stroke="{CREAM}"/><path d="M12 54h40"/>',
    "magic_academy": f'<path d="M13 25l19-11 19 11-19 11z" fill="{PURPLE}"/><path d="M20 31v12c7 6 17 6 24 0V31M51 25v17"/><path d="M32 39l2 4 5 1-4 3" stroke="{GOLD}"/>',
    "heist": f'<rect x="14" y="14" width="36" height="37" rx="5" fill="{SKY}"/><circle cx="32" cy="33" r="10"/><path d="M32 23v20M22 33h20M45 18h2"/><circle cx="32" cy="33" r="3" fill="{ORANGE}"/>',
    "mafia": f'<path d="M17 29c6-2 8-7 9-13h12c1 6 3 11 9 13-8 4-22 4-30 0z" fill="{INK}"/><path d="M20 35h24l-4 17H24z" fill="{PURPLE}"/><path d="M28 38l4 5 4-5" stroke="{CREAM}"/>',
    "automotive": f'<path d="M12 40l6-14h28l6 14v9H12z" fill="{ORANGE}"/><circle cx="21" cy="49" r="5" fill="{CREAM}"/><circle cx="43" cy="49" r="5" fill="{CREAM}"/><path d="M18 40h28M24 26l4-8h8l4 8"/>',
    "aviation": f'<path d="M9 35l19-5 7-17 6 2-4 17 16 8-2 5-17-4-7 12-5-2 3-13-15 2z" fill="{SKY}"/>',
    "railways": f'<path d="M18 14h28v28l-6 8H24l-6-8z" fill="{ORANGE}"/><path d="M23 20h18v12H23zM17 53h30M25 42h14"/><circle cx="25" cy="38" r="2" fill="{INK}"/><circle cx="39" cy="38" r="2" fill="{INK}"/>',
    "age_of_sail": f'<path d="M32 11v35M32 15l17 19H32M29 20L15 36h14" fill="{CREAM}"/><path d="M12 47c8 6 31 6 40 0" stroke="{SKY}"/>',
    "cooking": f'<path d="M14 35h36c-1 11-8 17-18 17s-17-6-18-17z" fill="{ORANGE}"/><path d="M11 35h42M24 28c-4-6 4-7 0-14m14 14c-4-6 4-7 0-14"/>',
    "music_rhythm": f'<path d="M25 18v29m0-24 23-6v25"/><circle cx="18" cy="48" r="7" fill="{ORANGE}"/><circle cx="41" cy="43" r="7" fill="{SKY}"/><path d="M11 27h8m31 4h5"/>',
    "wildlife": f'<path d="M18 49c-8-4-6-15 2-16-3-9 8-13 13-6 5-7 16-2 12 7 9 3 8 14 0 17-8 3-19 2-27-2z" fill="{GREEN}"/><circle cx="23" cy="26" r="5"/><circle cx="41" cy="25" r="5"/><circle cx="32" cy="17" r="5"/>',
    "dragons": f'<path d="M13 47c5-20 14-31 29-34l8 8-10 6 8 7-13 2-6 15z" fill="{RED}"/><circle cx="41" cy="20" r="2" fill="{INK}"/><path d="M39 27l11 1M20 38l-9-6"/>',
    "fairy_tales": f'<path d="M13 18c8-4 15-2 19 4 4-6 11-8 19-4v31c-8-4-15-2-19 4-4-6-11-8-19-4z" fill="{SKY}"/><path d="M32 22v31"/><path d="M43 13l2 5 5 2-5 2-2 5-2-5-5-2 5-2z" fill="{GOLD}"/>',
    "nuclear_wasteland": f'<circle cx="32" cy="33" r="8" fill="{GOLD}"/><path d="M32 12l-7 13m-13 20 15-3m25 3-15-3" stroke="{RED}" stroke-width="8"/><circle cx="32" cy="33" r="19"/>',
    "virtual_worlds": f'<path d="M12 21h40v28H12z" fill="{PURPLE}"/><path d="M18 27l9 9-9 7m28-16-9 9 9 7" stroke="{SKY}"/><circle cx="32" cy="36" r="4" fill="{GOLD}"/>',
    "hacking": f'<path d="M14 17h36v31H14z" fill="{INK}"/><path d="M20 26l7 6-7 6m11 0h11" stroke="{GREEN}"/><path d="M22 53h20"/>',
    "archaeology": f'<path d="M17 48l11-26 9-7 6 3-3 10-17 23z" fill="{GOLD}"/><path d="M39 17l9-7M13 52h39M29 35l7 3"/><circle cx="48" cy="10" r="3" fill="{ORANGE}"/>',
    "treasure_hunting": f'<path d="M13 25l8-9h22l8 9v25H13z" fill="{GOLD}"/><path d="M13 30h38M27 30v9h10v-9M20 16l4 9m20-9-4 9"/><circle cx="32" cy="43" r="3" fill="{ORANGE}"/>',
    "theme_park": f'<circle cx="32" cy="31" r="17" fill="{SKY}"/><path d="M32 14v34M15 31h34M20 19l24 24m0-24L20 43"/><path d="M22 54h20M32 48v6"/>',
    "occult": f'<circle cx="32" cy="33" r="19" fill="{PURPLE}"/><path d="M32 16l5 12 13 1-10 8 4 13-12-7-12 7 4-13-10-8 13-1z" stroke="{GOLD}"/>',
}


TECH_BRANCHES = {
    "graphics": ["2d_renderer", "adv_2d", "3d_renderer", "texture_mapping", "dynamic_lighting", "shaders", "pbr", "ray_tracing", "particle_systems", "global_illumination", "neural_upscaling", "lod_systems"],
    "tools": ["save_system", "level_editor", "scripting", "optimization", "build_pipeline", "hot_reload", "telemetry", "localization_pipeline", "replay_system"],
    "audio": ["audio_tools", "advanced_audio", "positional_audio", "adaptive_music", "procedural_audio", "voice_synthesis"],
    "architecture": ["systems_framework", "state_machines", "entity_component", "sandbox_systems"],
    "ai": ["basic_ai_tech", "pathfinding", "behaviour_trees", "utility_ai", "director_ai", "ml_agents", "data_pipeline_ml"],
    "network": ["lan_play", "online_play", "matchmaking", "netcode_rollback", "dedicated_servers", "anti_cheat", "crossplay"],
    "physics": ["rigid_body", "soft_body", "destruction", "fluid_dynamics", "vehicle_physics", "weather_time", "voxel_terrain"],
    "animation": ["keyframe_anim", "skeletal_anim", "blend_trees", "facial_animation", "inverse_kinematics", "physics_animation", "procedural_animation", "mocap_pipeline"],
    "streaming": ["tile_streaming", "world_streaming", "open_world_tech", "procedural_worlds"],
}

BRANCH_COLORS = {"graphics": SKY, "tools": GOLD, "audio": ORANGE, "architecture": TEAL, "ai": GREEN, "network": PURPLE, "physics": RED, "animation": "#d17a9b", "streaming": "#4f8795"}


def tech_mark(branch: str) -> str:
    return {
        "graphics": '<rect x="15" y="19" width="32" height="24" rx="3"/><path d="M24 49h14M31 43v6M21 35l7-8 5 5 7-8"/>',
        "tools": '<path d="M18 18l9 9 11-11 8 8-11 11 11 11-8 8-11-11-9 9-7-7 9-10-9-10z"/>',
        "audio": '<path d="M15 28h9l12-10v28L24 36h-9z"/><path d="M43 25c5 4 5 10 0 14M48 19c10 8 10 18 0 26"/>',
        "architecture": '<rect x="12" y="16" width="17" height="14"/><rect x="35" y="16" width="17" height="14"/><rect x="24" y="37" width="17" height="14"/><path d="M29 23h6m-3 7v7"/>',
        "ai": '<path d="M18 43V26c0-8 6-13 14-13s14 5 14 13v17c-5 7-23 7-28 0z"/><path d="M24 28l7 5 9-8M25 41h14"/>',
        "network": '<circle cx="16" cy="39" r="6"/><circle cx="48" cy="39" r="6"/><circle cx="32" cy="17" r="6"/><path d="M20 34l8-12m8 0 8 12M22 39h20"/>',
        "physics": '<circle cx="32" cy="32" r="5"/><ellipse cx="32" cy="32" rx="21" ry="9"/><ellipse cx="32" cy="32" rx="9" ry="21" transform="rotate(45 32 32)"/>',
        "animation": '<circle cx="20" cy="19" r="4"/><circle cx="42" cy="25" r="4"/><circle cx="25" cy="43" r="4"/><path d="M23 22l15 2M39 29L28 40M21 23l3 16"/>',
        "streaming": '<circle cx="32" cy="32" r="18"/><path d="M14 32h36M32 14c-8 9-8 27 0 36m0-36c8 9 8 27 0 36"/>',
    }[branch]


def tech_svg(identifier: str, branch: str, rank: int) -> str:
    colour = BRANCH_COLORS[branch]
    dots = ''.join(f'<circle cx="{46 - i * 7}" cy="12" r="2.5" fill="{colour}" stroke="none"/>' for i in range(1 + min(rank // 2, 3)))
    body = f'<rect x="4" y="4" width="8" height="56" rx="4" fill="{colour}" stroke="none"/>{tech_mark(branch)}{dots}'
    return icon_svg(body, identifier.replace("_", " "), CREAM)


FEATURE_MARKS = {
    "save_system": '<path d="M16 13h32v38H16z" fill="#4f91a2"/><path d="M22 13v13h19V13M23 51V36h18v15"/>',
    "character_creation": '<circle cx="29" cy="24" r="9" fill="#e98d48"/><path d="M14 51c2-12 8-18 15-18s13 6 15 18" fill="#4f91a2"/><path d="M48 18v16m-8-8h16"/>',
    "inventory": '<path d="M15 22h34v29H15z" fill="#f0b34f"/><path d="M24 22c0-8 16-8 16 0M26 33h12m-12 8h12"/>',
    "dialogue_system": '<path d="M11 16h39v25H28l-10 9v-9h-7z" fill="#4f91a2"/><path d="M19 25h23m-23 8h16"/>',
    "dialogue_trees": '<path d="M9 14h30v18H22l-8 7v-7H9z" fill="#4f91a2"/><path d="M31 37l-9 12m9-12 9 12m-9-12 14-5"/>',
    "turn_based_combat": '<path d="M16 19h16v15H16zM32 34h16v15H32z" fill="#f0b34f"/><path d="M37 17l11 5-11 5M27 47l-11-5 11-5"/>',
    "real_time_combat": '<path d="M17 48l29-29 4 4-29 29z" fill="#e98d48"/><path d="M14 39l11 11M38 16l11 11"/><circle cx="19" cy="19" r="7"/><path d="M19 15v5l4 2"/>',
    "multiple_endings": '<path d="M14 49V18m0 11h14l10-10m-10 10 10 10m-10-10v18h22"/><circle cx="42" cy="19" r="5" fill="#f0b34f"/><circle cx="42" cy="39" r="5" fill="#e98d48"/><circle cx="50" cy="47" r="5" fill="#4f956f"/>',
    "basic_ai": '<path d="M17 45V27c0-8 6-13 15-13s15 5 15 13v18" fill="#4f956f"/><path d="M24 31h16M27 39h10"/>',
    "advanced_ai": '<path d="M14 43V25c0-8 7-13 18-13s18 5 18 13v18" fill="#4f956f"/><path d="M20 30l7-6 6 7 9-9M22 40h20"/>',
    "2d_graphics": '<rect x="13" y="15" width="38" height="34" fill="#4f91a2"/><path d="M21 39l8-9 6 6 7-11 6 14z" fill="#f0b34f"/><circle cx="24" cy="24" r="4"/>',
    "3d_graphics": '<path d="M32 12l18 10v21L32 53 14 43V22z" fill="#7866a6"/><path d="M14 22l18 11 18-11M32 33v20"/>',
    "voice_acting": '<path d="M15 28h10l11-10v28L25 36H15z" fill="#e98d48"/><path d="M43 25c5 4 5 10 0 14M48 19c10 8 10 18 0 26"/>',
    "physics": '<circle cx="32" cy="32" r="5" fill="#b94e48"/><ellipse cx="32" cy="32" rx="21" ry="9"/><ellipse cx="32" cy="32" rx="9" ry="21" transform="rotate(45 32 32)"/>',
    "open_world": '<circle cx="32" cy="32" r="19" fill="#4f956f"/><path d="M13 35l11-8 9 5 8-10 10 8M15 43h34"/>',
    "online_multiplayer": '<circle cx="23" cy="25" r="7" fill="#e98d48"/><circle cx="43" cy="27" r="6" fill="#4f91a2"/><path d="M10 50c2-11 8-16 15-16s13 5 15 16m-3-10c9-3 15 2 17 10"/>',
    "achievements": '<path d="M20 12h24v17c0 9-5 15-12 18-7-3-12-9-12-18z" fill="#f0b34f"/><path d="M20 18h-8c0 8 4 12 10 12m22-12h8c0 8-4 12-10 12M27 47v6m-9 0h28"/>',
    "procedural_generation": '<path d="M17 17h12v12H17zm18 18h12v12H35z" fill="#7866a6"/><path d="M35 17h12v12H35zM17 35h12v12H17z"/><path d="M11 32h42" stroke="#e98d48"/>',
    "crafting_system": '<path d="M17 48l29-29 4 4-29 29z" fill="#f0b34f"/><path d="M14 18l13 13m-9-17 13 13M37 39l13 13"/>',
    "difficulty_options": '<path d="M15 18h34M15 32h34M15 46h34"/><circle cx="25" cy="18" r="5" fill="#4f956f"/><circle cx="40" cy="32" r="5" fill="#f0b34f"/><circle cx="31" cy="46" r="5" fill="#b94e48"/>',
    "new_game_plus": '<path d="M17 35c0-10 7-18 18-18 7 0 12 3 16 8M47 17l4 8-8 3"/><path d="M47 35c0 10-7 18-18 18-7 0-12-3-16-8M17 53l-4-8 8-3"/><path d="M32 25v16m-8-8h16"/>',
    "photo_mode": '<rect x="11" y="21" width="42" height="29" rx="5" fill="#4f91a2"/><path d="M20 21l4-7h16l4 7"/><circle cx="32" cy="35" r="9" fill="#fff7df"/><circle cx="47" cy="27" r="2" fill="#e98d48"/>',
    "cosmetic_customization": '<path d="M20 18l8-5h8l8 5 9 7-7 9-5-5v23H23V29l-5 5-7-9z" fill="#7866a6"/><path d="M28 21h8"/>',
    "mod_support": '<path d="M13 17h16v8c5-4 11 0 8 6h14v17H36c3 7-8 9-9 0H13V34c7 3 9-7 0-8z" fill="#4f956f"/>',
    "cooperative_campaign": '<circle cx="24" cy="24" r="7" fill="#e98d48"/><circle cx="42" cy="24" r="7" fill="#4f91a2"/><path d="M10 51c2-12 8-18 14-18 5 0 8 2 10 6 2-4 5-6 10-6 6 0 10 6 11 18"/><path d="M29 43h10"/>',
    "live_service_content": '<path d="M16 18h32v33H16z" fill="#4f91a2"/><path d="M16 27h32M23 13v10m18-10v10"/><path d="M32 33l3 6 7 1-5 5-5 6-5-6-5-5 7-1z" fill="#f0b34f"/>',
    "stealth_mechanics": '<path d="M10 32c10-13 34-13 44 0-10 13-34 13-44 0z" fill="#263c40"/><circle cx="32" cy="32" r="8" fill="#4f91a2"/><path d="M15 49l34-34" stroke="#e98d48"/>',
    "base_building": '<path d="M13 49V29l13-9 8 6 8-13 10 9v27z" fill="#e98d48"/><path d="M21 49V36h10v13m9-14h7M10 49h44"/>',
    "dynamic_weather_gameplay": '<path d="M15 38c-7-8 2-18 11-14 3-12 23-9 23 4 9 2 8 14 0 16H17" fill="#4f91a2"/><path d="M21 49l-3 6m14-6-3 6m14-6-3 6" stroke="#7866a6"/>',
    "accessibility_suite": '<circle cx="32" cy="15" r="6" fill="#e98d48"/><path d="M12 25h40M32 22v30m0-19L20 49m12-16 12 16"/><circle cx="32" cy="33" r="19"/>',
    "companion_characters": '<circle cx="24" cy="24" r="7" fill="#e98d48"/><path d="M10 51c2-12 8-18 14-18s12 6 14 18"/><path d="M40 35c-5-7 2-13 7-8 5-5 12 1 7 8l-7 8z" fill="#b94e48"/>',
}


def era_svg(identifier: str, decade: int) -> str:
    palettes = [("#c8ad79", "#8c6b3e"), ("#a89078", "#5f5964"), ("#7d8588", "#40484c"), ("#547b81", "#263c40"), ("#6a8582", "#254a50")]
    light, shade = palettes[decade]
    shelf = [
        '<rect x="538" y="154" width="34" height="42" rx="3"/><path d="M545 162h20v17h-20zM548 188h16"/><rect x="579" y="170" width="22" height="26" rx="3"/>',
        '<rect x="526" y="151" width="39" height="45" rx="3"/><path d="M532 158h27v21h-27zM538 187h16"/><path d="M574 162h34v34h-34zM580 170h22m-22 8h22"/>',
        '<rect x="523" y="153" width="45" height="31" rx="3"/><path d="M530 159h31v18h-31zM545 184v11"/><rect x="579" y="151" width="28" height="45" rx="3"/>',
        '<path d="M521 178h54l-5-29h-44zM548 178v18"/><rect x="584" y="155" width="23" height="41" rx="5"/>',
        '<path d="M518 179h61l-7-32h-47zM548 179v17"/><rect x="588" y="149" width="26" height="47" rx="5"/><path d="M594 157h14v27h-14z"/>',
    ][decade]
    desk = [
        '<rect x="252" y="299" width="62" height="45" rx="3"/><path d="M260 307h46v25h-46zM283 344v19M268 363h31"/><rect x="322" y="327" width="26" height="17" rx="2"/><circle cx="341" cy="337" r="2"/>',
        '<rect x="245" y="299" width="64" height="43" rx="3"/><path d="M253 307h48v23h-48zM277 342v20"/><rect x="318" y="309" width="35" height="34" rx="2"/><path d="M325 317h21m-21 8h21"/>',
        '<rect x="243" y="302" width="61" height="38" rx="3"/><path d="M251 309h45v22h-45zM273 340v19"/><path d="M313 344h48l-8-31h-33z"/><circle cx="346" cy="354" r="6"/>',
        '<path d="M238 339h77l-7-39h-63zM276 339v22"/><path d="M322 311h33v30h-33zM328 318h21m-21 8h21"/><path d="M363 330h17"/>',
        '<path d="M232 338h91l-10-40h-71zM277 338v23M252 361h52"/><rect x="333" y="301" width="30" height="48" rx="6"/><path d="M341 308h14v27h-14z"/><rect x="372" y="319" width="33" height="21" rx="3"/>',
    ][decade]
    floor = [
        '<rect x="104" y="384" width="20" height="25" rx="2"/><path d="M110 389h8m-8 6h8"/><path d="M134 397h32m-27-8h22"/>',
        '<circle cx="112" cy="397" r="15"/><circle cx="112" cy="397" r="5"/><path d="M136 407h35l-5-21h-25z"/>',
        '<rect x="99" y="382" width="45" height="28" rx="3"/><circle cx="121" cy="396" r="9"/><path d="M152 386h22v24h-22z"/>',
        '<path d="M98 406h53l-7-27h-39z"/><path d="M160 386h27v24h-27zM166 392h15"/>',
        '<rect x="99" y="382" width="47" height="29" rx="4"/><path d="M107 389h31v15h-31"/><rect x="157" y="379" width="33" height="34" rx="5"/>',
    ][decade]
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 768 512" role="img" aria-label="{identifier.replace('_', ' ')} integrated office technology">
  <g fill="#1e2d2f" opacity=".16" stroke="none"><ellipse cx="290" cy="365" rx="78" ry="14"/><ellipse cx="567" cy="202" rx="64" ry="9"/><ellipse cx="137" cy="416" rx="55" ry="10"/></g>
  <g fill="{light}" stroke="{shade}" stroke-width="4" stroke-linecap="round" stroke-linejoin="round">{desk}{shelf}{floor}</g>
  <g fill="none" stroke="{CREAM}" stroke-width="2" opacity=".55"><path d="M250 307l51 0M530 159h30M105 389h31"/></g>
</svg>'''


def main() -> None:
    theme_ids = [row["id"] for row in json.loads((ROOT / "data/themes.json").read_text(encoding="utf-8"))]
    missing = sorted(set(theme_ids) - THEMES.keys())
    if missing:
        raise ValueError(f"Missing theme art definitions: {missing}")
    for identifier in theme_ids:
        save(f"assets/icons/themes/{identifier}.svg", icon_svg(THEMES[identifier], identifier.replace("_", " ")))

    seen: set[str] = set()
    for branch, identifiers in TECH_BRANCHES.items():
        for rank, identifier in enumerate(identifiers):
            save(f"assets/icons/technologies/{identifier}.svg", tech_svg(identifier, branch, rank))
            seen.add(identifier)
    tech_ids = {row["id"] for row in json.loads((ROOT / "data/technologies.json").read_text(encoding="utf-8"))}
    if seen != tech_ids:
        raise ValueError(f"Technology branch mismatch: missing={sorted(tech_ids-seen)}, extra={sorted(seen-tech_ids)}")

    feature_ids = [row["id"] for row in json.loads((ROOT / "data/game_features.json").read_text(encoding="utf-8"))]
    missing = sorted(set(feature_ids) - FEATURE_MARKS.keys())
    if missing:
        raise ValueError(f"Missing feature art definitions: {missing}")
    for identifier in feature_ids:
        save(f"assets/icons/features/{identifier}.svg", icon_svg(FEATURE_MARKS[identifier], identifier.replace("_", " "), CREAM))

    for decade, identifier in enumerate(["era_1980s", "era_1990s", "era_2000s", "era_2010s", "era_2020s"]):
        save(f"assets/offices/era_overlays/{identifier}.svg", era_svg(identifier, decade))
    print(f"Authored {len(theme_ids)} themes, {len(tech_ids)} technologies, {len(feature_ids)} features and 5 era overlays")


if __name__ == "__main__":
    main()
