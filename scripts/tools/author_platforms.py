"""Author the post-1995 platform generations, out to 2050.

The market_curve on every platform is a per-year install base, hand-authored in
the original six. Writing 45 more years of them by hand would be error-prone and
inconsistent, so the later generations are generated from the same curve shape
the authored ones already have: a ramp from roughly a tenth of peak up to
peak_users, then a decay that steepens as the hardware ages.

    python scripts/tools/author_platforms.py

Idempotent -- it rewrites the generated platforms every run and leaves the six
original ones exactly as authored.
"""
import json
import os

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
PLATFORMS = os.path.join(ROOT, "data", "platforms.json")
GENRES = os.path.join(ROOT, "data", "genres.json")

ORIGINAL = {"microstar_64", "ibm_compatible", "famiclone", "pocket_play", "mega16", "playbox32"}

# id, name, announce, release, peak, retire, peak_users, dev_cost, fee, royalty,
# price, cost_multiplier, audience-profile, plateau
#
# `plateau` is the share of peak a platform never falls below. Consoles leave 0
# and decay away to nothing. An open platform does not: PC gaming did not end
# when a hardware generation did, and mobile did not either. Without this the
# PC line collapsed to under a million users by 2014 and stayed nominally
# "available" but commercially dead for the next forty years.
LATER = [
    ("home_pc", "Home PC", 1997, 1998, 2008, 2050, 60_000_000, 3_200, 0, 0.0, 1200, 3.4,
     {"action": 1.0, "adventure": 1.2, "rpg": 1.3, "strategy": 1.4, "simulation": 1.35,
      "puzzle": 1.05, "racing": 0.9, "shooter": 1.25}, 0.62),
    ("dreamcube", "DreamCube", 1997, 1998, 2002, 2007, 24_000_000, 4_200, 5_000, 0.15, 199, 4.0,
     {"action": 1.3, "adventure": 1.15, "rpg": 1.2, "strategy": 0.9, "simulation": 1.0,
      "puzzle": 0.95, "racing": 1.3, "shooter": 1.3}, 0.0),
    ("playbox64", "PlayBox 64", 1999, 2000, 2005, 2011, 48_000_000, 6_500, 7_500, 0.16, 299, 4.6,
     {"action": 1.35, "adventure": 1.15, "rpg": 1.3, "strategy": 0.9, "simulation": 1.0,
      "puzzle": 0.85, "racing": 1.3, "shooter": 1.4}, 0.0),
    ("pocket_dual", "Pocket Dual", 2001, 2002, 2006, 2011, 38_000_000, 3_400, 3_500, 0.13, 149, 3.0,
     {"action": 1.1, "adventure": 1.1, "rpg": 1.35, "strategy": 1.05, "simulation": 1.15,
      "puzzle": 1.45, "racing": 1.0, "shooter": 0.85}, 0.0),
    ("nexus_hd", "Nexus HD", 2005, 2006, 2011, 2017, 72_000_000, 12_000, 14_000, 0.17, 399, 5.6,
     {"action": 1.35, "adventure": 1.2, "rpg": 1.25, "strategy": 0.9, "simulation": 0.95,
      "puzzle": 0.8, "racing": 1.25, "shooter": 1.45}, 0.0),
    ("palmscreen", "Palmscreen", 2008, 2009, 2016, 2028, 130_000_000, 5_000, 2_500, 0.30, 5, 2.4,
     {"action": 1.0, "adventure": 0.9, "rpg": 0.95, "strategy": 1.1, "simulation": 1.2,
      "puzzle": 1.5, "racing": 1.05, "shooter": 0.85}, 0.45),
    ("vector_one", "Vector One", 2013, 2014, 2019, 2026, 92_000_000, 22_000, 18_000, 0.17, 449, 6.4,
     {"action": 1.35, "adventure": 1.25, "rpg": 1.3, "strategy": 0.95, "simulation": 1.0,
      "puzzle": 0.8, "racing": 1.2, "shooter": 1.4}, 0.0),
    ("helix_vr", "Helix VR", 2020, 2021, 2028, 2038, 58_000_000, 30_000, 20_000, 0.18, 549, 7.2,
     {"action": 1.3, "adventure": 1.35, "rpg": 1.15, "strategy": 0.85, "simulation": 1.4,
      "puzzle": 1.0, "racing": 1.3, "shooter": 1.35}, 0.0),
    ("continuum", "Continuum", 2028, 2029, 2036, 2044, 165_000_000, 45_000, 26_000, 0.18, 599, 8.0,
     {"action": 1.3, "adventure": 1.25, "rpg": 1.3, "strategy": 1.0, "simulation": 1.1,
      "puzzle": 0.9, "racing": 1.15, "shooter": 1.35}, 0.0),
    ("lattice", "Lattice", 2037, 2038, 2045, 2050, 210_000_000, 62_000, 32_000, 0.19, 649, 8.8,
     {"action": 1.25, "adventure": 1.3, "rpg": 1.35, "strategy": 1.05, "simulation": 1.15,
      "puzzle": 0.95, "racing": 1.1, "shooter": 1.25}, 0.0),
    ("ember", "Ember", 2046, 2047, 2050, 2050, 260_000_000, 80_000, 38_000, 0.19, 699, 9.4,
     {"action": 1.3, "adventure": 1.3, "rpg": 1.3, "strategy": 1.05, "simulation": 1.15,
      "puzzle": 0.95, "racing": 1.15, "shooter": 1.3}, 0.0),
]

