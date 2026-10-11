extends Node3D

# Lightweight surface hub assembled from shared low-poly meshes. Static props
# intentionally reuse materials and avoid dynamic shadows except for the sun.

const DUNGEON_SCENE := "res://dungeon.tscn"

var traveling: bool = false
var materials: Dictionary = {}


func _ready() -> void:
	_prepare_materials()
	_create_environment()
	_create_ground()
	_create_houses()
	_create_square_dressing()
	_create_dungeon_entrance()
	_create_title_card()


func _prepare_materials() -> void:
	materials["grass"] = _material(Color("#526b4c"), 0.96)
	materials["path"] = _material(Color("#9b8b70"), 0.94)
	materials["stone"] = _material(Color("#8e9690"), 0.9)
	materials["stone_dark"] = _material(Color("#596260"), 0.94)
	materials["plaster"] = _material(Color("#c4bba1"), 0.9)
	materials["timber"] = _material(Color("#654735"), 0.92)
	materials["roof"] = _material(Color("#415d63"), 0.88)
	materials["leaf"] = _material(Color("#416548"), 0.96)
	materials["leaf_light"] = _material(Color("#64805a"), 0.96)
	materials["water"] = _material(Color("#4d99a6"), 0.35)
	var water: StandardMaterial3D = materials["water"]
	water.metallic = 0.15
	water.emission_enabled = true
	water.emission = Color("#214f59")
	water.emission_energy_multiplier = 0.3


func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = roughness
	return result


func _create_environment() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "Warm afternoon sun"
	sun.rotation_degrees = Vector3(-52.0, -38.0, 0.0)
	sun.light_color = Color("#ffe2b3")
	sun.light_energy = 1.05
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 50.0
	add_child(sun)

	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#91b7be")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#b9d1c5")
	environment.ambient_light_energy = 0.72
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color("#a8c3bc")
	environment.fog_density = 0.004
	world.environment = environment
	add_child(world)


func _create_ground() -> void:
	_block("Village green", Vector3(0, -0.3, 0), Vector3(42, 0.6, 34), "grass", true)
	_block("Main stone path", Vector3(0, 0.025, 0), Vector3(5.2, 0.08, 31), "path", false)
	_block("Cross path", Vector3(0, 0.03, 1), Vector3(28, 0.09, 4.2), "path", false)
	# Sparse inset stones establish direction without hundreds of unique props.
	for z in range(-7, 8):
		var side := -1.0 if z % 2 == 0 else 1.0
		_block("Path edge stone", Vector3(side * 2.45, 0.09, float(z) * 1.9),
			Vector3(0.46, 0.12, 1.25), "stone", false)


func _create_houses() -> void:
	_house(Vector3(-9.5, 0, -5.5), 0.08, Color("#c8bea4"))
	_house(Vector3(9.8, 0, -4.0), -0.12, Color("#bdb095"))
	_house(Vector3(-10.5, 0, 8.0), PI * 0.55, Color("#cfc3a6"))


func _house(at: Vector3, yaw: float, plaster_tint: Color) -> void:
	var root := Node3D.new()
	root.name = "Timber village home"
	root.position = at
	root.rotation.y = yaw
	add_child(root)
	var local_plaster := _material(plaster_tint, 0.92)
	_mesh_block(root, Vector3(0, 1.65, 0), Vector3(6.4, 3.3, 5.0), local_plaster)
	# Strong timber silhouette and layered foundation remove the placeholder-box read.
	for x in [-2.72, 2.72]:
		_mesh_block(root, Vector3(x, 1.75, 2.54), Vector3(0.32, 3.5, 0.30), materials["timber"])
	_mesh_block(root, Vector3(0, 0.24, 0), Vector3(6.7, 0.48, 5.3), materials["stone_dark"])
	_mesh_block(root, Vector3(0, 3.05, 2.53), Vector3(6.5, 0.30, 0.32), materials["timber"])
	_mesh_block(root, Vector3(0, 1.45, 2.57), Vector3(1.35, 2.35, 0.24), materials["timber"])
	# Broad crossed roof slabs make a clean stylized pitched-roof silhouette.
	for roof_angle in [-0.48, 0.48]:
		var roof := _mesh_block(root, Vector3(roof_angle * -2.0, 4.05, 0),
			Vector3(4.4, 0.34, 6.1), materials["roof"])
		roof.rotation.z = roof_angle
	var door := _mesh_block(root, Vector3(0, 1.25, 2.69), Vector3(1.45, 2.5, 0.18), materials["timber"])
	door.name = "Recessed wooden door"
	for x in [-1.95, 1.95]:
		_mesh_block(root, Vector3(x, 1.72, 2.70), Vector3(1.05, 1.10, 0.16), materials["water"])


