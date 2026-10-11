extends Node3D

# Shared final-pass art direction for Greyhaven and the procedural dungeon.
# Geometry is deliberately low-poly and materials are shared so the extra depth
# remains inexpensive on the mobile renderer.

var clock: float = 0.0
var player: Node3D
var motes: Array[MeshInstance3D] = []
var lantern_lights: Array[OmniLight3D] = []
var materials: Dictionary = {}


func _ready() -> void:
	_build_materials()
	call_deferred("_build_showcase")


func _build_materials() -> void:
	materials["ink"] = _material(Color("#15242b"), 0.94)
	materials["slate"] = _material(Color("#344d55"), 0.92)
	materials["stone"] = _material(Color("#718083"), 0.96)
	materials["copper"] = _material(Color("#b67842"), 0.48, 0.35)
	materials["ember"] = _material(Color("#ffbd67"), 0.4, 0.0, Color("#f07832"), 2.3)
	materials["aether"] = _material(Color("#7de2d6"), 0.2, 0.0, Color("#36a99f"), 1.5)
	materials["flower"] = _material(Color("#d69ab7"), 0.95)
	materials["pine"] = _material(Color("#294d46"), 0.98)
	materials["pine_light"] = _material(Color("#3e6b55"), 0.98)
	materials["mist"] = _material(Color(0.55, 0.75, 0.76, 0.12), 1.0)
	(materials["mist"] as StandardMaterial3D).transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	(materials["mist"] as StandardMaterial3D).shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED


