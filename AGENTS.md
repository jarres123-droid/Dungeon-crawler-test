# AGENTS.md

# Mobile Dungeon Game — Agent Operating Rules

This repository contains a mobile-first 3D dungeon crawler built in Godot 4.x.

The goal of this file is to let multiple coding agents work safely in the same project without breaking systems owned by other agents.

## 1. Product Direction

Build a polished, replayable mobile dungeon crawler with:

- Procedurally generated dungeon layouts
- Touch-first controls
- Responsive melee combat
- Dodge/evade mechanics
- Enemies with readable behavior
- Loot and progression
- Increasing visual variety
- Strong mobile performance
- A stylized dark-fantasy dungeon presentation

The game should remain fun and readable on a phone screen. Desktop input may be supported for testing, but mobile behavior takes priority.

## 2. Source of Truth

The checked-out repository is always the source of truth.

This project has gone through multiple prototype versions. Old scripts, archived ZIPs, alternate versions, or similarly named files may exist.

Before changing a system:

1. Inspect the current scene tree.
2. Determine which script is actually attached to each relevant node.
3. Search for references to the script, class, node name, signal, and public methods.
4. Do not replace an active newer implementation with an older standalone version.
5. Preserve compatibility unless the task explicitly authorizes a migration.

Never assume a file is active merely because its filename looks canonical.

## 3. Known Project Patterns

The project has historically used runtime-generated Godot nodes and meshes.

Examples include systems that create:

- Player visuals
- Mobile controls
- Combat HUD
- Enemies
- Dungeon architecture
- Decorative meshes
- Materials
- Lighting
- Dungeon geometry

Several systems may be children of the same `Dungeon` root and may initialize with deferred calls because procedural dungeon generation occurs first.

Treat initialization order as important.

Do not casually change:

- `_ready()` timing
- `call_deferred(...)`
- frame waits
- expected node names
- runtime-created child structure

without tracing dependent systems first.

## 4. Important Compatibility Contracts

Existing systems may rely on specific node names and public methods.

Known historical contracts include names such as:

- `Dungeon`
- `Player`
- `DungeonCombat`
- `Character Visual`
- `FollowCamera`

Known player/combat integrations have used public methods such as:

- `start_dodge()`
- `can_dodge()`
- `is_dodging()`
- `get_dodge_cooldown_remaining()`
- `reset_dodge()`

Do not rename or remove a public contract unless all references are migrated in the same change.

If a contract must change, document it in `ARCHITECTURE.md`.

## 5. Mobile-First Rules

Every gameplay change must consider Android/mobile behavior.

Preserve:

- Touch input
- Multi-touch where required
- Analog joystick behavior
- On-screen attack/dodge controls
- Camera-relative movement
- Reasonable UI sizing
- Performance on mobile GPUs

Avoid systems that require keyboard or mouse input to function.

Desktop controls are fallbacks for testing only unless otherwise specified.

## 6. Performance Rules

Prefer inexpensive solutions suitable for mobile.

Use these principles:

- Reuse meshes and materials where practical.
- Prefer batching / instancing for repeated dungeon geometry.
- Avoid unnecessary per-frame allocations.
- Avoid expensive scene-tree searches every frame when references can be cached.
- Avoid large numbers of dynamic lights.
- Keep collision shapes simple when possible.
- Avoid excessive transparent materials.
- Avoid high-poly procedural geometry unless the visual benefit is justified.
- Avoid creating duplicate materials for every instance.
- Profile before making speculative optimizations.

Do not trade major gameplay quality for micro-optimizations without evidence.

## 7. Visual Rules

The target is stylized dark fantasy rather than photorealism.

Priorities:

1. Strong silhouette
2. Readable gameplay
3. Material differentiation
4. Environmental variety
5. Cohesive dungeon mood
6. Mobile performance

Avoid noisy detail that becomes unreadable on a phone screen.

Architecture should feel deliberately built rather than like overlapping primitive blocks.

Prevent:

- Z-fighting
- Coplanar duplicate surfaces
- Visible gaps between modular pieces
- Floating decorations
- Geometry clipping through doors
- Decorative meshes blocking navigation
- Excessive repetition

## 8. Agent Roles

Agents should stay primarily within their assigned ownership area.

### Lead / Architecture Agent

Owns:

