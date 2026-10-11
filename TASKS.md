# TASKS.md

# Mobile Dungeon Agent Task Board

This file is designed for both the user and coding agents.

Agents should update task status when they materially complete work.

Status keys:

- `TODO` — ready to work
- `IN PROGRESS` — actively owned by an agent
- `BLOCKED` — cannot proceed without another change/decision
- `REVIEW` — implementation done; needs verification
- `DONE` — completed and validated

Priority:

- `P0` — blocking / project safety
- `P1` — important next work
- `P2` — valuable
- `P3` — later polish

---

# Agent Ownership

| Agent | Primary Area |
|---|---|
| Lead / Architecture | integration, architecture, docs, shared interfaces |
| Dungeon & World | procedural dungeon, rooms, corridors, architecture |
| Gameplay | player, controls, combat, dodge, enemies |
| Art & Polish | materials, textures, lighting, visual variety, UI polish |
| QA / Review | regression testing, compatibility, mobile behavior |

---

# Batch 0 — Agent Readiness

## T-001 — Audit active project versions
**Status:** TODO  
**Priority:** P0  
**Owner:** Lead / Architecture

Determine which script versions are actually active in the current main scene.

Deliver:

- Active main scene path
- Active script attached to `Dungeon`
- Active script attached to `Player`
- Active combat script
- Active follow camera
- Active visual/art scripts
- Active architecture scripts
- List of obviously obsolete or archived alternatives

Do not delete anything in this task.

---

## T-002 — Document the live scene tree
**Status:** TODO  
**Priority:** P0  
**Owner:** Lead / Architecture

Update `ARCHITECTURE.md` with the real scene tree after inspecting the project.

Include runtime-created nodes separately from editor-authored nodes.

---

## T-003 — Baseline smoke test
**Status:** TODO  
**Priority:** P0  
**Owner:** QA / Review

Verify current behavior before feature work.

Check:

- Game launches
- Dungeon generates
- Player moves
- Joystick works
- Camera follows
- Attack works
- Dodge works
- Enemy attacks
- Restart/reset works if present
- Player can travel through generated openings

Record existing failures without fixing unrelated systems.

---

# Batch 1 — Stabilize Existing Systems

## T-010 — Consolidate player movement version
**Status:** REVIEW
**Priority:** P1  
**Owner:** Gameplay

Identify the current best mobile player controller.

Preserve:

- Analog joystick
- Camera-relative movement
- Partial stick speed
- Facing
- Multi-touch
- Dodge interface
- `Character Visual` compatibility if still referenced

Avoid a large redesign.

Integration review confirms `playerjoystickdodge.gd` is the single controller
attached to `Player` in both active scenes. Static and headless checks passed;
final touch feel and multi-touch behavior require an Android device.

---

## T-011 — Consolidate combat version
**Status:** REVIEW
**Priority:** P1  
**Owner:** Gameplay

Identify the newest working combat implementation and make it the clear active version.

Preserve:

- Directional attack behavior
- Attack button
- Dodge button
- Enemy chase
- Enemy attack
- Health
- Multi-touch

Document tuning constants.

Integration review confirms `dungeoncombatdodge.gd` is the active dungeon
combat implementation and its tuning remains centralized as constants. The
dungeon scene initializes combat successfully headlessly; physical touch combat
remains an Android review item.

---

## T-012 — Verify combat + dodge state interactions
**Status:** REVIEW
**Priority:** P1  
**Owner:** Gameplay

Test and define behavior for:

- Attack while dodging
- Dodge while attacking
- Enemy hit during dodge
- Button spam
- Dodge cooldown
- Stationary dodge direction
- Joystick-held dodge direction

Do not add stamina yet.

The current interaction policy is documented in `ARCHITECTURE.md` and the
relevant cooldown, invulnerability, directional-dodge, and restart paths pass
parse/startup review. Button-spam and simultaneous-finger behavior still need
final device validation.

---

## T-013 — Remove camera ownership ambiguity
**Status:** TODO  
**Priority:** P1  
**Owner:** Lead / Architecture

Ensure only the intended gameplay camera is active.

Older dungeon scripts may create their own camera while a separate follow camera also exists.

Preserve the smooth isometric follow behavior.

---

# Batch 2 — Procedural Dungeon Quality

## T-020 — Validate dungeon connectivity
**Status:** DONE
**Priority:** P1  
**Owner:** Dungeon & World

Add or improve a validation step that confirms every required room is reachable from the start room.

Prefer logic-level validation rather than visual inspection only.

Generation now runs a reachability check before physical construction. The
headless validation covers connected fixed/random plans and a deliberately
disconnected negative case.

---

## T-021 — Add deterministic debug seed
**Status:** DONE
**Priority:** P1  
**Owner:** Dungeon & World

Allow a fixed seed for debugging while preserving random generation for normal play.

The active seed should be easy to print or display during development.

`debug_seed = 0` preserves random generation; a positive exported value
reproduces the logical layout. The active seed is printed at dungeon startup
and exposed through `get_active_seed()`.

---

## T-022 — Architecture collision audit
**Status:** DONE
**Priority:** P1  
**Owner:** Dungeon & World

Inspect decorative dungeon architecture for:

- Doorway obstruction
- Corridor obstruction
- Floating pieces
- Overlaps
- Z-fighting
- Coplanar surfaces
- Gaps
- Repeated pieces stacked in the same position

