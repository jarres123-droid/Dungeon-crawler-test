extends Node3D

# DUNGEON ART v2 -- Godot 4.x / Android / procedural dungeon v1.
# Attach to a NEW child Node3D named DungeonArt in procedural_dungeon.tscn.
# This script reads the EXISTING generator's room plan; it does not replace it.
# All decorative geometry is batched into shared MultiMeshes for mobile performance.
# Solid furniture is restricted to room corners, leaving the 4m-wide pathways open.

@export_enum("Low", "Balanced", "High") var detail_quality: int = 1
@export var enable_prop_collisions: bool = true
@export var flickering_torches: bool = true
@export var brighten_room_lighting: bool = true

const SPACING: float = 24.0
const ROOM_HALF: float = 8.0
const DIRECTIONS = [
	Vector2i(-1, 0), Vector2i(1, 0),
	Vector2i(0, -1), Vector2i(0, 1)
]

var generator: Node3D
var randomizer: RandomNumberGenerator = RandomNumberGenerator.new()
var materials: Dictionary = {}
var batches: Dictionary = {}
var torch_lights: Array[OmniLight3D] = []
var elapsed: float = 0.0
var has_built: bool = false
var room_count: int = 0


func _ready() -> void:
	# Parent Dungeon._ready() runs AFTER its child _ready() functions.
	# A deferred call ensures its random room plan has been created first.
	call_deferred("_build_art")


func _process(delta: float) -> void:
	if not flickering_torches:
		return
	elapsed += delta
	# Only lights change each frame; all stone/prop meshes remain static.
	for index in range(torch_lights.size()):
		var light: OmniLight3D = torch_lights[index]
		var wave: float = sin(elapsed * 7.7 + float(index) * 2.1)
		var slow: float = sin(elapsed * 3.1 + float(index) * 4.3)
		light.light_energy = 0.92 + wave * 0.10 + slow * 0.07


func _build_art() -> void:
	if has_built:
		return
	generator = get_parent() as Node3D
	if generator == null or not generator.has_method("_are_connected"):
		push_warning("DungeonArt: attach to a child of the procedural Dungeon root.")
		return
	var cells_variant = generator.get("dungeon_cells")
	if not (cells_variant is Array):
		push_warning("DungeonArt: procedural room list not available.")
		return
	var cells: Array = cells_variant
	if cells.is_empty():
		push_warning("DungeonArt: no rooms found; check the generator script.")
		return
	has_built = true
	randomizer.randomize()
	_create_materials()
	_tune_original_lighting()
	var exit_pos: Vector2i = generator.get("exit_cell")
	var themes: Array[String] = [
		"CRYPT", "ARMORY", "LIBRARY", "PRISON",
		"FORGE", "SHRINE", "RUINS"
	]
	themes.shuffle()
	var theme_index: int = 0
	for cell_value in cells:
		var cell: Vector2i = cell_value
		var theme: String = "ENTRY"
		if cell == exit_pos and cell != Vector2i.ZERO:
			theme = "SANCTUM"
		elif cell != Vector2i.ZERO:
			theme = themes[theme_index % themes.size()]
			theme_index += 1
		_decorate_room(cell, theme)
		room_count += 1
	_decorate_corridors(cells)
	_accent_existing_pillars_and_chests()
	_flush_mesh_batches()
	print("Dungeon Art v2: %d rooms decorated, %d shared mesh groups, %d accent lights." % [
		room_count, batches.size(), torch_lights.size()
	])


func _material(tint: String, metallic: float = 0.0, luminous: bool = false) -> StandardMaterial3D:
	var result: StandardMaterial3D = StandardMaterial3D.new()
	result.albedo_color = Color(tint)
	result.roughness = 0.86 if metallic == 0.0 else 0.46
	result.metallic = metallic
	if luminous:
		result.emission_enabled = true
		result.emission = Color(tint)
		result.emission_energy_multiplier = 1.6
	return result


