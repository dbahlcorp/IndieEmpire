"""Aggregate BalanceProbe CSV dumps into a readable balance report.

    python scripts/tests/balance/analyse.py <dir-with-games_*.csv> [label]

Reports the things a balance pass actually needs to see: the review
distribution, how often the attach-rate ceiling is pinned, quality ratio per
project size, the cash curve, and how many releases lost money.
"""
import csv
import json
import re
import glob
import os
import statistics as st
import sys

directory = sys.argv[1]
label = sys.argv[2] if len(sys.argv) > 2 else os.path.basename(directory.rstrip("/\\"))

games, years = [], []
for path in sorted(glob.glob(os.path.join(directory, "games_*.csv"))):
    games += list(csv.DictReader(open(path)))
for path in sorted(glob.glob(os.path.join(directory, "years_*.csv"))):
    years += list(csv.DictReader(open(path)))

if not games:
    sys.exit("no games_*.csv under %s" % directory)

seeds = sorted({g["seed"] for g in games})
reviews = [float(g["review"]) for g in games]
attach = [float(g["attach_pct"]) for g in games]
profits = [int(g["profit"]) for g in games]

print("=" * 72)
print("BALANCE REPORT -- %s  (%d seeds, %d releases)" % (label, len(seeds), len(games)))
print("=" * 72)

print("\nREVIEW DISTRIBUTION")
buckets = [(0, 4), (4, 5), (5, 6), (6, 7), (7, 8), (8, 9), (9, 9.5), (9.5, 10.1)]
for lo, hi in buckets:
    n = sum(1 for r in reviews if lo <= r < hi)
    print("  %4.1f-%4.1f %5d  %5.1f%%  %s" % (lo, hi, n, 100 * n / len(reviews), "#" * int(60 * n / len(reviews))))
print("  mean %.2f  median %.2f  stdev %.2f  min %.1f  max %.1f"
      % (st.mean(reviews), st.median(reviews), st.pstdev(reviews), min(reviews), max(reviews)))
pinned = sum(1 for r in reviews if r >= 9.75)
print("  at the 9.8 review ceiling: %d (%.1f%%)" % (pinned, 100 * pinned / len(reviews)))

print("\nSALES CEILING (attach rate vs platform install base)")
capped = sum(1 for a in attach if a >= 7.99)
print("  mean %.2f%%  median %.2f%%  max %.2f%%" % (st.mean(attach), st.median(attach), max(attach)))
print("  pinned at the 8%% cap: %d (%.1f%%)" % (capped, 100 * capped / len(attach)))
distinct = len({g["units"] for g in games})
print("  distinct unit totals: %d of %d releases" % (distinct, len(games)))

print("\nQUALITY RATIO BY SIZE  (1.0 = met the size's expected_quality bar)")
print("  %-7s %5s %7s %7s %7s %7s %7s" % ("size", "n", "mean", "median", "min", "max", "review"))
for size in ["small", "medium", "large", "aaa"]:
    rows = [g for g in games if g["size"] == size]
    if not rows:
        continue
    q = [float(g["quality_ratio"]) for g in rows]
    r = [float(g["review"]) for g in rows]
    print("  %-7s %5d %7.2f %7.2f %7.2f %7.2f %7.2f"
          % (size, len(rows), st.mean(q), st.median(q), min(q), max(q), st.mean(r)))

print("\nPROFITABILITY (per release: revenue + advance - development cost)")
losses = sum(1 for p in profits if p <= 0)
print("  releases that lost money: %d of %d (%.1f%%)" % (losses, len(profits), 100 * losses / len(profits)))
print("  median profit %s   mean %s   max %s"
      % (f"${st.median(profits):,.0f}", f"${st.mean(profits):,.0f}", f"${max(profits):,.0f}"))
devcost = [int(g["dev_cost"]) for g in games]
rev = [int(g["revenue"]) + int(g["advance"]) for g in games]
print("  median revenue/total-cost ratio: %.1fx" % st.median([r / max(c, 1) for r, c in zip(rev, devcost)]))
if "labour_cost" in games[0]:
    labour = [int(g["labour_cost"]) for g in games]
    share = [l / max(c, 1) for l, c in zip(labour, devcost)]
    print("  wages as a share of a game's cost: median %.0f%%  mean %.0f%%"
          % (100 * st.median(share), 100 * st.mean(share)))
    staffed = [g for g in games if int(g["labour_cost"]) > 0]
    if staffed:
        lost = sum(1 for g in staffed if int(g["profit"]) <= 0)
        print("  of the %d releases built by paid staff, %d lost money (%.1f%%)"
              % (len(staffed), lost, 100 * lost / len(staffed)))

