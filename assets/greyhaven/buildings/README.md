# Greyhaven modular building kit

This kit separates **placement** (`village.gd`) from **construction**
(`greyhaven_building.gd`) and archetype selection (`archetypes/*.tscn`). It is intended
for reuse by later villages without copying Greyhaven's map coordinates.

## Dimensional standard

| Element | Standard |
| --- | ---: |
| wall thickness | 0.24 m |
| foundation height | 0.48 m |
| roof structural thickness | 0.24 m |
| timber projection/depth | 0.28 m |
| trim thickness | 0.16 m |
| typical eave | 0.66–0.94 m |
| pitch range | 0.49–0.69 radians |

The roof run, rise, slope length, ridge height, fascia and chimney exit are derived
from each definition. Roof halves use mirrored, vertical-cut prism meshes. They share
a coplanar ridge face and cannot cross through one another as rotated boxes can.

## Reusable modules

The builder exposes reusable construction functions for: inset plaster wall cores,
projecting stone foundations/weather courses, corner posts, sills, top plates, rails,
facade studs, diagonal braces, roof slopes, ridge caps, fascia, bargeboards, gable king
posts, staggered shingle courses/joints, layered ridge and drip caps, exposed rafter
tails, framed doors, thresholds and hardware, leaded windows, shutters, sills,
chimneys/caps, porch decks/posts/beams/brackets, shop awnings, awning brackets and
hanging signs. Corner footings, timber pegs and opening headers add close-range depth.
Meshes and materials are cached and shared between all instances with identical
dimensions.

## Archetypes

- `small_cottage.tscn`: compact steep moss-slate roof, herb shelf and shuttered opening.
- `medium_residence.tscn`: balanced two-window home with a crowned, balustraded porch.
- `merchant_shop.tscn`: warm roof, deep sales porch, display counter and trade sign.
- `workshop.tscn`: broad low pitch, loading platform, reinforced lintel and smith sign.
- `important_hall.tscn`: tallest roofline, jetty beam, carved corbels and deep porch.

## Validation

Every instance asserts positive rise, deliberate eave projection and a chimney clear
of the roof edge. It publishes `roof_run`, `roof_rise`, `ridge_height`, and
`geometry_validated` metadata for automated/editor diagnostics. Run
`godot --headless --path . --script tools/validate_greyhaven_buildings.gd` to load all
variants and verify the invariant metadata.

## Known simplification

Secondary structural/detail pieces remain low-polygon shared meshes for mobile
performance. Roof shells are purpose-built prism meshes; no roof plane uses a rotated
box, and decorative courses sit above rather than intersect the structural skin. The
kit does not yet provide interiors, dormers, curved tiles, or destructible states.