func _create_materials() -> void:
	materials = {
		"stone0": _material("#3b4148"),
		"stone1": _material("#535b61"),
		"stone2": _material("#647077"),
		"stone3": _material("#788080"),
		"stone4": _material("#8c8980"),
		"moss": _material("#40584c"),
		"moss2": _material("#586b4b"),
		"dark": _material("#272e37"),
		"wood": _material("#795337"),
		"wood2": _material("#4f352c"),
		"wood3": _material("#a07a4e"),
		"iron": _material("#73838b", 0.66),
		"iron2": _material("#364b58", 0.65),
		"bronze": _material("#b7965a", 0.62),
		"bone": _material("#aeb1a3"),
		"cloth_red": _material("#853d42"),
		"cloth_blue": _material("#3c647e"),
		"cloth_purple": _material("#615178"),
		"parchment": _material("#d4b98a"),
		"gold": _material("#e0b85d", 0.45),
		"ember": _material("#f99943", 0.0, true),
		"aqua": _material("#56c6bf", 0.0, true),
		"violet": _material("#a48af5", 0.0, true)
	}


func _push(kind: String, tint: String, at: Vector3,
		scale: Vector3, yaw: float = 0.0, pitch: float = 0.0, roll: float = 0.0) -> void:
	var key: String = kind + "|" + tint
	if not batches.has(key):
		batches[key] = []
	var rotation: Basis = Basis.from_euler(Vector3(pitch, yaw, roll))
	var tx: Transform3D = Transform3D(rotation.scaled(scale), at)
	var array: Array = batches[key]
	array.append(tx)


func _box(tint: String, at: Vector3, scale: Vector3, yaw: float = 0.0) -> void:
	_push("box", tint, at, scale, yaw)


func _orb(tint: String, at: Vector3, scale: Vector3) -> void:
	_push("orb", tint, at, scale)


func _cylinder(tint: String, at: Vector3, radius: float, height: float) -> void:
	_push("cylinder", tint, at, Vector3(radius * 2.0, height, radius * 2.0))


func _flush_mesh_batches() -> void:
	# 3 shared primitive meshes, reused across all themes and every room.
	# Each material/mesh pair becomes ONE MultiMeshInstance3D draw group.
	for key_variant in batches.keys():
		var key: String = key_variant
		var parts: PackedStringArray = key.split("|")
		var kind: String = parts[0]
		var tint: String = parts[1]
		var instances: Array = batches[key]
		if instances.is_empty():
			continue
		var primitive: PrimitiveMesh
		match kind:
			"orb":
				var sphere: SphereMesh = SphereMesh.new()
				sphere.radius = 0.5
				sphere.height = 1.0
				sphere.radial_segments = 10 if detail_quality == 0 else 14
				sphere.rings = 6 if detail_quality == 0 else 8
				primitive = sphere
			"cylinder":
				var cyl: CylinderMesh = CylinderMesh.new()
				cyl.top_radius = 0.5
				cyl.bottom_radius = 0.5
				cyl.height = 1.0
				cyl.radial_segments = 10 if detail_quality == 0 else 14
				primitive = cyl
			_:
				var cube: BoxMesh = BoxMesh.new()
				cube.size = Vector3.ONE
				primitive = cube
		primitive.material = materials[tint]
		var multi: MultiMesh = MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = primitive
		multi.instance_count = instances.size()
		for index in range(instances.size()):
			multi.set_instance_transform(index, instances[index])
		var item: MultiMeshInstance3D = MultiMeshInstance3D.new()
		item.name = "Dungeon Art " + key
		item.multimesh = multi
		add_child(item)


func _center(cell: Vector2i) -> Vector3:
	return Vector3(float(cell.x) * SPACING, 0.0, float(cell.y) * SPACING)


func _linked(a: Vector2i, b: Vector2i) -> bool:
	return bool(generator.call("_are_connected", a, b))


func _decorate_room(cell: Vector2i, theme: String) -> void:
	var center: Vector3 = _center(cell)
	_wall_masonry(center, cell)
	_floor_accents(center, theme)
	_door_stonework(center, cell)
	_add_wall_sconce(center + Vector3(4.7, 0.0, -7.40), theme == "SANCTUM" or theme == "SHRINE")
	if detail_quality > 0 and (theme == "CRYPT" or theme == "LIBRARY" or theme == "SANCTUM"):
		_add_wall_sconce(center + Vector3(-3.5, 0.0, -7.40), theme == "SANCTUM")
	match theme:
		"ENTRY":
			_entry_room(center)
		"CRYPT":
			_crypt_room(center)
		"ARMORY":
			_armory_room(center)
		"LIBRARY":
			_library_room(center)
		"PRISON":
			_prison_room(center)
		"FORGE":
			_forge_room(center)
		"SHRINE":
			_shrine_room(center)
		"RUINS":
			_ruins_room(center)
		"SANCTUM":
			_sanctum_room(center)


