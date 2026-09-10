# PA.16 visual asset audit

Audited: 2026-09-09  
Target: portrait mobile, 430 × 932 reference viewport  
Scope: repository state before PA.16 implementation

## Executive finding

Indie Empire already has a strong foundation, not a blank prototype. The logo,
app icon, splash, five painted isometric offices, twelve animated employee
sheets, modular close-up portraits, procedural covers and warm teal/cream/orange
UI are worth preserving. The office paintings in particular are production-
quality and already establish a recognizable cozy technology-studio world.

The visual weakness is fragmented coverage. The strongest art appears in the
Studio and branding while management screens fall back to text, repeated generic
icons or generated letter badges. The current year does not choose an era set;
14 of 20 platforms have no authored illustration; 7 of 15 genres and all 55
themes lack authored icons; all 64 technologies and 31 features are text-only;
awards have no trophy/category family; empty states are text panels; and company
identity has no emblem. These are the PA.16 priorities.

## Inventory summary

| Category | Existing source assets | Runtime footprint | Assessment |
| --- | ---: | ---: | --- |
| Branding | 3 PNG | 5.7 MB source | Production-ready; visually distinctive |
| Offices | 52 SVG + 59 PNG | 19.1 MB source | Core paintings production-ready; era coverage missing |
| Employees | 12 PNG sheets | 9.0 MB source | Strong small-scale sprites; clothing is era-neutral |
| Equipment | 3 PNG | 0.18 MB source | Functional workstation variants; limited era language |
| UI/identity vectors | 54 SVG | 18 KB source | Coherent but incomplete and occasionally over-reused |
| Audio | 21 WAV | 8.5 MB source | Outside PA.16 except presentation coordination |

Godot `.import` sidecars are excluded from counts. Runtime import compression,
not raw source size, determines shipped memory.

## Branding and main menu

| Existing assets | Quality/state | Used by | Missing variants / required sizes | Priority | Implementation notes |
| --- | --- | --- | --- | --- | --- |
| `branding/app_icon.png` 1024², `logo.png` 1860×845, `splash.png` 853×1844 | Production-ready, warm illustrated retro-tech identity | Project icon, boot splash, menu branding | Lightweight menu environment/montage; company emblem family; compact horizontal/mark-only logo | P1 | Preserve the current golden monitor/skyline language. Do not redraw the logo. Use the app-icon desk motif as the source language for secondary illustrations. |

The main menu uses the brand assets but does not yet present a living studio or
historical montage. The gap is supporting world art, not the logo itself.

## Office environments

| Existing assets | Quality/state | Used by | Missing variants / required sizes | Priority | Implementation notes |
| --- | --- | --- | --- | --- | --- |
| Five 768×512 painted rooms: Bedroom, Shared Workspace, Small Office, Professional Studio, Large Studio | Production-ready; each tier changes composition and function rather than only desk count | Studio floor, Office screen | `studio_building` and `campus` currently reuse Large Studio; current-year era variants absent | P0 | Keep `OfficeFloorView` and `OfficeArtwork`. Add modular era overlays selected from `TimeManager.current_year`, not five complete repaints per tier. |
| Five foreground and five atmosphere PNG layers | Production-ready layering; restrained ambience | Studio z-order and atmosphere | Era-specific props/signage; explicit reduced-motion treatment already handled by renderer | P1 | Keep layers at 768×512. Prefer transparent overlays below 512² equivalent. |
| Four customization packs, each with 10 SVG components plus painted PNG slices | Mixed: painted slices match the room; SVG sources are clean customization infrastructure | Office remodel system | Era compatibility metadata; style/era interaction rules | P2 | Do not duplicate these into era folders. Era props should compose beneath player-selected style overrides. |
| Three workstation equipment PNGs | Functional, small and efficient | Desk equipment | 1980s/1990s/2000s/2010s/2020s silhouettes | P1 | Use a small modular set: monitor/computer/phone/media overlays rather than unique workstation art for every office. |

Required office-era bands: 1985–1989, 1990–1999, 2000–2009,
2010–2019 and 2020+. The base paintings already read as late-1980s/1990s,
especially their CRTs. Later eras are the largest visual gap.

## Employee office characters

| Existing assets | Quality/state | Used by | Missing variants / required sizes | Priority | Implementation notes |
| --- | --- | --- | --- | --- | --- |
| Twelve 1024² sprite sheets with 4×5 state grids | Production-ready at office scale; diverse skin, hair and clothing silhouettes | Walking, working, talking, celebrating, stressed/idle state presentation | Research, engine, training and tired iconography can be clearer; era clothing not explicit | P1 | Preserve sheets and deterministic assignment. Existing states already cover more than filenames imply. Add small simulation-driven badges instead of new AI or continuous pathfinding. |
| Deterministic `OfficeCharacterArt` frame mapping | Production-ready architecture | `OfficeFloorView`, previews | Manifest integration and fallback declaration | P1 | Move asset lookup behind the manifest without changing identity seeds. |

