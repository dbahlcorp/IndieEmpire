# PA.16B visual QA

Status: baseline audit in progress  
Audit date: 2026-09-10  
Reference viewport: 430 x 932 portrait  
Source revision: `dd1c28a` (`Add PA.16 manifest-backed visual identity assets`)

## Review method

This audit is based on:

- the PA.16 manifest and every static source under `assets/`;
- labeled contact sheets rendered at 24, 32, 48, and 64 px, with larger
  family-specific previews where the runtime uses larger art;
- the deterministic 22-screen `PA16VisualSnapshot` fixture at 430 x 932;
- the visual identity guide, PA.16 audit, manifest contract, and visual
  acceptance matrix;
- comparison against the painted office environments, employee sheets,
  branding, palette, and typography that already define the game.

The generated baseline is in `artifacts/pa16b-before/`. A grade is a visual
judgment, not a file-validity result:

- **A — Production quality:** retain.
- **B — Good:** retain unless a small, clearly valuable correction emerges.
- **C — Noticeably weak:** polish or selectively replace.
- **D — Replace:** misleading, repetitive, stylistically incompatible, or
  unusable at its intended mobile size.

## Executive finding

PA.16's architecture is sound, but its main generation script authored only a
small motif library and assigned those motifs to hundreds of unrelated catalog
IDs. The manifest therefore has coverage without adequate art direction. This
is the dominant systemic problem and should be corrected at the family-system
level while preserving IDs, `AssetCatalog`, fallbacks, and save compatibility.

The repository is not uniformly weak. The logo, app icon, splash, painted
offices, employee sprite sheets, procedural portraits, original eight genre
icons, original six platform illustrations, and established functional UI
icons are the quality anchors. They should not be redrawn to create activity.

## Family scorecard

| Family | Assets reviewed | Readability | Distinctiveness | Semantic clarity | Style consistency | Craft | Mobile quality | Personality | Grade | Direction |
| --- | ---: | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Branding | 3 | A | A | A | A | A | A | A | **A** | Retain logo, icon, and splash unchanged. |
| Painted offices and layers | 5 bases plus layers | A | A | A | A | A | A | A | **A** | Preserve as the environmental anchor. |
| Employee sprite sheets | 12 | A | A | A | A | A | A | A | **A** | Retain; later inspect individual animation frames in motion. |
| Employee portraits | procedural | A | A | A | A | B | A | A | **A/B** | Retain identity system; verify expression separation. |
| Legacy functional UI icons | 28 plus remodel controls | A | B | A | A | B | A | B | **B** | Mostly retain. Verify contrast on both light and dark surfaces. |
| Genres | 15 | A | C | C | B | C | A | C | **C** | Retain the original eight; replace the seven generated additions. |
| Themes | 55 | B | D | D | C | D | B | D | **D** | Replace the generic motif assignment with strong topic symbols. |
| Technologies | 64 | B | D | D | C | D | B | D | **D** | Build recognizable branch families and progression. |
| Game features | 31 | B | D | D | C | D | B | D | **D** | Replace engineering abstractions with player-facing objects/experiences. |
| Platforms | 20 | A | C | C | C | C | A | C | **C** | Retain six originals; redraw fourteen generated devices as an era progression. |
| Awards | 10 | A | C | B | B | C | A | C | **C** | Preserve a coherent material family, but create hierarchy and distinct trophies. |
| Award presentation | 3 | B | C | C | C | C | B | C | **C** | Nominee/winner states need a collectible presentation language. |
| Empty states | 11 | A | D | D | C | D | A | D | **D** | Replace icon-in-card compositions with restrained object scenes. |
| Era overlays | 5 | C | C | B | D | C | C | C | **D** | Current vectors read as stickers over painted rooms; author integrated props. |
| Milestones | 12 | A | D | D | C | D | A | D | **D** | Create celebratory object/badge hierarchy with event-specific silhouettes. |
| Status icons | 12 | A | D | D | C | D | A | D | **D** | Replace incorrect motifs with minimal semantic marks and remove frames. |
| Manifest UI identity icons | 37 | B | D | C | C | D | B | D | **D** | Many repeat catalog motifs; retain stronger legacy functional icons instead. |
| Company identity | procedural | A | B | B | B | B | A | B | **B** | Retain architecture; audit emblem grammar and shield repetition. |
| Engine identity | procedural | B | C | C | B | B | B | C | **C** | Separate technical grammar from company emblems and improve version progression. |
| Procedural game covers | procedural | B | C | C | B | C | B | C | **C** | Architecture is sound; composition currently reads as a UI card. Audit 100 samples. |