func _wall_masonry(center: Vector3, cell: Vector2i) -> void:
	for dir in DIRECTIONS:
		var connected: bool = _linked(cell, cell + dir)
		var near: bool = dir.x > 0 or dir.y > 0
		var height: float = 1.3 if near else 3.0
		var rows: int = 1 if near else (4 if detail_quality == 2 else 3)
		var cols: int = 7 if detail_quality == 0 else 9
		for row in range(rows):
			for col in range(cols):
				var offset: float = -7.04 + (float(col) + 0.15 * float(row % 2)) * 14.08 / float(cols - 1)
				if absf(offset) > 7.18:
					continue
				if connected and absf(offset) < 2.32:
					continue
				var y: float = (float(row) + 0.51) * height / float(rows)
				var shade: String = ["stone1", "stone2", "stone3", "stone0"][randomizer.randi_range(0, 3)]
				if detail_quality > 0 and randomizer.randf() < 0.075:
					shade = "moss"
				var length: float = 12.7 / float(cols - 1)
				var thickness: float = 0.10
				var brick_h: float = height * 0.82 / float(rows)
				var placement: Vector3
				var size: Vector3
				if dir.x != 0:
					placement = center + Vector3(float(dir.x) * 7.55, y, offset)
					size = Vector3(thickness, brick_h, length)
				else:
					placement = center + Vector3(offset, y, float(dir.y) * 7.55)
					size = Vector3(length, brick_h, thickness)
				_box(shade, placement, size)
		# Raised capstones draw an outline without blocking the doorway.
		var rail_at: Vector3 = center + Vector3(float(dir.x) * 7.53,
			height + 0.025, float(dir.y) * 7.53)
		if dir.x == 0:
			if connected:
				_box("stone4", rail_at + Vector3(-5, 0, 0), Vector3(5.6, 0.14, 0.65))
				_box("stone4", rail_at + Vector3(5, 0, 0), Vector3(5.6, 0.14, 0.65))
			else:
				_box("stone4", rail_at, Vector3(15.2, 0.14, 0.65))
		else:
			if connected:
				_box("stone4", rail_at + Vector3(0, 0, -5), Vector3(0.65, 0.14, 5.6))
				_box("stone4", rail_at + Vector3(0, 0, 5), Vector3(0.65, 0.14, 5.6))
			else:
				_box("stone4", rail_at, Vector3(0.65, 0.14, 15.2))
		if detail_quality > 0:
			_wall_inlays(center, dir, near, connected)


func _wall_inlays(center: Vector3, dir: Vector2i, near: bool, connected: bool) -> void:
	var h: float = 0.62 if near else 1.8
	for u in [-5.4, -3.45, 3.45, 5.4]:
		if connected and absf(u) < 2.3:
			continue
		if randomizer.randf() < 0.55:
			continue
		var at: Vector3 = center + Vector3(float(dir.x) * 7.47,
			h, float(dir.y) * 7.47)
		if dir.x != 0:
			at.z += u
			_box("stone4", at, Vector3(0.14, 0.11, 0.56))
			_box("dark", at + Vector3(-float(dir.x) * 0.09, 0.0, 0.0), Vector3(0.04, 0.045, 0.35))
		else:
			at.x += u
			_box("stone4", at, Vector3(0.56, 0.11, 0.14))
			_box("dark", at + Vector3(0.0, 0.0, -float(dir.y) * 0.09), Vector3(0.35, 0.045, 0.04))


func _door_stonework(center: Vector3, cell: Vector2i) -> void:
	for dir in DIRECTIONS:
		if not _linked(cell, cell + dir):
			continue
		var near: bool = dir.x > 0 or dir.y > 0
		var height: float = 1.35 if near else 2.95
		var boundary: Vector3 = center + Vector3(float(dir.x) * 7.55, 0.0, float(dir.y) * 7.55)
		# Decorative jambs sit OUTSIDE the 4m door gap. No new collisions.
		for sign in [-1.0, 1.0]:
			var at: Vector3 = boundary + Vector3(0.0, height * 0.5, 0.0)
			var size: Vector3 = Vector3(0.36, height, 0.34)
			if dir.x != 0:
				at.z += sign * 2.4
			else:
				at.x += sign * 2.4
			_box("stone4", at, size)
			_box("bronze", at + Vector3(0, height * 0.37, 0), Vector3(0.39, 0.10, 0.38))
		if not near:
			var lintel: Vector3 = boundary + Vector3(0.0, 2.76, 0.0)
			var dims: Vector3 = Vector3(4.15, 0.27, 0.35)
			if dir.x != 0:
				dims = Vector3(0.35, 0.27, 4.15)
			_box("stone4", lintel, dims)
			_box("bronze", lintel + Vector3(0.0, 0.18, 0.0),
				Vector3(dims.x * 0.4 + 0.10, 0.15, dims.z * 0.4 + 0.10))


