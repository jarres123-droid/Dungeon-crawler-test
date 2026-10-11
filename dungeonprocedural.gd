extends Node3D

# PROCEDURAL DUNGEON v1 -- Godot 4 / Android
# Replace the SCRIPT on your existing Dungeon root with this file.
# Keep Player, FollowCamera, DungeonCombat, DungeonVisuals and CombatPolish.
# Their scripts remain unchanged. The old fixed-room DungeonDetails script
# is disabled at runtime because its geometry belongs to the original room.

@export_range(7, 16, 1) var rooms_to_generate: int = 10
@export_range(0.0, 0.6, 0.05) var extra_connection_chance: float = 0.22
# Zero keeps normal runs random. Set a positive value to reproduce a debug layout.
@export_range(0, 2147483647, 1) var debug_seed: int = 0

const ROOM_SIZE: float = 16.0
const ROOM_HALF: float = 8.0
const ROOM_SPACING: float = 24.0
const CORRIDOR_LENGTH: float = 8.0
const DOOR_WIDTH: float = 4.0
const WALL_THICKNESS: float = 0.75
const MAP_GRID_RADIUS: int = 2
const STEP_DIRECTIONS = [
	Vector2i(1, 0), Vector2i(-1, 0),
	Vector2i(0, 1), Vector2i(0, -1)
]

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var active_seed: int = 0
var dungeon_cells: Array[Vector2i] = []
var occupied: Dictionary = {}
var connections: Dictionary = {}
var exit_cell: Vector2i = Vector2i.ZERO
var floor_number: int = 1
var map_player: ColorRect
var map_panel: Panel
var exit_trigger: Area3D
var descending: bool = false
var tile_batches: Array = [[], [], [], []]
var tile_materials: Array[StandardMaterial3D] = []
var shadowed_torch_count: int = 0
var stone_material: StandardMaterial3D
var low_stone_material: StandardMaterial3D
var floor_material: StandardMaterial3D
var corridor_material: StandardMaterial3D
var pillar_material: StandardMaterial3D
var wood_material: StandardMaterial3D
var iron_material: StandardMaterial3D
var flame_material: StandardMaterial3D


func _enter_tree() -> void:
	# This old script draws only at (0,0) and creates a chest collider there.
	# Disabling it before child _ready() prevents a ghost room and stray wall art.
	var old_details: Node3D = get_node_or_null("DungeonDetails") as Node3D
	if old_details != null:
		old_details.set_script(null)
		old_details.visible = false


func _ready() -> void:
	if get_tree().has_meta("dungeon_floor_number"):
		floor_number = int(get_tree().get_meta("dungeon_floor_number"))
	_configure_rng()
	_prepare_materials()
	_generate_connected_plan()
	if not validate_connectivity():
		push_error("Procedural dungeon generation produced a disconnected room plan (seed %d)." % active_seed)
		return
	_create_environment()
	_create_rooms()
	_create_corridors()
	_create_tile_batch_meshes()
	_create_surface_return()
	_create_exit()
	_create_mini_map()
	print("Procedural dungeon floor %d: %d connected rooms; exit at %s; seed %d" % [
		floor_number, dungeon_cells.size(), str(exit_cell), active_seed
	])


func _configure_rng() -> void:
	if debug_seed > 0:
		active_seed = debug_seed
		rng.seed = active_seed
	else:
		rng.randomize()
		active_seed = rng.seed


func get_active_seed() -> int:
	return active_seed


func _process(_delta: float) -> void:
	if map_player == null:
		return
	var player: Node3D = get_node_or_null("Player") as Node3D
	if player == null:
		return
	# Continuous player dot, including positions between room centers.
	var p: Vector3 = player.global_position
	map_player.position = Vector2(22.0, 33.0) + Vector2(
		(p.x / ROOM_SPACING + 2.0) * 30.0,
		(p.z / ROOM_SPACING + 2.0) * 30.0
	)