## Protected work

The following assets/systems are currently graded A or high B and are protected
from broad replacement:

- `assets/branding/app_icon.png`, `logo.png`, and `splash.png`;
- the five painted office bases, their painted foreground layers, and their
  atmospheric layers;
- all twelve employee sprite sheets, pending frame-by-frame motion review;
- the deterministic employee portrait identity system;
- original genre icons: `action`, `adventure`, `rpg`, `strategy`,
  `simulation`, `puzzle`, `racing`, and `shooter`;
- original platform illustrations: `microstar_64`, `ibm_compatible`,
  `famiclone`, `pocket_play`, `mega16`, and `playbox32`;
- established navigation/status/employee/office icons under
  `assets/ui/icons/` where contrast and small-size checks pass.

## Confirmed replace list

### Generated genre additions — D

`battle_royale`, `fighting`, `horror`, `immersive_vr`, `mmo`, `neural_sim`,
and `sandbox` use unrelated stock motifs (crossed swords, ball, magnifier,
leaf, car, planet, globe). Several actively miscommunicate their genre.

### Generated platform additions — D

`continuum`, `dreamcube`, `ember`, `helix_vr`, `home_pc`, `lattice`,
`nexus_hd`, `optix_cd`, `palmscreen`, `playbox64`, `pocket_dual`,
`pocket_vue`, `vector_one`, and `vessel` cycle through six generic device
templates. They do not create a plausible hardware chronology; unrelated
systems are visually identical, and several names/classes receive the wrong
silhouette.

### Themes — D family

The contact sheets expose a many-to-one mapping that prevents recognition:

- `aviation`, `automotive`, `railways`, and `racing_theme` share the same car;
- `detective`, `crime`, `heist`, `mafia`, `horror`, and `zombies` share the
  same magnifying glass;
- `fantasy`, `dragons`, `ghosts`, `magic_academy`, `mythology`, `occult`,
  `samurai`, `vampires`, and `vikings` share the same abstract triangle;
- `farming`, `jungle`, `wildlife`, `dinosaurs`, `arctic`, and `steampunk`
  share a leaf;
- `archaeology`, `ancient_egypt`, `history`, `pirates`, `treasure_hunting`,
  and `western` share a document;
- `city_building`, `business`, `hacking`, and `superheroes` share a skyline;
- `space`, `aliens`, `time_travel`, and `virtual_worlds` share a planet;
- `sports` and `survival` share a ball.

Some individual symbols (`cooking`, `music_rhythm`, `space`) are readable in
isolation, but they are not distinct enough to retain unchanged inside this
family.

### Technologies and features — D families

The same gear, leaf, car, music note, globe, person, node triangle, wand, and
code brackets are repeatedly assigned to unrelated systems. Examples include:

- `ray_tracing` shown as a car;
- `pbr` and `pathfinding` shown as leaves;
- `texture_mapping` shown as a music note;
- `optimization` shown as a person;
- `dialogue_system` shown as a gear;
- `achievements` shown as a speaker;
- `photo_mode`, `multiple_endings`, and `mod_support` shown as code brackets;
- `inventory` shown as a gear;
- `dynamic_weather_gameplay` shown as a leaf.

This is a semantic failure, not a polishing problem. Replacement should use
recognizable branch grammars: graphics/rendering, audio, AI/logic, networking,
physics/motion, tools/editor, animation/rigging, and storage/streaming.

### Status and milestone families — D

Status marks currently reuse catalog art rather than state semantics. `failed`
and `locked` are magnifying glasses; `financial_trouble` is a car; `complete`
is a leaf; `warning` is crossed swords. Milestones similarly use unrelated
leaves, globes, documents, gears, and balls. Both families need simple,
purpose-specific silhouettes, with status icons unframed.

### Empty states — D

Every empty state repeats a large rounded card, one catalog motif, a decorative
plus, and a curved baseline. The illustrations do not depict the promised
unused shelf, empty workstation, trophy space, unfinished blueprint, or blank
release board. At their larger in-game size, the procedural repetition becomes
more obvious rather than more charming.

### Era overlays — D

The five overlays communicate broad device eras, but they are thin vector
clusters placed over painterly environments. In the 430 x 932 office captures,
they read as stickers in the lower-right corner and do not share room
perspective, lighting, material texture, or occlusion. The base paintings remain
strong; only the overlay props should be replaced.

## Systemic problems