func _floor_accents(center: Vector3, theme: String) -> void:
	var count: int = 10 if detail_quality == 0 else (23 if detail_quality == 1 else 38)
	for i in range(count):
		var x: float = randomizer.randf_range(-6.8, 6.8)
		var z: float = randomizer.randf_range(-6.8, 6.8)
		# Keep corridors and the central player/exit paths visually uncluttered.
		if absf(x) < 2.2 or absf(z) < 2.2:
			continue
		var tint: String = "stone4" if randomizer.randf() < 0.6 else "moss"
		var at: Vector3 = center + Vector3(x, 0.059, z)
		if randomizer.randf() < 0.22:
			_orb("stone3", at + Vector3(0, 0.05, 0), Vector3(0.32, 0.13, 0.26))
		else:
			_box(tint, at, Vector3(randomizer.randf_range(0.16, 0.55),
				0.016, randomizer.randf_range(0.06, 0.22)), randomizer.randf_range(-1.5, 1.5))
	if theme == "ENTRY":
		_rug(center + Vector3(-3.8, 0, 2.7), "cloth_blue")
	elif theme == "CRYPT":
		_rug(center + Vector3(3.8, 0, 2.7), "cloth_red")
	elif theme == "LIBRARY" or theme == "ARMORY":
		_rug(center + Vector3(-3.8, 0, 2.7), "cloth_purple")
	elif theme == "SANCTUM":
		_rune_circle(center, "gold")


func _rug(at: Vector3, tint: String) -> void:
	_box("wood2", at + Vector3(0, 0.061, 0), Vector3(2.1, 0.018, 2.8))
	_box(tint, at + Vector3(0, 0.074, 0), Vector3(1.91, 0.012, 2.59))
	for z in [-1.15, 1.15]:
		_box("gold", at + Vector3(0, 0.084, z), Vector3(1.72, 0.014, 0.065))
	_box("gold", at + Vector3(0, 0.086, 0), Vector3(0.12, 0.015, 1.5))


func _add_wall_sconce(at: Vector3, magic: bool = false) -> void:
	# Positioned on the far (-Z) wall and high above navigation height.
	var tint: String = "violet" if magic else "ember"
	_box("iron2", at + Vector3(0, 1.73, 0), Vector3(0.12, 0.45, 0.38))
	_box("iron", at + Vector3(0, 1.93, 0.20), Vector3(0.52, 0.09, 0.36))
	_orb(tint, at + Vector3(0, 2.18, 0.20), Vector3(0.29, 0.55, 0.29))
	_orb("gold" if magic else "bronze", at + Vector3(0, 1.98, 0.20),
		Vector3(0.38, 0.13, 0.38))
	if detail_quality == 0 and torch_lights.size() >= 6:
		return
	var light: OmniLight3D = OmniLight3D.new()
	light.name = "Blue brazier glow" if magic else "Warm brazier glow"
	light.position = at + Vector3(0, 2.23, 0.40)
	light.light_color = Color("#9880e7") if magic else Color("#ffb46d")
	light.light_energy = 1.0
	light.omni_range = 6.0
	light.shadow_enabled = false
	add_child(light)
	torch_lights.append(light)


func _tune_original_lighting() -> void:
	if not brighten_room_lighting:
		return
	for node in generator.get_children():
		if node is WorldEnvironment:
			var world: WorldEnvironment = node as WorldEnvironment
			var setting: Environment = world.environment
			if setting != null:
				setting.ambient_light_energy = 0.68
		elif node is DirectionalLight3D:
			var light: DirectionalLight3D = node as DirectionalLight3D
			light.light_energy = 0.78