func _generate_connected_plan() -> void:
	dungeon_cells.clear()
	occupied.clear()
	connections.clear()
	dungeon_cells.append(Vector2i.ZERO)
	occupied[Vector2i.ZERO] = true

	# Every new room must attach to an already-reachable room.
	# This creates a connected spanning tree by construction.
	var tries: int = 0
	while dungeon_cells.size() < rooms_to_generate and tries < 1500:
		tries += 1
		var parent: Vector2i = dungeon_cells[rng.randi_range(0, dungeon_cells.size() - 1)]
		var candidates: Array = STEP_DIRECTIONS.duplicate()
		_shuffle_with_rng(candidates)
		for step in candidates:
			var direction: Vector2i = step
			var next_cell: Vector2i = parent + direction
			if absi(next_cell.x) > MAP_GRID_RADIUS or absi(next_cell.y) > MAP_GRID_RADIUS:
				continue
			if occupied.has(next_cell):
				continue
			occupied[next_cell] = true
			dungeon_cells.append(next_cell)
			_open_connection(parent, next_cell)
			break

	# Optional loops give the dungeon alternative routes.
	for cell in dungeon_cells:
		for direction in [Vector2i(1, 0), Vector2i(0, 1)]:
			var neighbor: Vector2i = cell + direction
			if occupied.has(neighbor) and not _are_connected(cell, neighbor):
				if rng.randf() < extra_connection_chance:
					_open_connection(cell, neighbor)

	# Place the exit in the room furthest from the spawn by walkable doors.
	var distances: Dictionary = {}
	var queue: Array[Vector2i] = [Vector2i.ZERO]
	distances[Vector2i.ZERO] = 0
	var index: int = 0
	while index < queue.size():
		var current: Vector2i = queue[index]
		index += 1
		for step in STEP_DIRECTIONS:
			var neighbor: Vector2i = current + step
			if _are_connected(current, neighbor) and not distances.has(neighbor):
				distances[neighbor] = int(distances[current]) + 1
				queue.append(neighbor)

	exit_cell = Vector2i.ZERO
	for cell in dungeon_cells:
		if int(distances[cell]) > int(distances[exit_cell]):
			exit_cell = cell


func _shuffle_with_rng(values: Array) -> void:
	# Array.shuffle() uses the global RNG and would break fixed-seed layouts.
	for index in range(values.size() - 1, 0, -1):
		var swap_index: int = rng.randi_range(0, index)
		var value = values[index]
		values[index] = values[swap_index]
		values[swap_index] = value


func validate_connectivity() -> bool:
	if dungeon_cells.is_empty() or not occupied.has(Vector2i.ZERO):
		return false

	var reachable: Dictionary = {Vector2i.ZERO: true}
	var queue: Array[Vector2i] = [Vector2i.ZERO]
	var index: int = 0
	while index < queue.size():
		var current: Vector2i = queue[index]
		index += 1
		for direction in STEP_DIRECTIONS:
			var neighbor: Vector2i = current + direction
			if occupied.has(neighbor) and _are_connected(current, neighbor) and not reachable.has(neighbor):
				reachable[neighbor] = true
				queue.append(neighbor)

	return reachable.size() == dungeon_cells.size()


func _edge_key(a: Vector2i, b: Vector2i) -> String:
	if a.x > b.x or (a.x == b.x and a.y > b.y):
		var temp: Vector2i = a
		a = b
		b = temp
	return "%d,%d-%d,%d" % [a.x, a.y, b.x, b.y]


func _open_connection(a: Vector2i, b: Vector2i) -> void:
	connections[_edge_key(a, b)] = true


func _are_connected(a: Vector2i, b: Vector2i) -> bool:
	return connections.has(_edge_key(a, b))


func _room_center(cell: Vector2i) -> Vector3:
	return Vector3(float(cell.x) * ROOM_SPACING, 0.0, float(cell.y) * ROOM_SPACING)


func _prepare_materials() -> void:
	floor_material = _material(Color("#333b43"))
	corridor_material = _material(Color("#41474e"))
	stone_material = _material(Color("#596167"))
	low_stone_material = _material(Color("#404b54"))
	pillar_material = _material(Color("#8b857d"))
	wood_material = _material(Color("#755039"))
	iron_material = _material(Color("#a29b7d"))
	flame_material = _material(Color("#ffae40"))
	flame_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame_material.emission_enabled = true
	flame_material.emission = Color("#ff8c31")
	flame_material.emission_energy_multiplier = 2.0
	for shade in ["#4b555d", "#596168", "#424a50", "#66615b"]:
		tile_materials.append(_material(Color(shade)))


func _material(tint: Color) -> StandardMaterial3D:
	var result: StandardMaterial3D = StandardMaterial3D.new()
	result.albedo_color = tint
	result.roughness = 0.92
	return result


