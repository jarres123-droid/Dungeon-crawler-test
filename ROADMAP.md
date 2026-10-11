# ROADMAP.md

# Mobile Dungeon Game Roadmap

This roadmap describes the intended progression from the current prototype into a polished mobile dungeon crawler.

It is a direction document, not a rigid promise. The Lead Agent may reorder work when dependencies or testing show a better sequence.

---

## Current Foundation

The project already has prototypes or working versions of several important systems:

- 3D Godot dungeon scene
- Player movement
- Mobile touch input
- Analog joystick work
- Isometric/follow camera
- Basic melee combat
- Directional/facing-aware attacks
- Enemy chase/attack behavior
- Dodge roll
- Procedural dungeon work
- Dungeon art/visual upgrades
- Phone-oriented textures
- Decorative architecture upgrades

The next goal is to turn these individually working pieces into one stable, expandable game architecture.

---

# Phase 1 — Stabilize the Core

## Goal

Create a reliable playable loop that can be extended without breaking older systems.

## Milestones

- [ ] Identify the active main scene and active script versions.
- [ ] Remove or clearly separate obsolete prototype files from active game code.
- [ ] Document the active node tree.
- [ ] Confirm player movement works with touch.
- [ ] Confirm attack and dodge work together with multi-touch.
- [ ] Confirm follow camera works across procedural rooms.
- [ ] Confirm procedural generation consistently creates traversable dungeons.
- [ ] Eliminate major runtime errors and warnings.
- [ ] Establish stable interfaces between player, combat, dungeon, visuals, and camera.
- [ ] Create a basic repeatable smoke-test checklist.

## Exit Criteria

A player can launch the game, move through a generated dungeon, fight at least one enemy, dodge, and continue playing without a major system failure.

---

# Phase 2 — Combat Becomes Fun

## Goal

Move from a combat demo to a satisfying mobile action loop.

## Planned Work

- [ ] Improve attack responsiveness.
- [ ] Add readable attack anticipation.
- [ ] Add enemy hit reaction.
- [ ] Add player hit reaction.
- [ ] Add death flow.
- [ ] Add restart / room reset flow.
- [ ] Improve enemy pathing around architecture.
- [ ] Add multiple enemy archetypes.
- [ ] Add knockback or stagger where appropriate.
- [ ] Add attack VFX.
- [ ] Add impact audio hooks.
- [ ] Tune attack arc, range, speed, cooldown, and dodge timing.
- [ ] Prevent damage during unintended states.
- [ ] Decide whether dodge grants invulnerability frames.
- [ ] Add combat encounter spawning instead of a single fixed enemy.

## Candidate Enemy Archetypes

- Skeleton melee fighter
- Fast weak creature
- Slow armored enemy
- Ranged enemy
- Mini-boss / elite

## Exit Criteria

Combat should be understandable with no tutorial beyond basic icons and enjoyable for repeated encounters.

---

# Phase 3 — Dungeon Generation 2.0

## Goal

Make each run feel meaningfully different rather than like the same room arrangement shuffled.

## Planned Work

- [ ] Separate dungeon logical layout from visual construction.
- [ ] Create room archetypes.
- [ ] Create corridor archetypes.
- [ ] Add room tags / purposes.
- [ ] Add weighted generation rules.
- [ ] Add dead ends with rewards.
- [ ] Add combat rooms.
- [ ] Add treasure rooms.
- [ ] Add transition rooms.
- [ ] Add larger landmark rooms.
- [ ] Improve door/opening alignment.
- [ ] Prevent overlapping geometry.
- [ ] Validate dungeon connectivity automatically.
- [ ] Create deterministic seed support for debugging.

## Example Room Types

- Entry
- Small combat room
- Large combat room
- Shrine
- Storage room
- Prison
- Collapsed chamber
- Treasure vault
- Trap room
- Elite room
- Boss approach
- Boss room

## Exit Criteria

Multiple generated seeds should produce visibly and tactically different runs while remaining navigable.

---

# Phase 4 — Visual Identity & Architecture

## Goal

Give the dungeon a recognizable style rather than a collection of prototype primitives.

## Planned Work