func _add_blocking_prop(at: Vector3, dimensions: Vector3) -> void:
	# One approximate collider per major piece, NOT one collider per plank.
	# All colliders stay at x/z ~= +/-4, away from the 4m-wide center paths.
	if not enable_prop_collisions:
		return
	var solid: StaticBody3D = StaticBody3D.new()
	solid.name = "Dungeon furnishing collision"
	solid.position = at
	var collider: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = dimensions
	collider.shape = shape
	solid.add_child(collider)
	add_child(solid)


func _pile_crates(at: Vector3) -> void:
	for i in range(3):
		var dx: float = float(i % 2) * 0.72
		var dz: float = float(i / 2) * 0.75
		var y: float = 0.34 if i < 2 else 1.01
		var p: Vector3 = at + Vector3(dx, y, dz)
		_box("wood", p, Vector3(0.68, 0.65, 0.68), 0.10 * float(i))
		for b in [-0.24, 0.24]:
			_box("wood3", p + Vector3(0, b, 0.36), Vector3(0.72, 0.055, 0.055))
			_box("iron2", p + Vector3(b, 0, -0.36), Vector3(0.043, 0.67, 0.055))
	_add_blocking_prop(at + Vector3(0.3, 0.68, 0.25), Vector3(1.54, 1.37, 1.5))


func _barrel(at: Vector3) -> void:
	_cylinder("wood", at + Vector3(0, 0.50, 0), 0.40, 0.96)
	_cylinder("iron2", at + Vector3(0, 0.28, 0), 0.415, 0.11)
	_cylinder("iron2", at + Vector3(0, 0.76, 0), 0.415, 0.11)
	_cylinder("wood2", at + Vector3(0, 1.01, 0), 0.34, 0.055)
	_orb("iron", at + Vector3(0.13, 1.05, 0.08), Vector3(0.065, 0.05, 0.065))


func _banner(at: Vector3, cloth: String) -> void:
	_box("iron", at + Vector3(0, 1.85, 0), Vector3(1.25, 0.075, 0.12))
	_box(cloth, at + Vector3(0, 1.25, 0.05), Vector3(0.96, 1.22, 0.09))
	_box("gold", at + Vector3(0, 1.32, 0.105), Vector3(0.12, 0.82, 0.04))
	_orb("gold", at + Vector3(0, 0.92, 0.1), Vector3(0.26, 0.20, 0.055))
	for x in [-0.38, 0.38]:
		_box("bronze", at + Vector3(x, 0.68, 0.04), Vector3(0.07, 0.28, 0.06))


func _bench(at: Vector3) -> void:
	_box("wood", at + Vector3(0, 0.55, 0), Vector3(1.7, 0.20, 0.62))
	for x in [-0.65, 0.65]:
		_box("wood2", at + Vector3(x, 0.26, 0), Vector3(0.22, 0.51, 0.55))
	_box("iron2", at + Vector3(0, 0.62, 0), Vector3(1.64, 0.033, 0.10))


func _sarcophagus(at: Vector3) -> void:
	_box("stone0", at + Vector3(0, 0.32, 0), Vector3(1.60, 0.59, 2.50))
	_box("stone3", at + Vector3(0, 0.70, 0), Vector3(1.75, 0.21, 2.65))
	_box("stone4", at + Vector3(0, 0.85, 0), Vector3(1.10, 0.09, 1.78))
	_orb("bone", at + Vector3(0, 0.98, -0.55), Vector3(0.37, 0.17, 0.42))
	_box("iron", at + Vector3(0, 0.95, 0.32), Vector3(0.12, 0.06, 0.68))
	_box("bronze", at + Vector3(0, 0.98, 0.22), Vector3(0.45, 0.045, 0.10))
	_add_blocking_prop(at + Vector3(0, 0.37, 0), Vector3(1.64, 0.75, 2.51))


func _weapon_rack(at: Vector3) -> void:
	_box("wood2", at + Vector3(0, 1.18, 0), Vector3(2.45, 2.1, 0.21))
	for y in [0.52, 1.07, 1.75]:
		_box("wood3", at + Vector3(0, y, 0.14), Vector3(2.4, 0.14, 0.22))
	for x in [-0.76, -0.25, 0.31, 0.82]:
		_box("iron", at + Vector3(x, 1.39, 0.22), Vector3(0.075, 1.25, 0.055))
		_box("bronze", at + Vector3(x, 0.93, 0.22), Vector3(0.29, 0.085, 0.14))
		_orb("gold", at + Vector3(x, 1.98, 0.23), Vector3(0.12, 0.13, 0.07))
	_add_blocking_prop(at + Vector3(0, 1.05, 0), Vector3(2.4, 2.1, 0.45))


