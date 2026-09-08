"""Add the post-1995 genres, and give every theme an affinity for them.

25 themes x 7 new genres is 175 affinity values. Inventing them at random would
put noise where the original data has intent, so each new genre is defined as a
blend of the genres that already exist: Survival Horror leans on Adventure and
RPG, Battle Royale on Shooter and Action, and so on. A theme's affinity for a
new genre is the weighted average of its affinities for that blend, nudged by a
small authored bias so the new genre is not merely a copy of its parents.

    python scripts/tools/author_genres.py

Idempotent. Only touches the genres listed here and the affinity keys they add;
the original eight genres and all existing affinity values are left alone.
"""
import json
import os

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
GENRES = os.path.join(ROOT, "data", "genres.json")
THEMES = os.path.join(ROOT, "data", "themes.json")
PLATFORMS = os.path.join(ROOT, "data", "platforms.json")

ORIGINAL = {"action", "adventure", "rpg", "strategy", "simulation", "puzzle", "racing", "shooter"}

# id, name, unlock_year, unlock_games, story_weight, blend of existing genres,
# and a flat bias applied to every theme's derived affinity.
LATER = [
    ("fighting", "Fighting", 1996, 14, 0.4, {"action": 0.75, "racing": 0.25}, -0.02),
    ("horror", "Survival Horror", 1998, 18, 1.0, {"adventure": 0.55, "action": 0.25, "rpg": 0.20}, 0.0),
    ("mmo", "Online World", 2002, 26, 0.9, {"rpg": 0.65, "strategy": 0.20, "simulation": 0.15}, 0.03),
    ("sandbox", "Sandbox", 2008, 34, 0.55, {"simulation": 0.5, "adventure": 0.3, "strategy": 0.2}, 0.02),
    ("battle_royale", "Battle Royale", 2018, 44, 0.25, {"shooter": 0.7, "action": 0.3}, -0.03),
    ("immersive_vr", "Immersive VR", 2024, 52, 0.85, {"adventure": 0.45, "action": 0.3, "simulation": 0.25}, 0.02),
    ("neural_sim", "Neural Sim", 2036, 64, 0.75, {"simulation": 0.55, "rpg": 0.25, "strategy": 0.20}, 0.04),
]


def main():
    genres = json.load(open(GENRES, encoding="utf-8"))
    known = {g["id"] for g in genres}
    for gid, name, year, games, story_weight, _blend, _bias in LATER:
        if gid in known:
            continue
        genres.append({
            "id": gid, "name": name,
            "unlock_year": year, "unlock_games": games,
            "story_weight": story_weight,
        })
    with open(GENRES, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(json.dumps(genres, indent=2) + "\n")

    themes = json.load(open(THEMES, encoding="utf-8"))
    for theme in themes:
        affinity = theme.setdefault("genre_affinity", {})
        for gid, _name, _year, _games, _sw, blend, bias in LATER:
            if gid in affinity:
                continue
            total = sum(
                affinity.get(parent, 1.0) * weight for parent, weight in blend.items())
            affinity[gid] = round(min(max(total + bias, 0.60), 1.40), 2)
    with open(THEMES, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(json.dumps(themes, indent=2) + "\n")

    # Platforms carry a per-genre audience; anything missing reads as 1.0, which
    # would quietly make every new genre neutral everywhere.
    platforms = json.load(open(PLATFORMS, encoding="utf-8"))
    for platform in platforms:
        audience = platform.setdefault("audience", {})
        for gid, _name, _year, _games, _sw, blend, bias in LATER:
            if gid in audience:
                continue
            total = sum(
                audience.get(parent, 1.0) * weight for parent, weight in blend.items())
            audience[gid] = round(min(max(total + bias, 0.60), 1.45), 2)
    with open(PLATFORMS, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(json.dumps(platforms, indent=2) + "\n")

    print("genres now: %d" % len(genres))
    for g in genres:
        print("  %-14s %s  unlocks %d / %d games" % (
            g["id"], "(original)" if g["id"] in ORIGINAL else "(new)     ",
            g["unlock_year"], g["unlock_games"]))
    sample = themes[0]
    print("\nexample derived affinities -- theme '%s':" % sample["id"])
    for gid, _n, _y, _g, _sw, _b, _bias in LATER:
        print("  %-14s %.2f" % (gid, sample["genre_affinity"][gid]))


if __name__ == "__main__":
    main()