No evidence supports replacing these sprites. Their warm outlined style matches
the offices and remains readable at mobile scale.

## Employee portraits

| Existing assets | Quality/state | Used by | Missing variants / required sizes | Priority | Implementation notes |
| --- | --- | --- | --- | --- | --- |
| Code-drawn modular faces, hair, skin, glasses, clothing and facial hair | Production-capable vector-like runtime art; stable identity with low memory cost | Staff, hiring, employee detail, training and related cards | Explicit tired/excited/concerned expressions; nomination/winner adornment; stronger exceptional/star candidate framing | P1 | Extend expression overlays and framing, not the identity generator. Never tie roles to appearance stereotypes. Target 74 px cards and 104 px detail. |

Neutral, happy and stressed/low-morale expressions exist. Tired and excited are
not distinct enough to satisfy the requested expression list.

## Platforms and platform branding

| Existing assets | Quality/state | Used by | Missing variants / required sizes | Priority | Implementation notes |
| --- | --- | --- | --- | --- | --- |
| Six illustrated SVG silhouettes: MicroStar 64, IBM Compatible, Famiclone, Pocket Play, Mega16, PlayBox32 | Coherent, original, mobile-readable, production-ready | Project selectors, Market, covers | 14 of 20 platform records; family/manufacturer marks; fallback hardware silhouette | P0 | Extend the same 96×72-style illustration language. Avoid real-console silhouettes. Provide thumb and detail use from one SVG. |

Platform IDs requiring authored coverage are validated from `platforms.json`,
not guessed from display names. A generic category fallback is required even
after complete current catalog coverage.

## Genre, theme and topic identity

| Existing assets | Quality/state | Used by | Missing variants / required sizes | Priority | Implementation notes |
| --- | --- | --- | --- | --- | --- |
| Eight genre SVGs: action, adventure, RPG, strategy, simulation, puzzle, racing, shooter | Consistent outline/fill family; good at 24–40 px | Market, project creation, covers | 7 of 15 genre IDs | P0 | Complete the family at a 64×64 viewBox, 5 px rounded teal stroke, one orange/sky accent. |
| Runtime letter/color badges for 55 themes | Programmer-art fallback; readable but not memorable | Project selectors and procedural covers | All 55 topic motifs plus generic fallback | P0 | Create one coherent compact motif family. No full illustration per topic is needed. Use 64×64 SVG badges and keep text labels. |

Genre and theme art has high leverage because it feeds project creation,
Market, covers, history, franchises and awards.

## Technologies, features and engines

| Existing assets | Quality/state | Used by | Missing variants / required sizes | Priority | Implementation notes |
| --- | --- | --- | --- | --- | --- |
| Generic research/attribute icons and text cards | Programmer-art/incomplete | Research and Engine Lab | 64 technology icons, branch headers and four state marks | P0 | Use a manifest-backed icon family with branch accent and silhouette. Shared motifs may cover related levels while IDs remain explicit. |
| Text-only feature selection | Missing visual layer | New Project, Greenlight details | 31 feature icons and generic fallback | P0 | Match technology stroke/corner grammar; use subtle category frame, not unrelated illustration styles. |
| Custom-engine text identity | Functional prototype | Engine Lab and project details | Persistent emblem, generation/version badge, supported-tech strip | P1 | Generate emblem deterministically from engine ID/name locally. No editor is needed. |

## Procedural game covers and franchises

| Existing assets | Quality/state | Used by | Missing variants / required sizes | Priority | Implementation notes |
| --- | --- | --- | --- | --- | --- |
| `GameCoverArt`: local procedural background, genre symbol, title, theme badge and platform mark | Strong architecture, visually still template-like; production candidate | New Project preview, release, Games and Game Detail | Covers absent from franchise lists/details, Statistics timeline and Awards; richer era frames/motifs; long-title hierarchy | P0 | Preserve offline procedural generation. Add five era packaging frames and deterministic franchise palette/emblem reuse. |
| Franchise state and screens | Text-first | Franchise list/detail and sequel flow | Persistent series emblem and cover strip | P1 | Derive from stable series ID/original cover; sequels vary layout while retaining palette and motif. |

No runtime generative AI is appropriate. Authored SVG motifs plus deterministic
composition meet offline and mobile-performance requirements.

## Awards and milestones

| Existing assets | Quality/state | Used by | Missing variants / required sizes | Priority | Implementation notes |
| --- | --- | --- | --- | --- | --- |
| Generic success/star icons and styled ceremony cards | Functional programmer art | Ceremony and Statistics | Trophy family, 10 category marks, nomination/winner badges, ceremony backdrop, GOTY treatment | P0 | Use lightweight SVG/canvas art and one restrained burst animation. GOTY needs a taller trophy silhouette, not merely a different color. |
| Event/toast feedback | Consistent UI but generic | Milestones and notifications | Reusable milestone crest/banner system | P2 | One frame plus event-specific icon is sufficient; avoid one bespoke texture per milestone. |