func _bookcase(at: Vector3) -> void:
	_box("wood2", at + Vector3(0, 1.40, 0), Vector3(2.35, 2.77, 0.60))
	for y in [0.52, 1.23, 1.94, 2.63]:
		_box("wood3", at + Vector3(0, y, 0.34), Vector3(2.39, 0.13, 0.65))
	for y in [0.84, 1.55, 2.27]:
		for i in range(11):
			var color: String = ["cloth_red", "cloth_blue", "cloth_purple",
				"parchment", "moss"][randomizer.randi_range(0, 4)]
			var h: float = randomizer.randf_range(0.36, 0.57)
			_box(color, at + Vector3(-0.98 + float(i) * 0.19,
				y + (0.54 - h) * 0.5, 0.39), Vector3(0.16, h, 0.18))
	_add_blocking_prop(at + Vector3(0, 1.35, 0), Vector3(2.37, 2.70, 0.72))


func _iron_cage(at: Vector3) -> void:
	_box("stone4", at + Vector3(0, 0.09, 0), Vector3(2.4, 0.17, 2.1))
	_box("iron2", at + Vector3(0, 2.3, 0), Vector3(2.42, 0.16, 2.1))
	for x in [-1.05, -0.70, -0.35, 0.0, 0.35, 0.7, 1.05]:
		_box("iron", at + Vector3(x, 1.25, 1.03), Vector3(0.075, 2.3, 0.08))
	for z in [-0.96, -0.55, -0.14, 0.27, 0.68, 0.96]:
		_box("iron", at + Vector3(-1.16, 1.25, z), Vector3(0.075, 2.3, 0.075))
	for y in [0.45, 1.64]:
		_box("iron2", at + Vector3(0, y, 1.04), Vector3(2.3, 0.10, 0.10))
	_add_blocking_prop(at + Vector3(0, 1.15, 0), Vector3(2.4, 2.3, 2.1))


func _anvil(at: Vector3) -> void:
	_box("wood2", at + Vector3(0, 0.42, 0), Vector3(1.02, 0.81, 0.94))
	_box("iron", at + Vector3(0, 0.94, 0), Vector3(1.30, 0.34, 0.67))
	_box("iron", at + Vector3(-0.78, 0.96, 0), Vector3(0.48, 0.15, 0.24))
	_orb("iron2", at + Vector3(-1.05, 0.96, 0), Vector3(0.22, 0.16, 0.17))
	_add_blocking_prop(at + Vector3(0, 0.56, 0), Vector3(1.4, 1.12, 1.0))


func _altar(at: Vector3, magic: bool = false) -> void:
	_cylinder("stone3", at + Vector3(0, 0.26, 0), 1.02, 0.48)
	_cylinder("stone4", at + Vector3(0, 0.66, 0), 0.79, 0.32)
	_cylinder("bronze", at + Vector3(0, 0.85, 0), 0.67, 0.09)
	_orb("aqua" if magic else "gold", at + Vector3(0, 1.15, 0),
		Vector3(0.62, 0.64, 0.62))
	for i in range(6):
		var angle: float = float(i) * TAU / 6.0
		var x: float = cos(angle) * 0.64
		var z: float = sin(angle) * 0.64
		_orb("gold", at + Vector3(x, 0.94, z), Vector3(0.10, 0.08, 0.10))
	_add_blocking_prop(at + Vector3(0, 0.50, 0), Vector3(2.0, 1.0, 2.0))


func _chain(at: Vector3) -> void:
	for i in range(6):
		_orb("iron", at + Vector3(0, -float(i) * 0.19, 0), Vector3(0.17, 0.25, 0.13))
		_orb("dark", at + Vector3(0, -float(i) * 0.19, 0), Vector3(0.08, 0.14, 0.15))


func _bones(at: Vector3) -> void:
	for i in range(4):
		var shift: Vector3 = Vector3(randomizer.randf_range(-0.48, 0.48),
			0.13, randomizer.randf_range(-0.38, 0.38))
		_orb("bone", at + shift, Vector3(0.48, 0.11, 0.12))
	_orb("bone", at + Vector3(0.25, 0.20, 0.12), Vector3(0.38, 0.35, 0.32))
	_orb("dark", at + Vector3(0.25, 0.23, 0.29), Vector3(0.17, 0.08, 0.035))