- Overall technical direction
- Cross-system integration
- Major refactors
- Scene architecture
- Shared interfaces
- Documentation
- Review of cross-cutting changes

May modify any system when needed, but should minimize unnecessary churn.

### Dungeon & World Agent

Owns:

- Procedural dungeon generation
- Room/corridor rules
- Dungeon architecture
- Environmental placement
- Room variety
- Spawn-point generation
- World decoration
- Dungeon-specific performance

Should not rewrite player combat or controls unless required for a documented interface change.

### Gameplay Agent

Owns:

- Player movement
- Touch controls
- Dodge
- Combat
- Enemy gameplay
- Health/damage
- Loot interaction
- Progression mechanics

Should not redesign procedural world generation without coordination.

### Art & Polish Agent

Owns:

- Materials
- Textures
- Runtime visual meshes
- Lighting polish
- VFX
- UI visual polish
- Environmental visual variation

Must not silently change gameplay collision or combat values while doing visual work.

### QA / Review Agent

Owns:

- Regression checks
- Static review
- Runtime error investigation
- Mobile input verification
- Performance review
- Cross-system compatibility checks
- Reproduction steps

Should prefer reporting defects before making broad architectural rewrites.

## 9. Parallel Work Rules

When multiple agents are active:

- One agent should own a subsystem at a time.
- Avoid editing the same file from multiple branches unless necessary.
- Keep changes narrow and reviewable.
- Do not mix unrelated cleanup into feature work.
- If a task requires another agent's owned system, prefer a small documented interface change.
- Flag likely merge conflicts in the final report.

Before starting, state which files or systems you expect to touch.

## 10. Change Discipline

For every task:

1. Inspect before editing.
2. Identify dependencies.
3. Make the smallest coherent change.
4. Preserve existing working behavior unless the task says otherwise.
5. Run available validation.
6. Review the diff.
7. Report what changed and anything uncertain.

Do not perform broad "cleanup" merely because code could be rewritten.

Do not delete working prototype functionality without explicit justification.

## 11. Godot / GDScript Guidelines

Use Godot 4.x APIs.

Prefer:

- Typed variables where practical
- Clear function names
- Small focused functions
- Explicit node references
- Signals or narrow public interfaces instead of deep cross-system coupling
- Constants for gameplay tuning values
- Export variables for values designers may reasonably tune in the editor

Avoid:

- Magic node paths scattered throughout the code
- Repeated `get_node()` calls in hot loops
- Massive single scripts as the project grows
- Hidden dependencies on creation order
- Unexplained hard-coded world coordinates

If runtime generation remains appropriate, organize it into clear builders/managers rather than one monolithic script.

## 12. Testing Expectations

At minimum, evaluate:

### Startup
- Project opens without parse errors.
- Main gameplay scene loads.
- No required-node errors occur.

### Player
- Player can move.
- Touch joystick works.
- Character faces movement direction.
- Camera follows correctly.

### Combat
- Attack works.
- Hit detection respects intended facing/range.
- Enemy damage works.
- Dodge works.
- Dodge cooldown works.
- Combat UI remains usable with touch controls.

### Dungeon
- Generation completes.
- Rooms are connected.
- Player can navigate between rooms.
- Door/corridor openings are not blocked.
- Decorative architecture does not obstruct traversal.

### Visuals
- No obvious Z-fighting.
- No major gaps.
- No floating pieces.
- No duplicate surfaces fighting visually.

### Mobile
- UI remains inside the viewport.
- Multi-touch interactions are not broken.
- No new obviously expensive per-frame behavior was introduced.

If the environment cannot launch Godot, perform static validation and clearly say runtime testing was not available.

## 13. Definition of Done

A task is complete only when:

- The requested behavior is implemented.
- Existing relevant behavior is preserved.
- Obvious edge cases were considered.
- The diff was reviewed.
- Validation was run where available.
- Any limitation is documented.
- `TASKS.md` is updated if task status materially changed.
- `ARCHITECTURE.md` is updated for meaningful structural/interface changes.

## 14. Final Agent Report Format

At the end of each task, report:

### Completed
Briefly describe what changed.

### Files Changed
List files changed and why.

### Validation
State exactly what was tested or checked.

### Risks / Follow-ups
List unresolved issues, assumptions, or recommended next work.

### Cross-Agent Impact
Mention any interface, shared file, or likely merge-conflict impact.

Keep this concise and factual.