func _asset(kind: String, at: Vector3, yaw: float = 0.0) -> Node3D:
	var scene: PackedScene = load("res://assets/dungeon/%s.tscn" % kind)
	var instance := scene.instantiate() as Node3D
	instance.position = at
	instance.rotation.y = yaw
	add_child(instance)
	return instance


func _make_block(label: String, location: Vector3, dimensions: Vector3,
				 surface: Material, collide: bool = true) -> Node3D:
	var root: Node3D
	if collide:
		var solid: StaticBody3D = StaticBody3D.new()
		var shape: BoxShape3D = BoxShape3D.new()
		shape.size = dimensions
		var collision: CollisionShape3D = CollisionShape3D.new()
		collision.shape = shape
		solid.add_child(collision)
		root = solid
	else:
		root = Node3D.new()
	root.name = label
	root.position = location
	add_child(root)
	var cube: BoxMesh = BoxMesh.new()
	cube.size = dimensions
	cube.material = surface
	var visual: MeshInstance3D = MeshInstance3D.new()
	visual.mesh = cube
	root.add_child(visual)
	return root


func _create_rooms() -> void:
	for cell in dungeon_cells:
		var center: Vector3 = _room_center(cell)
		_make_block("Floor %s" % str(cell), center + Vector3(0.0, -0.25, 0.0),
			Vector3(ROOM_SIZE, 0.5, ROOM_SIZE), floor_material)
		_add_floor_tiles(center)
		for step in STEP_DIRECTIONS:
			_build_room_side(center, step, _are_connected(cell, cell + step))
		# Four corner pillars only in occasional rooms; doors stay clear.
		if cell != Vector2i.ZERO and rng.randf() < 0.65:
			_asset("column_damaged" if rng.randf() < 0.35 else "column", center + Vector3(-5.0, 0.0, -5.0))
			_asset("wall_buttress", center + Vector3(5.8, 0.0, 5.0), PI * .5)
		if cell != Vector2i.ZERO and rng.randf() < 0.48:
			_asset("dungeon_table", center + Vector3(2.8, 0.0, 2.5), rng.randf_range(-.3, .3))
			_asset("rubble", center + Vector3(-2.8, 0.0, 3.8), rng.randf_range(0.0, PI))
		if cell != Vector2i.ZERO and cell != exit_cell and rng.randf() < 0.55:
			_build_chest(center + Vector3(4.0, 0.0, -4.0))
		if cell == Vector2i.ZERO or cell == exit_cell or rng.randf() < 0.25:
			_build_torch(center + Vector3(-5.75, 0.0, -6.7))


func _build_room_side(center: Vector3, direction: Vector2i, has_door: bool) -> void:
	# The near two walls are low for a readable isometric camera.
	var height: float = 1.30 if direction.x > 0 or direction.y > 0 else 3.0
	var location: Vector3 = center + Vector3(
		float(direction.x) * ROOM_HALF, height * 0.5,
		float(direction.y) * ROOM_HALF
	)
	var surface: Material = low_stone_material if height < 2.0 else stone_material
	var full_size: Vector3 = Vector3(ROOM_SIZE, height, WALL_THICKNESS)
	if direction.x != 0:
		full_size = Vector3(WALL_THICKNESS, height, ROOM_SIZE)
	if not has_door:
		_make_block("Solid room wall", location, full_size, surface)
		return

	var section_length: float = (ROOM_SIZE - DOOR_WIDTH) * 0.5
	var section_size: Vector3 = Vector3(section_length, height, WALL_THICKNESS)
	var offset: Vector3 = Vector3((ROOM_SIZE + DOOR_WIDTH) * 0.25, 0.0, 0.0)
	if direction.x != 0:
		section_size = Vector3(WALL_THICKNESS, height, section_length)
		offset = Vector3(0.0, 0.0, (ROOM_SIZE + DOOR_WIDTH) * 0.25)
	_make_block("Door wall A", location - offset, section_size, surface)
	_make_block("Door wall B", location + offset, section_size, surface)
	if height >= 2.0:
		var lintel_size: Vector3 = Vector3(DOOR_WIDTH, 0.4, WALL_THICKNESS)
		if direction.x != 0:
			lintel_size = Vector3(WALL_THICKNESS, 0.4, DOOR_WIDTH)
		_make_block("Stone door lintel", location + Vector3(0.0, 1.32, 0.0),
			lintel_size, pillar_material, false)


