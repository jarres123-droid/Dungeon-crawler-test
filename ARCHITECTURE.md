# ARCHITECTURE.md

# Mobile Dungeon Game Architecture

This document records the intended architecture of the Godot 4.x mobile dungeon project.

Because the project began as a rapidly evolving prototype, the current repository may contain multiple generations of scripts. Agents must inspect the checked-out project and update this document as the architecture is consolidated.

---

# 1. Architectural Goals

The codebase should evolve toward:

- Clear subsystem ownership
- Minimal hidden dependencies
- Mobile-first input
- Deterministic procedural generation where useful
- Data-driven tuning
- Reusable dungeon content
- Testable interfaces
- Efficient runtime behavior
- Easy replacement of placeholder art with production assets

---

# 2. Current Historical Structure

Historically, the project has used a root similar to:

```text
Dungeon (Node3D)
├── Player (CharacterBody3D)
├── FollowCamera (Camera3D)
├── DungeonCombat (Node3D)
├── DungeonVisuals / DungeonArt (Node3D)
├── DungeonTextures / visual helpers
├── DungeonArchitecture (Node3D)
└── Runtime-generated dungeon geometry
```

The exact active scene tree in the repository is authoritative.

Do not assume every node above currently exists.

## Active Scene and Scripts (integration audit)

The configured main scene is `res://village.tscn`. The village entrance changes
to `res://dungeon.tscn`; the dungeon is therefore the gameplay scene for the
systems covered by T-010 through T-022, but it is not the application entry
scene.

The editor-authored dungeon tree is:

```text
Dungeon                         dungeonprocedural.gd
├── Player                      playerjoystickdodge.gd
├── followcamera                followcamera.gd
├── DungeonCombat               dungeoncombatdodge.gd
├── dungeonvisuals              dungeonvisualsv2.gd
├── combatpolish                combatpolish.gd
├── dungeonart                  dungeonartv3.gd
├── dungeontextures             dungeon_textures_v1.gd
├── dungeonarchitecture         dungeon_architecture_v1.gd
└── VisualShowcase              visual_showcase.gd
```

The lowercase editor name `followcamera` is intentional current scene data;
the script still identifies the compatibility concept as `FollowCamera` and
resolves the player through `../Player`, not through the camera node name.

Important runtime-created children include `Player/Character Visual`, the
player collision and mobile joystick HUD, `DungeonCombat`'s enemy/sword/combat
HUD, generated rooms/corridors/collisions, minimap and exit triggers, and the
visual/art/texture/architecture batches. Similarly named root-level scripts
not referenced by `dungeon.tscn` are retained prototypes, not active versions.

---

# 3. Initialization Pattern

Several systems have historically depended on procedural content being created before visual or combat helpers initialize.

Patterns used by existing prototypes may include:

```gdscript
call_deferred("_initialize")
```

or waiting one or more process frames before reading generated room data.

This means initialization order is currently part of the integration contract.

## Desired Direction

Over time, replace timing assumptions with explicit lifecycle signals.

Preferred future flow:

```text
DungeonGenerator.generate()
        ↓
dungeon_generated(layout)
        ↓
DungeonBuilder
        ↓
Architecture/Decoration
        ↓
EncounterSpawner
        ↓
Gameplay begins
```

A signal or explicit state transition is preferable to arbitrary frame delays.

Do not migrate this in unrelated feature work.

## Current Dungeon Startup Contract

`Dungeon._ready()` synchronously creates the logical plan and physical dungeon.
The active player creates `Character Visual` in its own `_ready()`. Combat uses
`call_deferred("_initialize_combat")`, so it attaches its sword only after the
player visual exists. Texture and architecture helpers also defer; architecture
then waits two process frames before reading `dungeon_cells` and calling the
root `_are_connected(a, b)` query. These delays remain compatibility behavior
and were not replaced during integration.

The dungeon root exposes `dungeon_cells`, `connections`, `exit_cell`,
`_are_connected(a, b)`, `validate_connectivity()`, and `get_active_seed()`.
`debug_seed == 0` selects a randomized run. A positive debug seed initializes
the generator's private RNG and is printed as the active seed; all logical-plan
shuffling must use that RNG rather than the global random source.

---