## Company identity

| Existing assets | Quality/state | Used by | Missing variants / required sizes | Priority | Implementation notes |
| --- | --- | --- | --- | --- | --- |
| Company/founder names only | Missing | Studio HUD, Company, Awards, Statistics, release | Deterministic emblem, initials treatment and two-color palette | P1 | Derive from company name hash. Render locally with primitives/SVG motifs; no logo editor or save migration required if deterministic. |

## UI and status iconography

| Existing assets | Quality/state | Used by | Missing variants / required sizes | Priority | Implementation notes |
| --- | --- | --- | --- | --- | --- |
| 28 compact UI SVGs plus 14 remodel icons/controls | Consistent rounded teal linework; production-ready where semantically matched | Navigation, cards, office and employees | Revenue, expenses, profit, research, technology, bugs, reviews, awards, franchise, engine, platform, training, risk, deadline | P0 | Stop aliasing unrelated icons such as research→attributes and sales→games. Complete a 24×24 semantic family. |
| Green/amber/red panel styles with generic icons | Partially production-ready | Success, warning and crisis states | Distinct check/info/research/critical silhouettes | P1 | Preserve semantic colors across eras; combine icon, label and color. |

## Empty states and screen-specific presentation

| Screen/category | Existing state | Gap | Required art size | Priority |
| --- | --- | --- | --- | --- |
| No Games, Employees, Franchises, Awards, Research, Engines, Sales, News | Helpful text panels | No illustration and repeated generic icon | 128×96 or smaller SVG illustration | P1 |
| Game Over | Deliberate text summary | No “studio history closes” visual; franchise omitted | 240×150 illustration/scene treatment | P1 |
| New Company | Form plus founder customization | Bedroom preview/emblem not integrated as a story beat | Existing office crop + 72 px emblem | P1 |
| Main Menu | Strong logo/splash language | No living world layer | 430×932 portrait background or composed existing art | P1 |
| Financial Crisis | Semantic cards | No distinct level symbols/pulse language | 32 px icons; canvas pulse | P1 |
| Statistics | Mobile scrapbook structure | Covers absent from timeline; generic record icons | 54×72 cover thumbs | P1 |

## Animation and motion

Existing office walking, work bubbles, reactions, portrait idle motion, release
reveal and reduced-motion handling are production-capable. Missing animation is
presentation-specific: trophy reveal, promotion/excited portrait beat, research
completion state and subtle financial warning pulse. Budget normal transitions
at 150–250 ms and major reveals at 300–700 ms. Every animation requires an
instant reduced-motion state.

## Typography, color and layout

`VisualTheme` has a coherent warm paper/teal system, semantic green/orange/red,
screen/section/card hierarchy and touch-scaled controls. This is production-
ready foundation. Gaps are documentation, occasional icon reuse, and visual
density on text-heavy Research/Engine/Awards surfaces. Era accents must remain
decorative; semantic colors and text contrast cannot drift by decade.

## Mobile asset budgets

| Asset type | Source target | Runtime/import rule |
| --- | --- | --- |
| UI/status/content icon | SVG, 24 or 64 viewBox | Lossless vector import; no mipmaps |
| Topic/genre/platform mark | SVG, 64–128 viewBox | One source serves thumb/detail; strong silhouette |
| Empty-state illustration | SVG ≤ 256 viewBox | No filters or embedded raster |
| Office base/layer | PNG ≤ 1024×1024, current 768×512 preferred | Compressed where visually safe; avoid 4K sources |
| Character sheet | PNG ≤ 1024² | Consistent filter; existing 12-sheet pool retained |
| Procedural cover component | SVG/Canvas, ≤ 256 | Compose at draw time; do not cache every career cover texture |
| Large portrait background | PNG ≤ 1024×2048 only when necessary | Load on owning screen; do not preload catalog-wide |

## Implementation order

1. Asset manifest, fallback contract and `AssetValidationTest`.
2. Complete shared UI/status icon family.
3. Complete genres/platforms and add topic/technology/feature motif systems.
4. Era resolver and modular office-era overlays.
5. Cover/franchise identity integration across all requested screens.
6. Awards/trophy and company-emblem systems.
7. Illustrated empty states and screen-specific presentation.
8. Deterministic screenshot fixtures and physical visual acceptance.

## Acceptance classification at audit time

- Production-ready: brand core, five primary office paintings, employee sprite
  sheets, office renderer architecture, procedural-cover architecture, base UI
  palette and typography.
- Temporary/programmer art: theme letter badges, generic research/feature cards,
  aliased semantic icons, text-only engine/franchise/award identity.
- Missing: era selection/overlays, most content art, award family, company
  emblem, illustrated empty states, complete screenshot fixture matrix.
- Implemented but not validated: current visual system on physical iPhone,
  including memory, heat, battery, safe-area composition and long-session visual
  fatigue.