func _create_corridors() -> void:
	# Generate each edge only once (+X or +Z).
	for cell in dungeon_cells:
		for direction in [Vector2i(1, 0), Vector2i(0, 1)]:
			var other: Vector2i = cell + direction
			if not _are_connected(cell, other):
				continue
			var center: Vector3 = _room_center(cell) + Vector3(
				float(direction.x) * ROOM_SPACING * 0.5, 0.0,
				float(direction.y) * ROOM_SPACING * 0.5
			)
			var floor_size: Vector3 = Vector3(CORRIDOR_LENGTH, 0.5, DOOR_WIDTH)
			if direction.y != 0:
				floor_size = Vector3(DOOR_WIDTH, 0.5, CORRIDOR_LENGTH)
			_make_block("Corridor floor", center + Vector3(0.0, -0.25, 0.0),
				floor_size, corridor_material)
			_asset("corridor_support", center, PI * .5 if direction.x != 0 else 0.0)
			for sign in [-1.0, 1.0]:
				var edge: Vector3 = Vector3(0.0, 1.05, sign * 2.4)
				var size: Vector3 = Vector3(CORRIDOR_LENGTH, 2.1, 0.72)
				if direction.y != 0:
					edge = Vector3(sign * 2.4, 1.05, 0.0)
					size = Vector3(0.72, 2.1, CORRIDOR_LENGTH)
				_make_block("Corridor parapet", center + edge, size, stone_material)


func _add_floor_tiles(center: Vector3) -> void:
	# Four MultiMesh drawables cover ALL rooms, much cheaper than
	# hundreds of individual tile nodes/colliders on an Android phone.
	for ix in range(8):
		for iz in range(8):
			var at: Vector3 = center + Vector3(
				-7.0 + float(ix) * 2.0, 0.021,
				-7.0 + float(iz) * 2.0
			)
			var group: int = rng.randi_range(0, 3)
			tile_batches[group].append(Transform3D(Basis.IDENTITY, at))


func _create_tile_batch_meshes() -> void:
	for group in range(4):
		var tile_mesh: BoxMesh = BoxMesh.new()
		tile_mesh.size = Vector3(1.94, 0.042, 1.94)
		tile_mesh.material = tile_materials[group]
		var multi: MultiMesh = MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = tile_mesh
		multi.instance_count = tile_batches[group].size()
		for index in range(tile_batches[group].size()):
			multi.set_instance_transform(index, tile_batches[group][index])
		var visual: MultiMeshInstance3D = MultiMeshInstance3D.new()
		visual.name = "Batched floor tiles %d" % group
		visual.multimesh = multi
		add_child(visual)


func _build_pillar(at: Vector3) -> void:
	_make_block("Column", at + Vector3(0.0, 1.38, 0.0),
		Vector3(0.95, 2.75, 0.95), pillar_material)
	_make_block("Column cap", at + Vector3(0.0, 2.65, 0.0),
		Vector3(1.30, 0.25, 1.30), iron_material, false)
	_make_block("Column foot", at + Vector3(0.0, 0.12, 0.0),
		Vector3(1.22, 0.22, 1.22), iron_material, false)


func _build_chest(at: Vector3) -> void:
	_make_block("Loot chest body", at + Vector3(0.0, 0.42, 0.0),
		Vector3(1.18, 0.80, 0.80), wood_material)
	_make_block("Loot chest lid", at + Vector3(0.0, 0.88, 0.0),
		Vector3(1.30, 0.20, 0.91), iron_material, false)
	_make_block("Chest lock", at + Vector3(0.0, 0.53, 0.43),
		Vector3(0.20, 0.23, 0.12), iron_material, false)


func _build_torch(at: Vector3) -> void:
	_asset("torch", at + Vector3(0.0, 1.0, 0.0))
	var flame: MeshInstance3D = MeshInstance3D.new()
	var shape: SphereMesh = SphereMesh.new()
	shape.radius = 0.16
	shape.height = 0.43
	shape.material = flame_material
	flame.mesh = shape
	flame.position = at + Vector3(0.0, 2.32, 0.0)
	add_child(flame)
	var glow: OmniLight3D = OmniLight3D.new()
	glow.position = flame.position
	glow.light_color = Color("#ffad65")
	glow.light_energy = 1.65
	glow.omni_range = 7.8
	glow.omni_attenuation = 1.35
	# Only the first two hero-area torches cast shadows: high impact, bounded cost.
	glow.shadow_enabled = shadowed_torch_count < 2
	if glow.shadow_enabled:
		shadowed_torch_count += 1
	add_child(glow)


