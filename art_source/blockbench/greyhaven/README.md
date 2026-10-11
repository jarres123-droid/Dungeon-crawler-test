# Greyhaven Blockbench building kit

The editable `.bbmodel` files in `buildings/` are the source of truth for this kit. They use the repository template's **Blockbench 5.0 generic-model structure**. Never overwrite `art_source/blockbench/templates/greyhaven_asset_template.bbmodel`.

## Construction grid

- **16 Blockbench units = 1 metre = 1 Godot unit** after export at `0.0625` scale.
- Wall origin is centered on X, at finished ground level, with the wall centered on Z.
- Every wall is exactly **4.00 m wide, 3.00 m tall, and 0.25 m structural thickness**. Projecting trim extends beyond the structural envelope intentionally.
- The stone foundation is **0.45 m** tall and 0.275 m thick at its continuous mortar core; dressed faces project to 0.394 m. Primary timbers are **0.25–0.35 m deep**, with smaller braces and joinery.
- Door clear opening is **1.10 m × 2.20 m**. The window opening is **1.25 m × 1.35 m**.

## Roof alignment

Roof assets use the same building-center ground origin as walls. The ridge center is `(0, 4.75 m, 0)`, while a slope runs to the eave at `(0, 3.00 m, -2.50 m)`. This gives a **34.99° pitch** (`rise 1.75 m / run 2.50 m`) and **0.50 m overhang** beyond a 4 m-deep building. Mirror the slope across Z for the opposite roof face. Ridge and slope pieces are both 4 m wide, with deliberate fascia/shingle overhang beyond their snapping envelope.

The structural roof deck is 0.20 m thick. Shingle courses overlap down-slope and project to a maximum 4.25 m authored width; fascia spans 4.25 m and the metal drip edge 4.31 m. The ridge uses paired pitched clay caps over a closed timber under-roll, centered at the same `(0, 4.75 m, 0)` datum. Snap wall and roof modules on a **4 m X/Z grid**; mirror slopes only across Z. Never offset a module merely to hide a surface conflict.

## Depth hierarchy (Standard v1.0)

Visible layers use deliberate, readable separation: the plaster shell ends at **Z ±0.125 m**; primary timber generally reaches **±0.16–0.175 m**; stone dressings and sills reach **±0.20–0.23 m**; and exterior metal hardware sits beyond its supporting face. Window glass is recessed behind the exterior frame. Continuous cores close the building envelope, while segmented stones, shingles, and trim are the finish layer. Intersections are allowed only where construction members physically join; finish faces must not be duplicated or placed nearly coplanar. New modules must reuse these planes rather than inventing epsilon offsets.

## Shared material library

All models reference six reusable **128 px** textures in `textures/`: aged timber, warm plaster, weathered stone, oxblood roof shingles, dark iron, and muted leaded glass. Broad tonal drift is combined with restrained material-specific grain, stains, mortar, and wear so surfaces remain calm at an isometric camera distance. The source PNG is both relative-linked and embedded for portable Texture-mode viewing. Keep the 128 px shared-library scale (roughly 32 px/m on major surfaces), keep UV density visually consistent, and add shared materials here rather than baking one-off resources into modules.

## Pivot and naming rules

Wall pivots remain at building-grid origin `(0, 0, 0)`: centered in X and Z at finished ground. Roof pieces retain the same building origin rather than localizing their pivot at the ridge, allowing walls, mirrored slopes, and ridge to be assembled numerically without hand correction. Names describe construction function; deterministic UUIDs derive from asset and element names. These five files define **Greyhaven Building Kit Standard v1.0**.

## Batch workflow

1. Run `python3 tools/blockbench/generate_greyhaven_batch_01.py` to reproducibly rebuild batch 01.
2. Open each source in the same/current Blockbench release used to create the template and inspect silhouettes, UVs, and joins.
3. Run `python3 tools/blockbench/validate_greyhaven_bbmodels.py` before committing.
4. Export for Godot with a `0.0625` scale so one Godot unit equals one metre.

The generator is deterministic: stable names produce stable UUIDs, while every element and texture within a file remains unique.