func _material(color: Color, roughness: float, metallic: float = 0.0,
		emission: Color = Color.BLACK, emission_energy: float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	if emission_energy > 0.0:
		mat.emission_enabled = true
		mat.emission = emission
		mat.emission_energy_multiplier = emission_energy
	return mat


func _build_showcase() -> void:
	await get_tree().process_frame
	player = get_parent().get_node_or_null("Player") as Node3D
	if get_parent().name == "Village":
		_build_greyhaven_pass()
	else:
		_build_dungeon_pass()
	_add_player_readability()
	_add_screen_finish()


func _build_greyhaven_pass() -> void:
	# Layered distant silhouettes give the orthographic camera a composed horizon.
	for data in [
		[Vector3(-25, -0.2, -20), 9.0, 11.0], [Vector3(-10, -0.2, -25), 12.0, 15.0],
		[Vector3(8, -0.2, -27), 10.0, 13.0], [Vector3(25, -0.2, -20), 8.0, 10.0]]:
		var peak := _cone(data[0] + Vector3(0, data[2] * 0.5, 0), data[1], data[2], materials["slate"], 7)
		peak.name = "Mistbound mountain"
	# Foreground conifers frame the town without closing its playable space.
	for at in [Vector3(-20, 0, -5), Vector3(-19, 0, 7), Vector3(19, 0, -9), Vector3(20, 0, 11), Vector3(-13, 0, 15)]:
		_pine(at)
	# Warm path lanterns establish a visual route from the square to the dungeon.
	for at in [Vector3(-2.8, 0, -8), Vector3(2.8, 0, -8), Vector3(-2.8, 0, -2), Vector3(2.8, 0, 5.0)]:
		_lantern(at)
	# Small color clusters soften the broad ground plane.
	for at in [Vector3(-4, 0, -10), Vector3(5, 0, 10), Vector3(13, 0, 6), Vector3(-14, 0, -7), Vector3(-7, 0, 12)]:
		_wildflowers(at)
	_add_motes(Color("#d8ecb1"), 22, Vector3(18, 4, 14), Vector3(0, 0.4, 1))


func _build_dungeon_pass() -> void:
	var dungeon := get_parent()
	var cells_value = dungeon.get("dungeon_cells")
	if cells_value is Array:
		var cells: Array = cells_value
		for index in range(cells.size()):
			var cell: Vector2i = cells[index]
			var center := Vector3(cell.x * 24.0, 0.0, cell.y * 24.0)
			# Raised perimeter plinths and teal rune shards add rhythm and navigation cues.
			for corner in [Vector3(-6.7, 0, -6.7), Vector3(6.7, 0, -6.7), Vector3(-6.7, 0, 6.7), Vector3(6.7, 0, 6.7)]:
				_cone(center + corner + Vector3(0, 0.38, 0), 0.34, 0.76, materials["stone"], 6)
			if index % 2 == 0:
				_rune_dais(center, index)
			if index % 3 == 1:
				_chain_cluster(center + Vector3(6.9, 0, -5.0))
	_add_motes(Color("#75c8c0"), 28, Vector3(13, 3, 13), Vector3(0, 0.25, 0))


func _rune_dais(center: Vector3, seed_value: int) -> void:
	var root := Node3D.new()
	root.name = "Aether rune floor accent"
	root.position = center + Vector3(-4.8 if seed_value % 4 == 0 else 4.8, 0.07, 4.8)
	add_child(root)
	for i in range(8):
		var angle := TAU * float(i) / 8.0
		var shard := _box(root, Vector3(cos(angle) * 0.85, 0, sin(angle) * 0.85), Vector3(0.34, 0.035, 0.10), materials["aether"])
		shard.rotation.y = -angle
	var gem := _cone(Vector3.ZERO, 0.20, 0.46, materials["aether"], 6, root)
	gem.position.y = 0.27


func _chain_cluster(at: Vector3) -> void:
	var root := Node3D.new()
	root.name = "Hanging iron chains"
	root.position = at
	add_child(root)
	for chain in range(2):
		for link in range(6 + chain * 2):
			var ring := TorusMesh.new()
			ring.inner_radius = 0.075
			ring.outer_radius = 0.12
			ring.rings = 8
			ring.ring_segments = 5
			ring.material = materials["ink"]
			var mesh := MeshInstance3D.new()
			mesh.mesh = ring
			mesh.position = Vector3(chain * 0.35, 2.8 - link * 0.24, 0)
			mesh.rotation.x = PI * 0.5 if link % 2 == 0 else 0.0
			root.add_child(mesh)


func _pine(at: Vector3) -> void:
	var root := Node3D.new()
	root.name = "Layered Greyhaven pine"
	root.position = at
	add_child(root)
	_box(root, Vector3(0, 1.4, 0), Vector3(0.42, 2.8, 0.42), materials["copper"])
	for layer in range(3):
		_cone(Vector3(0, 2.2 + layer * 1.15, 0), 2.25 - layer * 0.4, 2.8,
			materials["pine"] if layer != 1 else materials["pine_light"], 8, root)


func _lantern(at: Vector3) -> void:
	var root := Node3D.new()
	root.name = "Copper wayfinding lantern"
	root.position = at
	add_child(root)
	_box(root, Vector3(0, 1.1, 0), Vector3(0.13, 2.2, 0.13), materials["ink"])
	_box(root, Vector3(0, 2.18, 0), Vector3(0.62, 0.08, 0.62), materials["copper"])
	_box(root, Vector3(0, 2.43, 0), Vector3(0.40, 0.48, 0.40), materials["ember"])
	var light := OmniLight3D.new()
	light.position = Vector3(0, 2.4, 0)
	light.light_color = Color("#ffc37c")
	light.light_energy = 1.1
	light.omni_range = 5.5
	light.shadow_enabled = false
	root.add_child(light)
	lantern_lights.append(light)


func _wildflowers(at: Vector3) -> void:
	var root := Node3D.new()
	root.position = at
	root.name = "Wildflower color cluster"
	add_child(root)
	for i in range(7):
		var angle := float(i) * 2.4
		var p := Vector3(cos(angle) * (0.18 + i * 0.06), 0.22 + (i % 3) * 0.06, sin(angle) * (0.18 + i * 0.06))
		_box(root, Vector3(p.x, p.y * 0.5, p.z), Vector3(0.035, p.y, 0.035), materials["pine_light"])
		_cone(p, 0.09, 0.10, materials["flower"] if i % 2 == 0 else materials["ember"], 6, root)


func _add_motes(tint: Color, count: int, bounds: Vector3, origin: Vector3) -> void:
	var mat := _material(tint, 1.0, 0.0, tint, 1.25)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var mesh := SphereMesh.new()
	mesh.radius = 0.035
	mesh.height = 0.07
	mesh.radial_segments = 6
	mesh.rings = 3
	mesh.material = mat
	for i in range(count):
		var mote := MeshInstance3D.new()
		mote.name = "Atmospheric mote"
		mote.mesh = mesh
		mote.position = origin + Vector3(fmod(i * 7.13, bounds.x) - bounds.x * 0.5,
			fmod(i * 1.91, bounds.y), fmod(i * 4.77, bounds.z) - bounds.z * 0.5)
		mote.set_meta("phase", float(i) * 0.71)
		add_child(mote)
		motes.append(mote)


func _add_player_readability() -> void:
	if player == null:
		return
	var light := OmniLight3D.new()
	light.name = "Hero readability rim"
	light.position = Vector3(-1.2, 3.2, -1.0)
	light.light_color = Color("#8fd5e6")
	light.light_energy = 0.42
	light.omni_range = 4.5
	light.shadow_enabled = false
	player.add_child(light)
	# A dark soft-edged-looking octagon anchors the hero to the floor.
	var shadow_mat := _material(Color(0.015, 0.025, 0.035, 0.34), 1.0)
	shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var shadow := _cone(Vector3(0, 0.035, 0), 0.62, 0.025, shadow_mat, 16, player)
	shadow.name = "Hero contact shadow"


func _add_screen_finish() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Cinematic presentation overlay"
	layer.layer = 2
	add_child(layer)
	# Thin letterbox gradients focus the playfield without consuming mobile space.
	for top in [true, false]:
		var band := ColorRect.new()
		band.mouse_filter = Control.MOUSE_FILTER_IGNORE
		band.color = Color(0.015, 0.025, 0.035, 0.22)
		band.anchor_right = 1.0
		band.anchor_top = 0.0 if top else 1.0
		band.anchor_bottom = 0.0 if top else 1.0
		band.offset_top = 0.0 if top else -18.0
		band.offset_bottom = 18.0 if top else 0.0
		layer.add_child(band)


func _process(delta: float) -> void:
	clock += delta
	for i in range(motes.size()):
		var mote := motes[i]
		if is_instance_valid(mote):
			var phase: float = float(mote.get_meta("phase"))
			mote.position.y += sin(clock * 1.4 + phase) * delta * 0.045
			mote.scale = Vector3.ONE * (0.8 + sin(clock * 2.1 + phase) * 0.25)
	for i in range(lantern_lights.size()):
		lantern_lights[i].light_energy = 1.08 + sin(clock * 6.0 + i * 1.7) * 0.08


func _box(parent: Node3D, at: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = size
	shape.material = material
	var mesh := MeshInstance3D.new()
	mesh.mesh = shape
	mesh.position = at
	parent.add_child(mesh)
	return mesh


func _cone(at: Vector3, radius: float, height: float, material: Material, sides: int,
		parent: Node3D = self) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.top_radius = 0.0
	shape.bottom_radius = radius
	shape.height = height
	shape.radial_segments = sides
	shape.material = material
	var mesh := MeshInstance3D.new()
	mesh.mesh = shape
	mesh.position = at
	parent.add_child(mesh)
	return mesh