func _create_environment() -> void:
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	sun.light_color = Color("#8ca9c2")
	sun.light_energy = 0.54
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 52.0
	add_child(sun)
	var sky: WorldEnvironment = WorldEnvironment.new()
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#0d131b")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#557087")
	environment.ambient_light_energy = 0.30
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.12
	environment.adjustment_enabled = true
	environment.adjustment_brightness = 1.02
	environment.adjustment_contrast = 1.26
	environment.adjustment_saturation = 1.10
	environment.glow_enabled = true
	environment.glow_intensity = 0.72
	environment.glow_bloom = 0.12
	environment.fog_enabled = true
	environment.fog_light_color = Color("#172733")
	environment.fog_light_energy = 0.48
	environment.fog_density = 0.015
	environment.fog_height = 1.5
	environment.fog_height_density = 0.12
	sky.environment = environment
	add_child(sky)


func _create_surface_return() -> void:
	# The entry room remains the stable bridge back to the separate hub scene.
	# This is deliberately away from the player spawn and combat lane so scene
	# travel can never fire accidentally when a floor loads.
	var ladder_position := Vector3(-5.8, 0.0, 5.8)
	var oak := _material(Color("#8b633f"))
	var dark_iron := _material(Color("#50483f"))
	_make_block("Surface ladder left rail", ladder_position + Vector3(-0.58, 1.25, 0.0),
		Vector3(0.18, 2.5, 0.18), oak, false)
	_make_block("Surface ladder right rail", ladder_position + Vector3(0.58, 1.25, 0.0),
		Vector3(0.18, 2.5, 0.18), oak, false)
	for rung_index in range(6):
		_make_block("Surface ladder rung", ladder_position + Vector3(0.0, 0.32 + rung_index * 0.38, 0.0),
			Vector3(1.28, 0.12, 0.16), oak, false)
	_make_block("Ladder stone surround", ladder_position + Vector3(0.0, 0.12, 0.0),
		Vector3(2.1, 0.22, 1.45), dark_iron, false)

	var return_area := Area3D.new()
	return_area.name = "Return to village ladder"
	return_area.position = ladder_position + Vector3(0.0, 0.9, -0.65)
	return_area.collision_layer = 0
	return_area.collision_mask = 1
	var return_shape := BoxShape3D.new()
	return_shape.size = Vector3(2.2, 1.8, 2.0)
	var return_collision := CollisionShape3D.new()
	return_collision.shape = return_shape
	return_area.add_child(return_collision)
	add_child(return_area)
	return_area.body_entered.connect(_on_surface_return_reached)
	_create_world_label("SURFACE", ladder_position + Vector3(0.0, 2.9, 0.0), Color("#a9d9cf"))


func _create_world_label(words: String, at: Vector3, tint: Color) -> void:
	var label := Label3D.new()
	label.text = words
	label.position = at
	label.modulate = tint
	label.font_size = 38
	label.outline_size = 8
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	add_child(label)


func _on_surface_return_reached(body: Node3D) -> void:
	if body.name != "Player" or descending:
		return
	descending = true
	call_deferred("_return_to_village")


func _return_to_village() -> void:
	get_tree().change_scene_to_file("res://village.tscn")