- [ ] Define a consistent dark-fantasy material palette.
- [ ] Improve walls, floors, columns, arches, doors, and thresholds.
- [ ] Remove gaps and coplanar overlaps.
- [ ] Reduce Z-fighting.
- [ ] Add modular visual variation.
- [ ] Add controlled grime/moss variation.
- [ ] Add props.
- [ ] Add lighting variation by room type.
- [ ] Add readable combat lighting.
- [ ] Add environmental VFX.
- [ ] Add visual landmarks that help navigation.
- [ ] Establish mobile LOD / quality tiers.

## Exit Criteria

Screenshots from different rooms should look like the same game while still showing meaningful visual variety.

---

# Phase 5 — Loot, Equipment & Progression

## Goal

Create a reason to explore and replay dungeons.

## Planned Work

- [ ] Item data model
- [ ] Loot drops
- [ ] Pickup interaction
- [ ] Inventory
- [ ] Equipment slots
- [ ] Weapon stats
- [ ] Armor stats
- [ ] Rarity tiers
- [ ] Item comparison UI
- [ ] Basic player stats
- [ ] Healing items
- [ ] Currency
- [ ] Reward chests
- [ ] Persistent run rewards

## Exit Criteria

Completing rooms and defeating enemies provides meaningful rewards that change the player's capabilities.

---

# Phase 6 — Run Structure

## Goal

Turn isolated dungeon gameplay into a complete repeatable game session.

## Planned Work

- [ ] Start-run flow
- [ ] Procedural seed selection
- [ ] Room progression
- [ ] Encounter pacing
- [ ] Treasure pacing
- [ ] Boss encounter
- [ ] Run completion
- [ ] Player death
- [ ] Results screen
- [ ] Meta-progression hook
- [ ] Save data

## Exit Criteria

A player can start a run, progress through a dungeon, reach an ending condition, and begin another run.

---

# Phase 7 — Mobile UX & Polish

## Goal

Make the game feel intentionally built for a phone.

## Planned Work

- [ ] Safe-area handling
- [ ] Scalable HUD
- [ ] Adjustable control placement
- [ ] Better button icons
- [ ] Haptic hooks
- [ ] Touch feedback
- [ ] Pause menu
- [ ] Settings
- [ ] Graphics quality options
- [ ] Audio controls
- [ ] Tutorial/onboarding
- [ ] Accessibility review

## Exit Criteria

Controls are comfortable, readable, and reliable across common phone screen sizes.

---

# Phase 8 — Performance Pass

## Goal

Keep the game smooth as content density increases.

## Planned Work

- [ ] Establish representative test dungeon.
- [ ] Record baseline performance.
- [ ] Profile CPU.
- [ ] Profile GPU.
- [ ] Inspect draw calls.
- [ ] Inspect material count.
- [ ] Inspect collision complexity.
- [ ] Batch repeated geometry where appropriate.
- [ ] Pool frequently spawned objects where appropriate.
- [ ] Reduce expensive dynamic lights.
- [ ] Add distance-based visual reduction.
- [ ] Tune shadows.
- [ ] Tune texture resolution.
- [ ] Test low / medium / high quality presets.

## Exit Criteria

Representative gameplay maintains an acceptable frame rate on the target mobile hardware.

---

# Phase 9 — Content Expansion

Only after the core loop is stable:

- Additional dungeon themes
- More room sets
- More enemies
- Bosses
- Traps
- Weapons
- Armor
- Consumables
- Status effects
- Environmental hazards
- Secrets
- Challenges
- Achievements

---

# Near-Term Priority Order

Unless a blocking issue changes the plan:

1. Stabilize active project structure.
2. Verify current dungeon generation + architecture integration.
3. Consolidate player movement / joystick / dodge.
4. Consolidate combat.
5. Create repeatable smoke tests.
6. Improve procedural room variety.
7. Add encounter spawning.
8. Add first loot/reward loop.
9. Polish visuals.
10. Profile mobile performance.

---

# Scope Guardrail

Do not jump directly into large systems such as:

- Online multiplayer
- Complex crafting
- Open-world streaming
- Large dialogue systems
- Live-service architecture
- Procedural quest generation

until the core mobile dungeon loop is demonstrably fun and stable.