# 4. Dungeon Logical Model

Procedural generation should eventually be separated into two layers.

## Logical Layout

Responsible for:

- Room coordinates
- Connections
- Room types
- Seed
- Start room
- Exit/boss room
- Encounter tags
- Reward tags

Example conceptual data:

```gdscript
{
    "seed": 12345,
    "rooms": [...],
    "connections": [...],
    "start_room": ...,
    "exit_room": ...
}
```

## Physical Builder

Responsible for:

- Floors
- Walls
- Door openings
- Corridors
- Collision
- Navigation support
- Spawn anchors

This separation allows the layout to be tested without rendering the entire dungeon.

---

# 5. Dungeon Architecture / Decoration

Architecture is visual enhancement layered onto the dungeon's physical structure.

Historical architecture code has included:

- Arched openings
- Upgraded columns
- Decorative floor elements
- Material variation
- Repeated mesh batching / instancing

## Boundary

Architecture must not:

- Break room connectivity
- Block door openings
- Alter combat rules
- Change player controls
- Add hidden collision without a gameplay reason

Visual pieces should be non-blocking by default unless deliberately designed as gameplay geometry.

---

# 6. Player System

The player is a `CharacterBody3D`.

Historical implementations have included:

- Camera-relative movement
- Mobile analog joystick
- Desktop fallback input
- Directional facing
- Dodge roll
- Runtime-generated placeholder visuals

A compatibility node named `Character Visual` has historically been used so other systems can attach or replace the player's visual representation.

## Desired Separation

Long-term structure:

```text
Player
├── PlayerMotor
├── PlayerCombat
├── PlayerStats
├── PlayerVisual
└── PlayerInput / MobileHUD
```

This does not require separate nodes for every component immediately. The important goal is separation of responsibilities.

---

# 7. Mobile Input

Touch input is a first-class system.

Historical joystick behavior includes:

- Analog stick
- Dead zone
- Partial movement speed
- Camera-relative movement
- One tracked finger for movement
- Another finger able to use attack/dodge controls
- Desktop mouse/keyboard fallback for testing

## Contract

Gameplay changes must not assume that one pointer controls the entire game.

Multi-touch must remain possible.

---

# 8. Dodge System

Historical player versions expose methods similar to:

```gdscript
can_dodge()
is_dodging()
get_dodge_cooldown_remaining()
start_dodge()
reset_dodge()
```

The combat UI may call these methods.

Do not remove them unless combat is migrated at the same time.

## Current Combat/Dodge Policy

The integrated prototype currently applies these explicit rules:

- Attack input during the active dodge window is ignored.
- Dodge input during an attack cooldown is allowed. Attack damage resolves on
  button press, so this does not duplicate or defer damage.
- Enemy damage is ignored throughout the active dodge window.
- Repeated attacks are limited by the combat cooldown; repeated dodges are
  limited by the player's dodge duration and cooldown.
- A held joystick dodges in the last resolved camera-relative movement
  direction. A stationary dodge uses `Character Visual`'s local forward axis.
- Encounter restart calls `reset_dodge()` and restores player physics.

This documents existing behavior rather than introducing a new combat design.

## Future Considerations

Decide explicitly:

- Whether dodge grants invulnerability frames
- Whether attacks can cancel into dodge
- Whether dodge can cancel attacks
- Whether stamina limits dodge
- Whether dodge direction uses input or facing
- How dodge interacts with knockback

These should be design decisions, not accidental side effects.

---

# 9. Combat System

Historical combat prototypes have included:

- Player health
- Enemy health
- Melee attack range
- Directional attack arc
- Attack cooldown
- Enemy chase range
- Enemy attack range
- Runtime enemy spawning
- Mobile attack/dodge HUD

## Desired Direction

Split combat into reusable concepts:

```text
Damageable
Attack / Hitbox
Health
EnemyBrain
Encounter
CombatHUD
```

Avoid a future where one `DungeonCombat.gd` owns every enemy, all UI, all player combat, and the entire encounter lifecycle.

Prototype code may remain monolithic until the next feature requires separation.

---

# 10. Enemy Architecture

Enemies should eventually become reusable scenes/resources rather than runtime primitive bodies embedded entirely inside a combat manager.