if "concurrent" in games[0]:
    print("\nMARKET SATURATION")
    conc = [int(g["concurrent"]) for g in games]
    print("  the studio's own games on sale at launch: median %.0f  mean %.2f  max %d"
          % (st.median(conc), st.mean(conc), max(conc)))
    # Read the live constants rather than copying them here, so this report
    # cannot quietly describe a tuning the game no longer uses.
    sales_gd = os.path.join(os.path.dirname(__file__), "..", "..", "simulation", "SalesSimulator.gd")
    rate, floor = 0.13, 0.50
    try:
        source = open(sales_gd, encoding="utf-8").read()
        rate = float(re.search(r"CATALOGUE_CROWDING := ([0-9.]+)", source).group(1))
        floor = float(re.search(r"MIN_CATALOGUE_FACTOR := ([0-9.]+)", source).group(1))
    except (OSError, AttributeError, ValueError):
        print("  (could not read crowding constants; showing defaults)")
    print("  crowding: -%.0f%% per concurrent release, floored at %.0f%%"
          % (100 * rate, 100 * floor))
    print("  %-8s %6s %14s %11s" % ("slate", "n", "median units", "crowding"))
    for size in sorted(set(conc)):
        rows = [g for g in games if int(g["concurrent"]) == size]
        factor = max(1.0 - rate * (size - 1), floor)
        print("  %-8d %6d %14s %10.0f%%"
              % (size, len(rows),
                 f"{st.median([int(g['units']) for g in rows]):,.0f}", 100 * factor))
    demand = [float(g["genre_demand"]) for g in games]
    print("  genre demand at launch (1.0 = untouched): median %.2f  min %.2f"
          % (st.median(demand), min(demand)))
    print("  launched into a genre the studio had already crowded: %.0f%%"
          % (100 * sum(1 for d in demand if d < 0.75) / len(demand)))

def inflation_for(year):
    """The same curve the game uses, read from the same file.

    Nominal cash is close to meaningless over a 65-year timeline: costs inflate
    5.3x by 2050, so a balance that has completely stopped growing still prints
    an ever-larger number. Two balance passes read the nominal column and called
    a flat economy a runaway. Every cash figure below is therefore reported in
    1985 dollars and as runway alongside the nominal one.
    """
    path = os.path.join(os.path.dirname(__file__), "..", "..", "..",
                        "data", "inflation.json")
    try:
        points = [(int(p["year"]), float(p["multiplier"]))
                  for p in json.load(open(path, encoding="utf-8"))]
    except (OSError, ValueError, KeyError):
        return 1.0
    if year <= points[0][0]:
        return points[0][1]
    for (ya, ma), (yb, mb) in zip(points, points[1:]):
        if year <= yb:
            return ma + (mb - ma) * (year - ya) / max(yb - ya, 1)
    (ya, ma), (yb, mb) = points[-2], points[-1]
    return mb + (mb - ma) / max(yb - ya, 1) * (year - yb)


print("\nCASH CURVE (median across seeds)")
by_year = {}
for y in years:
    by_year.setdefault(int(y["year"]), []).append(y)
print("  %5s %14s %14s %9s %6s %8s %7s"
      % ("year", "cash", "in 1985 $", "runway", "staff", "games", "avg rev"))
real_by_year = {}
for year in sorted(by_year):
    rows = by_year[year]
    nominal = st.median([int(r["cash"]) for r in rows])
    overhead = st.median([int(r["payroll_mo"]) + int(r.get("rent_mo", 0)) for r in rows])
    real = nominal / inflation_for(year)
    real_by_year[year] = real
    print("  %5d %14s %14s %9s %6.1f %8.1f %7.2f" % (
        year,
        f"${nominal:,.0f}",
        f"${real:,.0f}",
        ("%.0fy" % (nominal / overhead / 12)) if overhead > 0 else "-",
        st.median([int(r["staff"]) for r in rows]),
        st.median([int(r["released"]) for r in rows]),
        st.median([float(r["avg_review"]) for r in rows])))

finals = [rows for year, rows in sorted(by_year.items())][-1]
cash = [int(r["cash"]) for r in finals]
print("\n  final cash across seeds: min %s  median %s  max %s"
      % (f"${min(cash):,.0f}", f"${st.median(cash):,.0f}", f"${max(cash):,.0f}"))

# Whether the economy is still compounding, which nominal cash cannot show.
span = sorted(real_by_year)
if len(span) >= 12:
    half = span[len(span) // 2]
    growth = (real_by_year[span[-1]] / max(real_by_year[half], 1.0)) ** (
        1.0 / max(span[-1] - half, 1)) - 1.0
    verdict = ("FLAT -- income and costs have met" if abs(growth) < 0.015
               else "STILL COMPOUNDING -- this is a runaway" if growth > 0
               else "SHRINKING -- the late game is a treadmill")
    print("  real growth %d-%d: %+.1f%%/yr  %s"
          % (half, span[-1], 100 * growth, verdict))
