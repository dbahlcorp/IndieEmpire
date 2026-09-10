# Indie Empire visual identity guide

Version: PA.16  
Primary target: portrait mobile at 430 × 932 points

## North star

Indie Empire is a warm, hand-built history of small teams making ambitious
games. Its visual identity combines a cozy illustrated studio, the tactile
imperfection of printed game magazines, and the clarity of a modern management
game. Screens should feel authored and optimistic without hiding hard business
information.

Three phrases govern visual decisions: **cozy technology**, **earned history**,
and **readable at a glance**.

## Existing identity to preserve

- The golden monitor, skyline and teal-night language of the logo, app icon and
  splash are the brand anchor.
- The five painted isometric offices are the environmental anchor. New work
  composes with them; it does not repaint or stylistically replace them.
- Cream paper, deep teal ink, sky blue and warm orange remain the core UI family.
- Existing employee sheets and procedural close-up portraits remain the people
  system. New states extend those systems instead of introducing a second cast.

## Shape language

- Primary panels and large illustrations use soft rectangles with 10–16 px
  equivalent corner radii.
- Small marks use circles, shields, cartridges and ticket-like plaques. Avoid
  sharp corporate geometry unless it communicates danger or advanced hardware.
- UI icons use a 64 × 64 authoring grid, 4 px rounded strokes and a minimum
  enclosed gap of 6 px. Their silhouette must survive at 20–24 px.
- Content icons may contain two filled accent regions but no more than three
  semantic parts. Tiny decorative detail is reserved for large empty states.
- Cast shadows are short and offset down-right. Do not use blurred drop shadows
  inside SVG assets; the runtime theme supplies panel depth.

## Edge and rendering rules

- Vectors use round line caps and joins, whole or half-pixel coordinates, and
  no filters, masks, embedded fonts or embedded raster data.
- Illustrations use flat fills plus one darker shade and one highlight. Texture
  comes from restrained dots, lines and small chips rather than noise filters.
- Raster environment art keeps its existing painted edge treatment. Pixel-art
  people retain nearest-neighbour sampling when shown at native sprite scale.
- Transparent padding is intentional: 8 px on 64 px icons, 12 px on 96 px
  identity marks and 16 px on empty-state illustrations.

## Color system

The runtime `VisualTheme` remains authoritative. Asset authors use this subset:

| Role | Hex | Use |
| --- | --- | --- |
| Ink | `#263c40` | outlines, primary pictograms |
| Deep teal | `#254a50` | dark fills, selected states |
| Teal | `#315f65` | structure, neutral identity |
| Sky | `#4f91a2` | secondary fill, information |
| Cream | `#fff7df` | highlights, light inset areas |
| Paper | `#f8e8c8` | cards and illustration fields |
| Orange | `#e98d48` | actions, energy, warm accents |
| Gold | `#f0b34f` | awards, milestones, premium results |
| Green | `#4f956f` | success and healthy progress |
| Red | `#b94e48` | failure, urgent risk, destructive intent |
| Muted ink | `#617174` | secondary detail only |

Semantic color is never the only signal. Success pairs green with a check or
upward motion; warning pairs orange with a triangle or pulse; failure pairs red
with a cross, crack or downward motion.

## Typography and labels

- Runtime text uses the project UI font and theme sizes; SVGs contain no text.
- Screen titles are sentence case. All-caps is reserved for tiny era/category
  chips and game-cover mastheads.
- Minimum body text is 15 points at the reference viewport; secondary labels are
  13 points. Touch controls retain a 44 point minimum hit area.
- Long game and company names wrap before truncating. A two-line cover title is
  preferred to ellipsis. Essential state is never conveyed by a clipped label.

## Icon families

### Navigation and actions

Navigation icons use teal outline, a cream or transparent interior and one sky
or orange focal fill. Similar concepts must remain distinct: research is a
flask/spark, engines are interlocking blocks, finance is a ledger/coin, staff is
two people, milestones are a flag, and awards are a handled cup.

### Genres

Genres use bold object or motion silhouettes on a rounded paper tile. The genre
mark is the darkest element and the orange accent indicates player energy or
conflict. Each genre must read without initials.

### Themes and topics

Themes use reusable motif art grouped by meaning—space, city, wilderness,
history, sport, mystery, fantasy, machinery and social life. A topic may share a
motif with a related topic, but the manifest records that relationship. Runtime
letter badges are fallback only.

### Technologies and features

Technologies use blueprint-like teal structures with sky highlights. Game
features use warmer player-facing objects and orange highlights. Both families
must avoid the same generic gear for unrelated concepts.

### Platforms

