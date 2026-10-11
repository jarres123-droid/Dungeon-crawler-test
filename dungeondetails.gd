extends Node3D

# Dungeon visual upgrade for Godot 4.x (including the Android editor).
# Attach to a NEW Node3D child named DungeonDetails beneath Dungeon.
# Keep Dungeon.gd, Player.gd and follow_camera.gd unchanged.
# Decorative stones are batched and use the original room's collision.

var randomizer := RandomNumberGenerator.new()
var flames: Array[MeshInstance3D] = []
var fire_lights: Array[OmniLight3D] = []
var elapsed: float = 0.0


func _ready() -> void:
	randomizer.seed = 20260929
	# Child nodes become ready BEFORE Dungeon._ready() makes its walls.
	# Defer this step so the old dungeon is already present.
	call_deferred("_build_details")


func _build_details() -> void:
	_recolor_existing_geometry()
	_add_floor_tiles()
	_add_wall_bricks()
	_add_pillar_trim()
	_add_doorway_arch()
	_add_wall_torch(Vector3(-4.0, 0.0, -7.35))
	_add_wall_torch(Vector3(4.0, 0.0, -7.35))
	_add_treasure_chest()
	_set_mood_lighting()
	print("DungeonDetails: medieval dungeon decorations added.")


func _mat(color: Color, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.88
	material.metallic = metallic
	return material


func _box(label: String, center: Vector3, dimensions: Vector3, color: Color, metallic: float = 0.0) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	mesh.material = _mat(color, metallic)
	var visual := MeshInstance3D.new()
	visual.name = label
	visual.mesh = mesh
	visual.position = center
	add_child(visual)
	return visual


func _batch_boxes(label: String, dimensions: Vector3, positions: Array, tint: Color) -> void:
	if positions.is_empty():
		return
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	mesh.material = _mat(tint)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = positions.size()
	for index in range(positions.size()):
		multi.set_instance_transform(index, positions[index])
	var visual := MultiMeshInstance3D.new()
	visual.name = label
	visual.multimesh = multi
	add_child(visual)


func _recolor_existing_geometry() -> void:
	# The original StaticBody3D collisions remain unchanged.
	var recolors := {
		"Stone Floor": Color("#292e33"),
		"Back Wall": Color("#32383e"),
		"Left Wall": Color("#32383e"),
		"Right Wall": Color("#32383e"),
		"Front Left": Color("#32383e"),
		"Front Right": Color("#32383e"),
		"Stone Pillar": Color("#555c62"),
		"Treasure Platform": Color("#523b30")
	}
	for child in get_parent().get_children():
		var object_name := str(child.name)
		if child is StaticBody3D and (recolors.has(object_name) or object_name.begins_with("Stone Pillar")):
			var tint: Color = recolors.get(object_name, Color("#555c62"))
			for part in child.get_children():
				if part is MeshInstance3D:
					part.material_override = _mat(tint)


func _add_floor_tiles() -> void:
	# Four shared mesh/material sets = 64 stone tiles with just four drawables.
	var shades := [
		Color("#4f565a"), Color("#596064"),
		Color("#464d53"), Color("#62615e")
	]
	var groups: Array = [[], [], [], []]
	for x in range(8):
		for z in range(8):
			var position := Vector3(-7.0 + float(x) * 2.0, 0.009, -7.0 + float(z) * 2.0)
			var transform := Transform3D(Basis.IDENTITY, position)
			groups[randomizer.randi_range(0, 3)].append(transform)
	for i in range(4):
		_batch_boxes("Stone floor tile group %d" % i, Vector3(1.93, 0.043, 1.93), groups[i], shades[i])


func _add_wall_bricks() -> void:
	# Draw brick faces over the old collision walls without creating hundreds
	# of extra collision objects. Separate batches for X-facing and Z-facing.
	var shades := [
		Color("#5d646a"), Color("#687077"),
		Color("#4b535a"), Color("#71757a")
	]
	var along_x: Array = [[], [], [], []]
	var along_z: Array = [[], [], [], []]
	var side_rotation := Basis(Vector3.UP, PI / 2.0)
	for row in range(6):
		var height := 0.265 + float(row) * 0.48
		var stagger := 0.08 if row % 2 == 0 else -0.08
		for column in range(10):
			var line := -7.1 + float(column) * 1.57 + stagger
			_place_brick(along_x, Vector3(line, height, -7.52), Basis.IDENTITY)
			_place_brick(along_z, Vector3(-7.52, height, line), side_rotation)
			_place_brick(along_z, Vector3(7.52, height, line), side_rotation)
		# Leave the central 4m entrance clear of decorative bricks.
		for column in range(3):
			var span := float(column) * 1.71
			_place_brick(along_x, Vector3(-6.95 + span, height, 7.52), Basis.IDENTITY)
			_place_brick(along_x, Vector3(6.95 - span, height, 7.52), Basis.IDENTITY)
	for i in range(4):
		_batch_boxes("Wall bricks X group %d" % i, Vector3(1.48, 0.43, 0.12), along_x[i], shades[i])
		_batch_boxes("Wall bricks Z group %d" % i, Vector3(1.48, 0.43, 0.12), along_z[i], shades[i])


func _place_brick(groups: Array, point: Vector3, rotation: Basis) -> void:
	var selection := randomizer.randi_range(0, groups.size() - 1)
	groups[selection].append(Transform3D(rotation, point))


func _add_pillar_trim() -> void:
	for x in [-5.0, 5.0]:
		for z in [-4.0, 4.0]:
			var position := Vector3(x, 0.0, z)
			_box("Pillar foot", position + Vector3(0.0, 0.15, 0.0), Vector3(1.56, 0.28, 1.56), Color("#75787a"))
			_box("Pillar cap", position + Vector3(0.0, 2.87, 0.0), Vector3(1.64, 0.27, 1.64), Color("#85817b"))
			_box("Pillar ring", position + Vector3(0.0, 2.58, 0.0), Vector3(1.42, 0.14, 1.42), Color("#434a50"))
			# Subtle vertical stone grooves.
			for offset in [-0.36, 0.36]:
				_box("Pillar front groove", position + Vector3(offset, 1.47, 0.615), Vector3(0.065, 2.08, 0.045), Color("#3c444a"))
				_box("Pillar side groove", position + Vector3(0.615, 1.47, offset), Vector3(0.045, 2.08, 0.065), Color("#3c444a"))


func _add_doorway_arch() -> void:
	# The doorway remains open so the Player can walk through it.
	for x in [-2.23, 2.23]:
		_box("Door frame post", Vector3(x, 1.55, 7.53), Vector3(0.38, 3.10, 0.45), Color("#737679"))
		_box("Door frame foot", Vector3(x, 0.17, 7.53), Vector3(0.56, 0.34, 0.60), Color("#898682"))
	_box("Door lintel", Vector3(0.0, 3.18, 7.53), Vector3(4.94, 0.43, 0.55), Color("#85827e"))


func _add_wall_torch(location: Vector3) -> void:
	var base := location + Vector3(0.0, 1.80, 0.0)
	_box("Torch wall bracket", base, Vector3(0.31, 0.25, 0.46), Color("#322b29"), 0.4)
	_box("Torch handle", base + Vector3(0.0, 0.22, 0.24), Vector3(0.12, 0.57, 0.12), Color("#573e2a"))
	_box("Torch holder", base + Vector3(0.0, 0.49, 0.24), Vector3(0.28, 0.12, 0.28), Color("#5d5141"), 0.4)

	var fire_material := StandardMaterial3D.new()
	fire_material.albedo_color = Color("#ff9b27")
	fire_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fire_material.emission_enabled = true
	fire_material.emission = Color("#ff7c24")
	fire_material.emission_energy_multiplier = 2.0
	var flame_shape := SphereMesh.new()
	flame_shape.radius = 0.16
	flame_shape.height = 0.42
	flame_shape.material = fire_material
	var flame := MeshInstance3D.new()
	flame.name = "Animated torch flame"
	flame.mesh = flame_shape
	flame.position = base + Vector3(0.0, 0.72, 0.24)
	add_child(flame)
	flames.append(flame)

	var light := OmniLight3D.new()
	light.name = "Warm torch light"
	light.position = flame.position + Vector3(0.0, 0.07, 0.35)
	light.light_color = Color("#ffb86c")
	light.light_energy = 1.45
	light.omni_range = 6.5
	light.shadow_enabled = false  # Better for mobile performance.
	add_child(light)
	fire_lights.append(light)


func _add_treasure_chest() -> void:
	var chest_z := -5.0
	_box("Chest body", Vector3(0.0, 0.64, chest_z), Vector3(1.42, 0.65, 0.88), Color("#72472b"))
	_box("Chest lid", Vector3(0.0, 1.04, chest_z), Vector3(1.49, 0.24, 0.96), Color("#8b592f"))
	for x in [-0.53, 0.53]:
		_box("Metal chest strap", Vector3(x, 0.72, chest_z + 0.46), Vector3(0.13, 0.88, 0.045), Color("#96835b"), 0.65)
		_box("Lid strap", Vector3(x, 1.175, chest_z), Vector3(0.13, 0.045, 0.99), Color("#96835b"), 0.65)
	_box("Chest lock", Vector3(0.0, 0.80, chest_z + 0.49), Vector3(0.23, 0.24, 0.09), Color("#d2aa58"), 0.65)

	# Match the visible chest with collision (no need to edit Dungeon.gd).
	var chest_collision := StaticBody3D.new()
	chest_collision.name = "Chest collision"
	chest_collision.position = Vector3(0.0, 0.72, chest_z)
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.44, 0.88, 0.94)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	chest_collision.add_child(collider)
	add_child(chest_collision)


func _set_mood_lighting() -> void:
	for child in get_parent().get_children():
		if child is DirectionalLight3D:
			child.light_energy = 0.55
			child.light_color = Color("#aab8ce")
	var sky := WorldEnvironment.new()
	sky.name = "Dungeon atmosphere"
	var atmosphere := Environment.new()
	atmosphere.background_mode = Environment.BG_COLOR
	atmosphere.background_color = Color("#171d25")
	atmosphere.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	atmosphere.ambient_light_color = Color("#74859a")
	atmosphere.ambient_light_energy = 0.40
	sky.environment = atmosphere
	add_child(sky)


func _process(delta: float) -> void:
	elapsed += delta
	for index in range(flames.size()):
		# Small, inexpensive animation. No particle system required.
		var wave := sin(elapsed * 9.0 + float(index) * 2.3)
		flames[index].scale.y = 1.0 + wave * 0.13
		fire_lights[index].light_energy = 1.38 + wave * 0.15