func _rune_circle(at: Vector3, tint: String) -> void:
	# Flat projected geometric runes. No collision near exit or player spawn.
	for i in range(16):
		var angle: float = float(i) * TAU / 16.0
		var x: float = cos(angle) * 1.88
		var z: float = sin(angle) * 1.88
		_box(tint, at + Vector3(x, 0.064, z),
			Vector3(0.14, 0.022, 0.42), -angle)
	for i in range(8):
		var angle: float = float(i) * TAU / 8.0
		_orb(tint, at + Vector3(cos(angle) * 1.33, 0.070, sin(angle) * 1.33),
			Vector3(0.13, 0.032, 0.13))
	_box(tint, at + Vector3(0, 0.066, 0), Vector3(1.1, 0.020, 0.10))
	_box(tint, at + Vector3(0, 0.067, 0), Vector3(0.10, 0.020, 1.1))


func _entry_room(center: Vector3) -> void:
	_pile_crates(center + Vector3(-5.2, 0, 3.5))
	_barrel(center + Vector3(4.5, 0, 3.2))
	_barrel(center + Vector3(5.35, 0, 3.15))
	_banner(center + Vector3(-4.2, 0, -7.48), "cloth_blue")
	_banner(center + Vector3(2.65, 0, -7.48), "cloth_red")
	_bench(center + Vector3(-4.25, 0, -4.0))


func _crypt_room(center: Vector3) -> void:
	_sarcophagus(center + Vector3(-4.5, 0, 3.7))
	_sarcophagus(center + Vector3(4.5, 0, 3.6))
	_bones(center + Vector3(-4.3, 0, -3.8))
	_orb("moss", center + Vector3(-6.5, 0.14, 3.2), Vector3(0.60, 0.21, 0.34))
	_banner(center + Vector3(-3.75, 0, -7.48), "cloth_purple")


func _armory_room(center: Vector3) -> void:
	_weapon_rack(center + Vector3(-4.25, 0, -6.30))
	_weapon_rack(center + Vector3(4.25, 0, -6.30))
	_pile_crates(center + Vector3(-4.7, 0, 3.65))
	_barrel(center + Vector3(4.35, 0, 3.1))
	_banner(center + Vector3(0, 0, -7.48), "cloth_red")


func _library_room(center: Vector3) -> void:
	_bookcase(center + Vector3(-4.15, 0, -6.35))
	_bookcase(center + Vector3(4.15, 0, -6.35))
	_bench(center + Vector3(-4.4, 0, 3.75))
	_pile_crates(center + Vector3(4.4, 0, 3.25))
	_orb("parchment", center + Vector3(-4.0, 0.69, 3.75), Vector3(0.37, 0.07, 0.13))


func _prison_room(center: Vector3) -> void:
	_iron_cage(center + Vector3(-4.6, 0, 3.7))
	_bench(center + Vector3(4.1, 0, 3.6))
	_bones(center + Vector3(-4.5, 0, -3.8))
	for x in [-5.3, 5.1]:
		_chain(center + Vector3(x, 2.54, -6.95))
	_banner(center + Vector3(3.6, 0, -7.48), "cloth_red")


func _forge_room(center: Vector3) -> void:
	_anvil(center + Vector3(-4.45, 0, 3.65))
	_pile_crates(center + Vector3(4.0, 0, 2.95))
	_barrel(center + Vector3(5.4, 0, 3.5))
	_box("stone0", center + Vector3(-4.8, 0.55, -5.6), Vector3(1.35, 1.1, 1.0))
	_orb("ember", center + Vector3(-4.8, 1.15, -5.6), Vector3(0.71, 0.34, 0.55))
	_add_blocking_prop(center + Vector3(-4.8, 0.55, -5.6), Vector3(1.35, 1.10, 1.0))


func _shrine_room(center: Vector3) -> void:
	_altar(center + Vector3(-4.35, 0, 3.75), true)
	_rune_circle(center, "aqua")
	_banner(center + Vector3(-3.9, 0, -7.48), "cloth_purple")
	_banner(center + Vector3(2.9, 0, -7.48), "cloth_blue")
	_orb("violet", center + Vector3(4.6, 0.55, 3.5), Vector3(0.33, 0.62, 0.33))
	_cylinder("stone4", center + Vector3(4.6, 0.24, 3.5), 0.5, 0.46)