Suggested structure:

```text
Enemy
├── CharacterBody3D
├── Visual
├── Collision
├── EnemyBrain
├── Health
└── AttackComponent
```

Enemy definitions should expose tunable values through resources or exported variables.

---

# 11. Encounter System

Future room-based encounter flow:

```text
Player enters encounter room
        ↓
Encounter activates
        ↓
Enemies spawn
        ↓
Room optionally locks
        ↓
Enemies defeated
        ↓
Reward / exit unlocked
```

The dungeon generator should mark potential encounter rooms, while the encounter system owns enemy spawning.

---

# 12. Camera System

Historical camera behavior uses:

- Orthographic projection
- Isometric offset
- Smooth player following

The camera should remain independent of dungeon generation.

Dungeon code should not continuously control the active camera after gameplay begins.

Potential future features:

- Slight look-ahead
- Combat framing
- Camera shake
- Zoom tuning
- Boss-room framing

Keep camera effects subtle on mobile.

---

# 13. Visual System

The game currently uses or has used runtime-created placeholder visuals.

This is useful for prototyping because gameplay can progress without an external art pipeline.

As production assets are added:

- Keep gameplay nodes independent from mesh choice.
- Replace visuals without replacing player/enemy logic.
- Avoid using mesh names as gameplay identifiers.
- Keep collisions separate from art meshes.

---

# 14. Materials & Textures

Dungeon materials should be reused.

Avoid creating a unique material instance for every repeated wall or floor unless runtime modification requires it.

Material categories may include:

- Stone
- Aged stone
- Mossy stone
- Floor
- Dark/cracked stone
- Metal
- Bronze/accent
- Emissive magical accent

Texture paths should be centralized when possible.

---

# 15. Performance Architecture

Repeated dungeon geometry should favor:

- Shared meshes
- Shared materials
- MultiMesh / batching where beneficial
- Simple collision
- Controlled dynamic lighting
- Limited transparency

Do not use optimization techniques that make level authoring impossible to maintain.

Measure representative scenes before and after major optimization work.

---

# 16. Data vs Code

As systems mature, tuneable values should move toward data/resources.

Candidates include:

- Player stats
- Weapons
- Enemies
- Loot tables
- Room definitions
- Encounter definitions
- Material themes
- Dungeon generation weights

Avoid hard-coding every future content variant into GDScript.

---

# 17. Proposed Directory Direction

Do not reorganize the repository solely to match this tree. Migrate gradually when touching the relevant systems.

```text
res://
├── scenes/
│   ├── game/
│   ├── player/
│   ├── enemies/
│   ├── dungeon/
│   └── ui/
├── scripts/
│   ├── player/
│   ├── combat/
│   ├── enemies/
│   ├── dungeon/
│   ├── encounters/
│   └── ui/
├── resources/
│   ├── enemies/
│   ├── items/
│   ├── rooms/
│   └── themes/
├── art/
│   ├── meshes/
│   ├── textures/
│   ├── materials/
│   └── vfx/
└── tests/
```

---

# 18. Cross-System Contracts

Until a formal component architecture is complete, treat these as protected concepts:

- Root dungeon lifecycle
- Player lookup / reference
- Player visual attachment root
- Combat-to-player dodge interface
- Camera-relative movement
- Dungeon room connectivity data
- Room connection query functions
- Runtime generation completion timing

Any change to these must include:

1. Reference search
2. Migration of callers
3. Relevant testing
4. Documentation update

---

# 19. Technical Debt to Resolve Gradually

Likely technical debt areas:

- Multiple generations of similarly named scripts
- Runtime procedural code that combines several responsibilities
- Frame-delay initialization dependencies
- Hard-coded tuning values
- Runtime-created UI tightly coupled to combat
- Runtime-created enemy tightly coupled to combat manager
- Placeholder visuals mixed with gameplay initialization

Do not attempt to resolve all of these in one refactor.

Each refactor should be justified by an upcoming gameplay need.

---

# 20. Architecture Decision Rule

When choosing between:

A. a sophisticated system that might be useful later, and  
B. a simple system that solves the current mobile-game need cleanly,

prefer B.

Build extensibility where a real next step requires it, not for hypothetical future complexity.