1. **One rounded tile applied to identity, utility, status, hardware, and
   celebration.** Family hierarchy is lost because almost every object is
   framed the same way.
2. **Twenty generic motifs standing in for hundreds of concepts.** The
   `motif_for()` keyword mapping provides file coverage but creates false visual
   equivalence.
3. **Semantic mismatches.** Several icons depict an unrelated object, making
   labels mandatory and defeating the icon's purpose.
4. **No visual progression.** Technology levels and platform eras do not evolve
   within recognizable families.
5. **Repeated visual weight and padding.** Utility icons and hero art occupy the
   same square, use the same stroke, and carry the same amount of detail.
6. **Sterile geometry beside painted environments.** Era overlays and empty
   states lack the authored edges, material cues, perspective, and restrained
   irregularity of the offices.
7. **Cream-on-cream contrast risk.** Several established navigation icons are
   nearly invisible on the light contact-sheet ground, so each retained icon
   needs confirmation in its actual dark runtime container and a dark/light
   swatch check.
8. **Procedural cover composition is too card-like.** The real-screen fixture
   shows a readable cover, but it resembles a framed UI component more than a
   fictional piece of commercial cover art.

## In-game findings at 430 x 932

- The five office tiers remain coherent and attractive. Employee scale and room
  composition survive portrait rendering.
- Era overlay props are visibly detached from the room paintings and repeat a
  lower-right placement language.
- Research exposes the repeated technology motifs immediately; adjacent rows
  lack progression and conceptual distinction.
- Market benefits from the six original platform illustrations, making the
  generated platform clones especially conspicuous lower in the catalog.
- Awards are readable but not prestigious: the ceremony illustration and GOTY
  trophy use the same small icon-library treatment as ordinary controls.
- Game covers remain readable at list size, but the template lacks the visual
  specificity of a fictional release.
- Employee portraits and office sprites remain charming and should not be
  replaced during this pass.
- Several fixture screens contain large empty cream fields. Empty-state artwork
  must add specific, restrained scenes rather than larger generic badges.

## Production order

1. Replace status icons and the seven generated genres to establish clean
   utility and identity grammars.
2. Redesign platform silhouettes as a five-era progression while retaining the
   six original illustrations.
3. Redesign awards and empty states as collectible/illustrative hero families.
4. Replace the most common, player-visible theme symbols first, then complete
   the family only where the audit still grades C/D.
5. Establish technology branch grammars and feature object grammar; prioritize
   items visible in the first-hour Research, Engine Lab, and Greenlight flows.
6. Replace vector era stickers with integrated raster props; use Aseprite source
   only where it materially improves the room integration.
7. Generate and audit 100 deterministic covers before changing the cover
   component system.
8. Re-run contact sheets, the 22-screen fixture, mobile tests, asset validation,
   and the regression suite. Physical-device review remains a human gate.

## Review status legend

| State | Meaning |
| --- | --- |
| Automatically valid | File/manifest/test validation only. |
| Visually reviewed | Inspected on contact sheets and in deterministic screens. |
| Physical-device reviewed | Confirmed by a human on a representative phone. |

Current state: static families and 22 deterministic screens are **visually
reviewed**. No asset is yet marked **physical-device reviewed**.

## Implemented selective pass 1

### Genres

The seven D-grade generated additions were redrawn as distinct identity marks:

- `battle_royale`: parachute and closing play-space arc;
- `fighting`: single boxing-glove silhouette;
- `horror`: jagged ghost silhouette;
- `immersive_vr`: headset and lenses;
- `mmo`: connected players around a world;
- `neural_sim`: split brain with neural paths;
- `sandbox`: sandcastle and shovel.

The original eight A/B icons were retained. All fifteen now remain readable at
24, 32, 48, and 64 px. Family grade after this pass: **B**.

### Status icons

All twelve D-grade generated status marks were replaced with unframed semantic
symbols: play, check, octagonal alert, cross, declining chart, cracked coin,
padlock, low battery, pause, queue dots, rising trend, and warning triangle.
Colored silhouettes with cream internal marks survive both light and dark
grounds at 24 px. Family grade after this pass: **A/B**.

### Verification

- Before contact sheets retained in `artifacts/pa16b-before/`.
- After contact sheets written to `artifacts/pa16b-after/`.
- SVG structural audit: 19 of 19 changed assets passed with no findings.
- `AssetValidationTest`: passed, 1,528 checks.
- `MobileLayoutTest`: passed, 184 checks.
- Physical-device review: not performed; human gate remains open.

## Implemented selective pass 2

### Platforms