func _ruins_room(center: Vector3) -> void:
	for i in range(16 if detail_quality == 2 else 9):
		var x: float = randomizer.randf_range(-6.5, -3.0)
		var z: float = randomizer.randf_range(2.7, 6.5)
		_box("stone3", center + Vector3(x, 0.14, z),
			Vector3(randomizer.randf_range(0.18, 0.8), 0.18,
				randomizer.randf_range(0.2, 0.74)), randomizer.randf_range(-1.0, 1.0))
	_bones(center + Vector3(4.4, 0, 3.8))
	_banner(center + Vector3(3.65, 0, -7.48), "cloth_red")
	_barrel(center + Vector3(4.3, 0, 2.9))
	_orb("moss2", center + Vector3(-4.4, 0.13, -3.85), Vector3(0.8, 0.16, 0.5))


func _sanctum_room(center: Vector3) -> void:
	# The generator's gold exit at (0, 0) remains COMPLETELY unobstructed.
	_altar(center + Vector3(-4.15, 0, 3.6), true)
	_banner(center + Vector3(-4.5, 0, -7.48), "cloth_purple")
	_banner(center + Vector3(3.0, 0, -7.48), "cloth_blue")
	_barrel(center + Vector3(4.6, 0, 3.35))
	_orb("violet", center + Vector3(4.7, 0.70, -4.35), Vector3(0.48, 0.81, 0.48))
	_cylinder("stone3", center + Vector3(4.7, 0.23, -4.35), 0.48, 0.43)


func _decorate_corridors(cells: Array) -> void:
	for c in cells:
		var cell: Vector2i = c
		for direction in [Vector2i(1, 0), Vector2i(0, 1)]:
			if not _linked(cell, cell + direction):
				continue
			var middle: Vector3 = _center(cell) + Vector3(
				float(direction.x) * SPACING * 0.5, 0.0,
				float(direction.y) * SPACING * 0.5
			)
			for step in [-3.0, -1.0, 1.0, 3.0]:
				var spot: Vector3 = middle + Vector3(float(direction.x) * step,
					0.057, float(direction.y) * step)
				_box("stone2" if randomizer.randf() < 0.5 else "stone3",
					spot, Vector3(1.74, 0.024, 1.74))
			# Decorate existing parapet tops, leaving floor center clear.
			for sign in [-1.0, 1.0]:
				var cap: Vector3 = middle + Vector3(0, 2.13, sign * 2.4)
				var size: Vector3 = Vector3(7.8, 0.17, 0.75)
				if direction.y != 0:
					cap = middle + Vector3(sign * 2.4, 2.13, 0)
					size = Vector3(0.75, 0.17, 7.8)
				_box("stone4", cap, size)
				if detail_quality > 0:
					_orb("moss", cap + Vector3(0.0, 0.10, 0.0),
						Vector3(0.67, 0.12, 0.48))


func _accent_existing_pillars_and_chests() -> void:
	# The generator creates its own columns/chests; we decorate those exact
	# positions rather than guessing and accidentally making duplicate props.
	for node in generator.get_children():
		if not (node is Node3D):
			continue
		var block: Node3D = node as Node3D
		if String(block.name).begins_with("Column") and not String(block.name).begins_with("Column cap") and not String(block.name).begins_with("Column foot"):
			var p: Vector3 = block.position
			_box("stone4", Vector3(p.x, 0.45, p.z), Vector3(1.12, 0.12, 1.12))
			_box("bronze", Vector3(p.x, 1.32, p.z), Vector3(1.05, 0.08, 1.05))
			_box("stone3", Vector3(p.x, 2.30, p.z), Vector3(1.05, 0.11, 1.05))
		elif String(block.name).begins_with("Loot chest body"):
			var base: Vector3 = block.position - Vector3(0, 0.42, 0)
			# The original generator owns chest collision; added trim is visual.
			for x in [-0.42, 0.42]:
				_box("iron2", base + Vector3(x, 0.64, 0),
					Vector3(0.12, 0.60, 0.92))
				_orb("bronze", base + Vector3(x, 0.78, 0.49),
					Vector3(0.11, 0.10, 0.08))
			_box("wood2", base + Vector3(0, 1.01, 0), Vector3(1.28, 0.09, 0.82))
			_box("bronze", base + Vector3(0, 1.06, 0), Vector3(0.11, 0.07, 0.90))
			_orb("gold", base + Vector3(0, 0.63, 0.51), Vector3(0.16, 0.16, 0.11))