func _create_exit() -> void:
	var center: Vector3 = _room_center(exit_cell)
	_asset("floor_decal", center)
	_asset("brazier", center + Vector3(-2.2, 0.0, 0.0))
	_asset("brazier", center + Vector3(2.2, 0.0, 0.0))
	var marker: MeshInstance3D = MeshInstance3D.new()
	marker.name = "Gold exit stairs"
	var base: CylinderMesh = CylinderMesh.new()
	base.top_radius = 1.3
	base.bottom_radius = 1.5
	base.height = 0.14
	base.radial_segments = 16
	var gold: StandardMaterial3D = _material(Color("#e3b957"))
	gold.emission_enabled = true
	gold.emission = Color("#a2752f")
	gold.emission_energy_multiplier = 1.1
	base.material = gold
	marker.mesh = base
	marker.position = center + Vector3(0.0, 0.09, 0.0)
	add_child(marker)
	exit_trigger = Area3D.new()
	exit_trigger.name = "Floor exit trigger"
	exit_trigger.position = center + Vector3(0.0, 1.0, 0.0)
	exit_trigger.collision_layer = 0
	exit_trigger.collision_mask = 1
	var hit_shape: SphereShape3D = SphereShape3D.new()
	hit_shape.radius = 1.25
	var trigger_shape: CollisionShape3D = CollisionShape3D.new()
	trigger_shape.shape = hit_shape
	exit_trigger.add_child(trigger_shape)
	add_child(exit_trigger)
	exit_trigger.body_entered.connect(_on_exit_reached)
	var beacon: OmniLight3D = OmniLight3D.new()
	beacon.position = center + Vector3(0.0, 1.7, 0.0)
	beacon.omni_range = 7.0
	beacon.light_color = Color("#fbd57e")
	beacon.light_energy = 1.4
	beacon.shadow_enabled = false
	add_child(beacon)


func _on_exit_reached(body: Node3D) -> void:
	if body.name != "Player" or descending:
		return
	descending = true
	# The SceneTree survives scene reload; this increments the level number.
	get_tree().set_meta("dungeon_floor_number", floor_number + 1)
	call_deferred("_reload_for_next_floor")


func _reload_for_next_floor() -> void:
	get_tree().reload_current_scene()


func _create_mini_map() -> void:
	var overlay: CanvasLayer = CanvasLayer.new()
	overlay.name = "Procedural dungeon mini map"
	overlay.layer = 5
	add_child(overlay)
	map_panel = Panel.new()
	map_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_panel.anchor_left = 1.0
	map_panel.anchor_right = 1.0
	map_panel.anchor_top = 0.0
	map_panel.anchor_bottom = 0.0
	map_panel.offset_left = -219.0
	map_panel.offset_right = -16.0
	map_panel.offset_top = 16.0
	map_panel.offset_bottom = 216.0
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.075, 0.11, 0.88)
	style.border_color = Color("#8296af")
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	map_panel.add_theme_stylebox_override("panel", style)
	overlay.add_child(map_panel)
	var caption: Label = Label.new()
	caption.text = "FLOOR %d  -  FIND EXIT" % floor_number
	caption.position = Vector2(16.0, 6.0)
	caption.add_theme_font_size_override("font_size", 16)
	caption.add_theme_color_override("font_color", Color("#f0e2be"))
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_panel.add_child(caption)
	for cell in dungeon_cells:
		var marker_color: Color = Color("#778899")
		if cell == Vector2i.ZERO:
			marker_color = Color("#74ba9b")
		if cell == exit_cell:
			marker_color = Color("#f6c66b")
		_map_rect(Vector2(22.0, 33.0) + Vector2(cell.x + 2, cell.y + 2) * 30.0,
			Vector2(17.0, 17.0), marker_color)
	for cell in dungeon_cells:
		for direction in [Vector2i(1, 0), Vector2i(0, 1)]:
			if not _are_connected(cell, cell + direction):
				continue
			var spot: Vector2 = Vector2(22.0, 33.0) + Vector2(cell.x + 2, cell.y + 2) * 30.0
			if direction.x == 1:
				_map_rect(spot + Vector2(17.0, 6.0), Vector2(13.0, 5.0), Color("#8797a7"))
			else:
				_map_rect(spot + Vector2(6.0, 17.0), Vector2(5.0, 13.0), Color("#8797a7"))
	map_player = _map_rect(Vector2(0.0, 0.0), Vector2(10.0, 10.0), Color("#65b7ff"))
	map_player.z_index = 10
	var legend: Label = Label.new()
	legend.text = "BLUE = YOU     GOLD = EXIT"
	legend.position = Vector2(15.0, 182.0)
	legend.add_theme_font_size_override("font_size", 12)
	legend.add_theme_color_override("font_color", Color("#cfdded"))
	legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_panel.add_child(legend)


func _map_rect(spot: Vector2, dimensions: Vector2, tint: Color) -> ColorRect:
	var rect: ColorRect = ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.position = spot
	rect.size = dimensions
	rect.color = tint
	map_panel.add_child(rect)
	return rect