The fourteen generated platform placeholders were redrawn as distinct hardware
silhouettes while preserving the six original illustrations. The family now
progresses from optical-disc and cube consoles through tower PCs, dual-screen
handhelds, HD slabs, phones, hybrid docks, VR hardware, and compact future
systems. Each silhouette remains recognizable at the Market screen's compact
list size. Family grade after this pass: **B**.

### Awards

All ten repeated trophy placeholders were replaced with category-specific
collectibles. Game of the Year has the strongest star-and-plinth silhouette;
narrative, technology, visuals, innovation, indie, action, RPG, strategy, and
simulation use distinct symbolic forms with a consistent gold, teal, coral,
and ink palette. Family grade after this pass: **A/B**.

### Empty states

All eleven generic badge illustrations were replaced with restrained scenes
specific to their screen: an empty trophy shelf, contract inbox, unfinished
engine blueprint, cash drawer and ledger, unopened franchise boxes, empty game
shelf, quiet newsstand, archive drawers, research blueprint, blank sales board,
and empty workstation. Family grade after this pass: **B**.

### Generator protection

`scripts/tools/generate_pa16_visual_assets.py` now treats every reviewed genre,
status, platform, award, and empty-state SVG as an approved existing source.
Re-running the PA.16 coverage generator therefore cannot silently replace this
hand-authored work with generic motifs.

### Verification

- Updated contact sheets inspected at family-specific display sizes and on both
  light and dark grounds.
- Updated 22-screen fixture inspected at 430 x 932 after forcing a Godot import;
  Market and Awards display the new art in context.
- SVG structural audit: 54 of 54 changed assets passed with no findings.
- Python syntax compilation: contact-sheet and asset-generation tools passed.
- `AssetValidationTest`: passed, 1,528 checks.
- `MobileLayoutTest`: passed, 184 checks.
- `OfficeFloorTest`: passed, 264 checks.
- `ReleasePresentationTest`: passed, 64 checks.
- Physical-device review: not performed; human gate remains open.

## Implemented selective pass 3

### Milestones

All twelve repeated milestone placeholders were replaced with collectible,
achievement-specific marks: a first cartridge, ascending sales bars, crowned
coin stacks, employee badge, first office, separate eight- and nine-review
marks, first trophy, GOTY star, linked franchise boxes, custom engine gear, and
the first ten-person team. The family is readable from 32 through 96 px and on
the dark runtime ground. Family grade after this pass: **A/B**.

The asset generator now preserves these reviewed sources. All twelve passed the
SVG structural audit, Python syntax compilation passed after the generator
change, Godot imported the assets successfully, and `AssetValidationTest`
passed again with 1,528 checks. This brings the selective redraw total to 66
SVGs. Physical-device review remains open.

## Implemented final pass

### Themes, technologies and features

All 55 themes now use topic-specific silhouettes rather than keyword-assigned
stock motifs. All 64 technologies use nine coherent branch grammars—graphics,
tools, audio, architecture, AI, networking, physics, animation and
streaming/world—with shared category marks and visible progression. All 31 game
features now depict concrete player-facing objects or experiences and no longer
share the technology grammar. Final grades: themes **B+**, technologies **B**,
features **B+**.

### Era props and procedural covers

Five era overlays now distribute period hardware across three room anchors with
short contact shadows, subdued material colors and runtime occlusion under
furniture/people. The painted rooms remain untouched. Final grade: **B**.

A deterministic 100-cover before/after audit confirmed that the old system
repeated one centered-icon card. The final runtime system adds seven genre-aware
composition archetypes, decade language, measured title fitting and stable
franchise palette/composition. Final grade: **B**.

### Final verification and stop condition

- 155/155 final-family SVGs passed structural audit;
- the PA.16 coverage generator changed 0/155 reviewed assets on a protection rerun;
- nine final contact sheets were reviewed at intended mobile sizes;
- 100 before and 100 after covers were captured and reviewed;
- 22/22 current application screens plus 13 bottom-of-scroll views rendered at
  430 × 932 with the real runtime theme and zero capture errors;
- 72/72 root regression suites passed with 13,522 checks;
- connected acceptance Phases A–D passed 56, 40, 14 and 68 checks;
- physical-device review remains open.

All target families are B or better and the high-frequency fixture has no obvious
C/D art. The PA.16B stop condition is met: **stop producing assets and enter the
Alpha RC1 device gate.** See `docs/PA16B_FINAL_REPORT.md` and
`docs/ALPHA_RC1_DEVICE_TEST.md`.