Fix only issues within architecture/world ownership.

The active architecture layer was audited as visual-only `MultiMesh` geometry:
it adds no collision bodies or shapes, keeps the 4 m doorway opening clear, and
uses thin non-colliding thresholds. Headless dungeon construction completed
without runtime errors.

---

## T-023 — Room archetype framework
**Status:** TODO  
**Priority:** P1  
**Owner:** Dungeon & World

Introduce a lightweight way to classify rooms without rewriting the whole generator.

Initial types:

- Entry
- Normal
- Combat
- Treasure
- Landmark
- Exit

The visual builder may initially treat several types the same.

---

## T-024 — Improve room visual variety
**Status:** TODO  
**Priority:** P2  
**Owner:** Art & Polish

Use controlled variation rather than completely random decoration.

Possible variation:

- Column sets
- Wall aging
- Floor damage
- Moss amount
- Accent material
- Prop clusters
- Light placement

Keep navigation readable.

---

# Batch 3 — Encounter System

## T-030 — Decouple enemy spawning from fixed coordinates
**Status:** TODO  
**Priority:** P1  
**Owner:** Gameplay

Replace fixed one-off enemy placement with spawn anchors or room-relative spawning.

Do not build a full wave system yet.

---

## T-031 — Create encounter room activation
**Status:** TODO  
**Priority:** P1  
**Owner:** Gameplay

When the player enters a combat room:

- Activate/spawn enemies
- Track enemies in the encounter
- Detect completion
- Emit encounter-completed state

Room locking is optional for the first pass.

---

## T-032 — Add second enemy archetype
**Status:** TODO  
**Priority:** P2  
**Owner:** Gameplay

Add one enemy that plays differently from the base melee enemy.

Good first options:

- Faster, weaker melee enemy
- Slow heavy enemy

Avoid ranged combat until encounter architecture is stable.

---

# Batch 4 — First Reward Loop

## T-040 — Basic pickup object
**Status:** TODO  
**Priority:** P1  
**Owner:** Gameplay

Create a reusable pickup that can be collected on mobile without precise tapping.

Start with one simple reward type.

---

## T-041 — Treasure room reward
**Status:** TODO  
**Priority:** P1  
**Owner:** Gameplay + Dungeon & World

Treasure-tagged rooms should contain a reward.

Keep the first version simple.

---

## T-042 — Minimal player currency/stat reward
**Status:** TODO  
**Priority:** P2  
**Owner:** Gameplay

Persist a simple value during the run so rewards have visible meaning.

No permanent save system required yet.

---

# Batch 5 — Visual Polish

## T-050 — Material reuse audit
**Status:** TODO  
**Priority:** P2  
**Owner:** Art & Polish

Find repeated runtime-created materials that can safely be shared.

Goal:

- Reduce unnecessary material count
- Preserve visual variety
- Avoid accidental shared-state changes when runtime tinting is needed

---

## T-051 — Lighting pass
**Status:** TODO  
**Priority:** P2  
**Owner:** Art & Polish

Improve atmosphere while preserving gameplay readability.

Avoid adding many shadow-casting dynamic lights.

---

## T-052 — Combat readability pass
**Status:** TODO  
**Priority:** P2  
**Owner:** Art & Polish

Improve:

- Enemy hit feedback
- Player damage feedback
- Attack cue
- Dodge cue
- Enemy attack cue

Prefer inexpensive effects.

---

# Batch 6 — Mobile QA / Performance

## T-060 — UI safe-area review
**Status:** TODO  
**Priority:** P1  
**Owner:** QA / Review

Check touch controls on different aspect ratios.

Verify that joystick, attack, dodge, health, and other HUD elements do not collide with screen edges or each other.

---

## T-061 — Multi-touch regression test
**Status:** TODO  
**Priority:** P1  
**Owner:** QA / Review

Verify combinations including:

- Move + attack
- Move + dodge
- Hold movement while repeatedly attacking
- Release joystick while attacking
- Switch movement direction during combat

---

## T-062 — Baseline performance capture
**Status:** TODO  
**Priority:** P2  
**Owner:** QA / Review

Capture a representative baseline before adding substantially more content.

Record if available:

- FPS
- Frame time
- Draw calls
- Object count
- Material count
- Triangle count
- Device / environment

---

# Recommended First Parallel Agent Run

Start with these in parallel because their ownership areas are mostly separate:

### Lead Agent
Take `T-001` and `T-002`.

### Gameplay Agent
After a quick active-version inspection, evaluate `T-010`, `T-011`, and `T-012`, but do not commit broad consolidation until the Lead Agent's active-version audit is clear.

### Dungeon & World Agent
Take `T-020` and inspect `T-022`.

### QA Agent
Take `T-003`.

Avoid starting major Art & Polish modifications until the active script/version audit is complete.

---

# Human Decisions Needed Later

The user should eventually choose:

- Portrait vs landscape as the permanent orientation, if not already fixed
- Target minimum Android hardware
- Desired run length
- Whether dodge has invulnerability frames
- Whether the game is roguelite or traditional dungeon crawler
- Art style target
- Permanent progression model
- Monetization model, if any

Agents should not invent product decisions in these areas unless explicitly asked to prototype an option.
