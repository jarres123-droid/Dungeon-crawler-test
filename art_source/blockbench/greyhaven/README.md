# Greyhaven Blockbench building kit

The editable `.bbmodel` files in `buildings/` are the source of truth for this kit. They use the repository template's **Blockbench 5.0 generic-model structure**. Never overwrite `art_source/blockbench/templates/greyhaven_asset_template.bbmodel`.

## Construction grid

- **16 Blockbench units = 1 metre = 1 Godot unit** after export at `0.0625` scale.
- Wall origin is centered on X, at finished ground level, with the wall centered on Z.
- Every wall is exactly **4.00 m wide, 3.00 m tall, and 0.25 m structural thickness**. Projecting trim extends beyond the structural envelope intentionally.
- The stone foundation is **0.45 m** tall. Primary timbers are **0.25 m** (corner posts) with smaller braces and joinery.
- Door clear opening is **1.10 m × 2.20 m**. The window opening is **1.25 m × 1.35 m**.

## Roof alignment

Roof assets use the same building-center ground origin as walls. The ridge center is `(0, 4.75 m, 0)`, while a slope runs to the eave at `(0, 3.00 m, -2.50 m)`. This gives a **34.99° pitch** (`rise 1.75 m / run 2.50 m`) and **0.50 m overhang** beyond a 4 m-deep building. Mirror the slope across Z for the opposite roof face. Ridge and slope pieces are both 4 m wide, with deliberate fascia/shingle overhang beyond their snapping envelope.

## Shared material library

All models reference the six reusable 64 px textures in `textures/`: aged timber, warm plaster, weathered stone, oxblood roof shingles, dark iron, and muted leaded glass. Their restrained variation is designed to read from an isometric camera without becoming noisy. Keep texture paths relative and add new shared materials here rather than baking one-off resources into modules.

## Batch workflow

1. Run `python3 tools/blockbench/generate_greyhaven_batch_01.py` to reproducibly rebuild batch 01.
2. Open each source in the same/current Blockbench release used to create the template and inspect silhouettes, UVs, and joins.
3. Run `python3 tools/blockbench/validate_greyhaven_bbmodels.py` before committing.
4. Export for Godot with a `0.0625` scale so one Godot unit equals one metre.

The generator is deterministic: stable names produce stable UUIDs, while every element and texture within a file remains unique.