FINAL_YEAR = 2050


def curve(release, peak_year, retire, peak_users, plateau=0.0):
    """Install base per year, shaped like the six authored platforms.

    Ramp: starts near a tenth of peak and accelerates into it. Decay: geometric
    and steepening, so a dead platform trails off rather than falling off a
    cliff. A platform still alive in 2050 simply stops at 2050.
    """
    out = {}
    end = min(retire, FINAL_YEAR)
    ramp_years = max(peak_year - release, 1)
    for offset in range(ramp_years):
        year = release + offset
        if year > FINAL_YEAR:
            return out
        fraction = 0.10 + 0.90 * ((offset / ramp_years) ** 1.7)
        out[str(year)] = int(round(peak_users * fraction / 1000.0)) * 1000
    if peak_year <= FINAL_YEAR:
        out[str(peak_year)] = peak_users
    remaining = peak_users
    floor = peak_users * plateau
    # An evergreen platform settles onto its plateau instead of decaying away.
    rate = 0.88 if plateau > 0.0 else 0.68
    for year in range(peak_year + 1, end + 1):
        if year > FINAL_YEAR:
            break
        remaining = max(remaining * rate, floor)
        if plateau <= 0.0:
            rate = max(rate - 0.07, 0.32)
        out[str(year)] = max(int(round(remaining / 1000.0)) * 1000, 40_000)
    return out


def main():
    genre_ids = [g["id"] for g in json.load(open(GENRES, encoding="utf-8"))]
    platforms = json.load(open(PLATFORMS, encoding="utf-8"))
    kept = [p for p in platforms if p["id"] in ORIGINAL]

    for (pid, name, announce, release, peak_year, retire, peak_users,
         dev_cost, fee, royalty, price, cost_multiplier, audience, plateau) in LATER:
        # Any genre unlocked after this table was written defaults to neutral
        # rather than silently vanishing from the platform's audience.
        full_audience = {g: round(float(audience.get(g, 1.0)), 2) for g in genre_ids}
        kept.append({
            "id": pid, "name": name,
            "announce_year": announce, "release_year": release,
            "peak_year": peak_year, "retire_year": retire,
            "peak_users": peak_users,
            "development_cost": dev_cost, "platform_fee": fee,
            "royalty": royalty, "price": price,
            "market_curve": curve(release, peak_year, retire, peak_users, plateau),
            "audience": full_audience,
            "cost_multiplier": cost_multiplier,
        })

    kept.sort(key=lambda p: (p["release_year"], p["id"]))
    with open(PLATFORMS, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(json.dumps(kept, indent=2) + "\n")

    print("%-16s %8s %8s %8s %14s" % ("platform", "release", "peak", "retire", "peak users"))
    for p in kept:
        print("%-16s %8d %8d %8d %14s" % (
            p["id"], p["release_year"], p["peak_year"], p["retire_year"],
            "{:,}".format(p["peak_users"])))

    print("\nplatforms on sale, by year:")
    for year in range(1985, FINAL_YEAR + 1, 5):
        live = [p["id"] for p in kept
                if p["release_year"] <= year <= p["retire_year"]]
        print("  %d  %d  %s" % (year, len(live), ", ".join(live) or "NONE"))
    gaps = [y for y in range(1985, FINAL_YEAR + 1)
            if not any(p["release_year"] <= y <= p["retire_year"] for p in kept)]
    print("\nyears with no platform at all: %s" % (gaps or "none"))

    # "Available" is not the same as "worth shipping on". A year whose biggest
    # market is tiny is a dead year even though the gap check above passes --
    # which is exactly how the PC line hid a forty-year dead tail.
    print("\nbiggest install base actually on sale, by year:")
    thin = []
    for year in range(1985, FINAL_YEAR + 1):
        best = 0
        for p in kept:
            best = max(best, int(p["market_curve"].get(str(year), 0)))
        if year % 5 == 0:
            print("  %d  %s" % (year, "{:,}".format(best)))
        if best < 2_000_000:
            thin.append(year)
    print("\nyears whose biggest market is under 2 million: %s" % (thin or "none"))


if __name__ == "__main__":
    main()