Platform art depicts hardware classes, not trademarks. Console, computer,
handheld, optical, online and mobile silhouettes are visually distinct. A 96 ×
72 source must remain legible at 32 × 24 in a compact card.

### Status

Status marks are the most restrained family. They use a single dominant
semantic shape and at most one accent: locked, active, queued, complete,
warning, failed, paused and trending.

## Characters and expression

- Existing employee sprites define body proportion and workplace tone.
- Close-up portraits derive skin, hair, clothing and rig from stable employee
  identity. The same employee must not visually change between screens or saves.
- Supported readable states are neutral, happy, stressed, worried, tired and
  excited. Expression thresholds come from morale, stress and energy; animation
  may emphasize a state but may not invent it.
- Diversity is expressed through the existing range of skin, hair, clothing and
  rig variants. Do not bind appearance to role, ability or personality.

## Office environments and eras

Era presentation is derived from the simulation year and never saved as a
separate cosmetic preference:

| Era | Years | Accent | Signature props |
| --- | --- | --- | --- |
| Homebrew | 1985–1989 | amber + olive | CRT, cassette, paper manuals |
| Multimedia | 1990–1999 | red-orange + blue | cartridges, beige tower, posters, CD cases |
| Online transition | 2000–2009 | violet + cyan | optical media, dev kit, dual/flat displays |
| Mobile era | 2010–2019 | blue + green | thin monitor, router, headset, smartphone |
| Modern indie | 2020 onward | coral + sky | ultrawide, tablet, compact devices, LED accents |

Era overlays are transparent 768 × 512 vectors aligned to the existing office
paintings. They add a small prop cluster and restrained ambient accents, keeping
walkable space and workstation hit regions unobscured. Office tier still changes
the room's composition; era changes technology and atmosphere.

## Game covers and franchise identity

- Covers are deterministic from stable game/franchise identifiers, genre,
  theme, platform and development era.
- A franchise keeps its core emblem and two-color family. Sequels vary framing,
  subtitle treatment and one accent rather than becoming unrelated covers.
- Era changes print treatment: sparse homebrew grid, cartridge-era framing,
  early-3D facets, online-era glow bands, modern-indie editorial blocks.
- Titles may occupy two lines and remain readable at list thumbnail size.
- Covers appear wherever a specific game is the subject: development, release,
  games, game detail, franchises, awards and statistical history.

## Company identity

The company emblem is deterministic from the company name plus the founder's
stable identity. It combines one of several shields/roundels, a studio motif and
a two-color brand pair. The emblem is visible on Company, Studio, release,
awards and statistical-history surfaces, but it never replaces the Indie Empire
product logo.

## Awards, milestones and empty states

- Award trophies share a gold body and deep-teal base. Category is communicated
  by a distinct inset mark: star, quill, mask, graph, people, globe or spark.
- Milestone badges use ribbon/flag geometry and can be earned at 32–48 px.
- Empty states are small editorial illustrations, not decorative full-screen
  paintings. They show an object with potential: blank shelf, unopened box,
  idle desk, empty podium, folded map or unfinished blueprint.
- Empty states include a concise heading and one next action in runtime text.

## Charts and data-heavy screens

- Charts use teal as the base series, sky for comparison, orange for attention,
  green/red only for meaningful positive/negative state, and direct labels where
  space permits.
- Research and engine screens separate dense text with 32–40 px identity marks,
  consistent category bands and generous vertical rhythm.
- Decorative illustrations yield to data: never place art behind small text or
  inside a scrolling table column that needs alignment.

## Motion

- Ordinary feedback runs 150–250 ms; major releases and awards run 300–700 ms.
- Approved motions are short scale-settle, 2–4 px float, glow/pulse for urgent
  status, and existing office walking/work loops.
- Reduced-motion mode resolves immediately to the final frame and retains every
  informational state.
- No illustration requires continuous animation to be understood.

## Density, import and performance budget

- UI and content icons: SVG with a 24, 64, 96 or 128 view box; no filters.
- Empty states: SVG at or below a 256 unit view box.
- Office bases/layers: retain 768 × 512 PNG sources; no new 4K images.
- Character sheets: retain current 1024² maximum and consistent filtering.
- Procedural cover/emblem components: cache by stable key only while their owning
  screen needs them; do not preload the full catalog.
- Every manifest key resolves to an existing asset or an explicit family
  fallback. Missing art must never create a broken-texture rectangle.

## Review checklist

Before accepting an asset, verify it at intended size, 50%, and 200%; test it on
cream and deep-teal backgrounds; check silhouette without color; confirm it does
not duplicate another concept; audit SVG structure; and view it inside the
430 × 932 fixture rather than only as an isolated file.