func _create_square_dressing() -> void:
	# Central well acts as the village focal point and keeps the entrance secondary.
	var well := Node3D.new()
	well.name = "Village well"
	well.position = Vector3(5.4, 0, 4.4)
	add_child(well)
	_cylinder(well, Vector3(0, 0.55, 0), 1.35, 1.15, materials["stone"])
	_cylinder(well, Vector3(0, 1.12, 0), 1.5, 0.20, materials["stone_dark"])
	_cylinder(well, Vector3(0, 1.18, 0), 1.12, 0.08, materials["water"])
	for x in [-1.25, 1.25]:
		_mesh_block(well, Vector3(x, 2.15, 0), Vector3(0.20, 2.4, 0.20), materials["timber"])
	_mesh_block(well, Vector3(0, 3.2, 0), Vector3(3.1, 0.22, 0.32), materials["timber"])

	for tree_position in [Vector3(-16, 0, -10), Vector3(16, 0, 7), Vector3(13, 0, 12), Vector3(-16, 0, 12)]:
		_tree(tree_position)
	for crate_position in [Vector3(-5.5, 0.55, -1.8), Vector3(-6.7, 0.42, -1.6), Vector3(7.6, 0.5, -0.4)]:
		_block("Trade crate", crate_position, Vector3(1.1, crate_position.y * 2.0, 1.1), "timber", true)


func _tree(at: Vector3) -> void:
	var tree := Node3D.new()
	tree.name = "Low poly shade tree"
	tree.position = at
	add_child(tree)
	_cylinder(tree, Vector3(0, 1.6, 0), 0.38, 3.2, materials["timber"], 8)
	_sphere(tree, Vector3(0, 4.2, 0), Vector3(3.0, 2.4, 2.8), materials["leaf"])
	_sphere(tree, Vector3(1.25, 3.75, 0.35), Vector3(2.0, 1.7, 1.9), materials["leaf_light"])


func _create_dungeon_entrance() -> void:
	var at := Vector3(0, 0, -11.5)
	_block("Entrance dais", at + Vector3(0, 0.18, 0), Vector3(5.4, 0.36, 4.5), "stone_dark", true)
	_block("Open shaft", at + Vector3(0, 0.39, 0), Vector3(3.2, 0.12, 2.4), "stone", false)
	_block("Shaft darkness", at + Vector3(0, 0.47, 0), Vector3(2.65, 0.08, 1.9), "stone_dark", false)
	for x in [-1.0, 1.0]:
		_block("Dungeon ladder rail", at + Vector3(x, 1.25, 0), Vector3(0.20, 2.5, 0.20), "timber", false)
	for rung in range(6):
		_block("Dungeon ladder rung", at + Vector3(0, 0.35 + rung * 0.4, 0), Vector3(2.1, 0.13, 0.18), "timber", false)

	var area := Area3D.new()
	area.name = "Dungeon entrance ladder"
	area.position = at + Vector3(0, 1.0, 1.0)
	area.collision_layer = 0
	area.collision_mask = 1
	var shape := BoxShape3D.new()
	shape.size = Vector3(3.6, 2.0, 3.0)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	area.add_child(collision)
	add_child(area)
	area.body_entered.connect(_on_dungeon_entrance_reached)

	var label := Label3D.new()
	label.text = "DESCEND TO THE DUNGEON"
	label.position = at + Vector3(0, 3.1, 0)
	label.font_size = 36
	label.outline_size = 8
	label.modulate = Color("#f0d593")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	add_child(label)


func _create_title_card() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 4
	add_child(layer)
	var panel := Panel.new()
	panel.position = Vector2(18, 18)
	panel.size = Vector2(310, 78)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.09, 0.10, 0.82)
	style.border_color = Color("#b9a672")
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	var title := Label.new()
	title.text = "GREYHAVEN\nSurface Refuge  •  Dungeon Entrance North"
	title.position = Vector2(16, 9)
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", Color("#f1e5c5"))
	panel.add_child(title)


func _on_dungeon_entrance_reached(body: Node3D) -> void:
	if body.name != "Player" or traveling:
		return
	traveling = true
	get_tree().set_meta("dungeon_floor_number", 1)
	call_deferred("_enter_dungeon")


func _enter_dungeon() -> void:
	get_tree().change_scene_to_file(DUNGEON_SCENE)


func _block(label: String, at: Vector3, size: Vector3, material_key: String, collide: bool) -> Node3D:
	var root: Node3D
	if collide:
		var body := StaticBody3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		var collision := CollisionShape3D.new()
		collision.shape = shape
		body.add_child(collision)
		root = body
	else:
		root = Node3D.new()
	root.name = label
	root.position = at
	add_child(root)
	_mesh_block(root, Vector3.ZERO, size, materials[material_key])
	return root


func _mesh_block(parent: Node3D, at: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	box.material = material
	var mesh := MeshInstance3D.new()
	mesh.mesh = box
	mesh.position = at
	parent.add_child(mesh)
	return mesh


func _cylinder(parent: Node3D, at: Vector3, radius: float, height: float,
		material: Material, segments: int = 16) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.top_radius = radius
	shape.bottom_radius = radius * 1.05
	shape.height = height
	shape.radial_segments = segments
	shape.material = material
	var mesh := MeshInstance3D.new()
	mesh.mesh = shape
	mesh.position = at
	parent.add_child(mesh)
	return mesh


func _sphere(parent: Node3D, at: Vector3, size: Vector3, material: Material) -> void:
	var shape := SphereMesh.new()
	shape.radius = 0.5
	shape.height = 1.0
	shape.radial_segments = 10
	shape.rings = 6
	shape.material = material
	var mesh := MeshInstance3D.new()
	mesh.mesh = shape
	mesh.position = at
	mesh.scale = size
	parent.add_child(mesh)
