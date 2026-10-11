extends Node3D

# Lightweight surface hub assembled from shared low-poly meshes. Static props
# intentionally reuse materials and avoid dynamic shadows except for the sun.

const DUNGEON_SCENE := "res://dungeon.tscn"

var traveling: bool = false
var materials: Dictionary = {}
var box_meshes: Dictionary = {}


func _ready() -> void:
	_prepare_materials()
	_create_environment()
	_create_ground()
	_create_houses()
	_create_square_dressing()
	_create_dungeon_entrance()
	_create_villagers()
	_create_title_card()


func _prepare_materials() -> void:
	materials["grass"] = _material(Color("#435d3f"), 0.98)
	materials["grass_light"] = _material(Color("#5e7449"), 0.98)
	materials["grass_dry"] = _material(Color("#78805a"), 0.98)
	materials["path"] = _material(Color("#78664f"), 0.97)
	materials["path_light"] = _material(Color("#907958"), 0.97)
	materials["path_dark"] = _material(Color("#6d5d4d"), 0.98)
	materials["stone"] = _material(Color("#8e9690"), 0.9)
	materials["stone_light"] = _material(Color("#abb0a5"), 0.92)
	materials["stone_dark"] = _material(Color("#4a5352"), 0.94)
	materials["plaster"] = _material(Color("#c4bba1"), 0.9)
	materials["timber"] = _material(Color("#654735"), 0.92)
	materials["timber_dark"] = _material(Color("#3f2d26"), 0.95)
	materials["wood_light"] = _material(Color("#8a6544"), 0.94)
	materials["roof"] = _material(Color("#344d54"), 0.9)
	materials["roof_edge"] = _material(Color("#23383e"), 0.92)
	materials["iron"] = _material(Color("#252c2d"), 0.82)
	materials["cloth_red"] = _material(Color("#873f38"), 0.93)
	materials["cloth_gold"] = _material(Color("#b48a4b"), 0.93)
	materials["skin"] = _material(Color("#b98568"), 0.95)
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
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	sun.shadow_bias = 0.08
	sun.directional_shadow_max_distance = 50.0
	add_child(sun)

	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#769da8")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#829fab")
	environment.ambient_light_energy = 0.44
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 0.92
	environment.adjustment_enabled = true
	environment.adjustment_brightness = 1.04
	environment.adjustment_contrast = 1.12
	environment.adjustment_saturation = 1.08
	environment.glow_enabled = true
	environment.glow_intensity = 0.72
	environment.glow_bloom = 0.12
	environment.fog_enabled = true
	environment.fog_light_color = Color("#a8c3bc")
	environment.fog_density = 0.0045
	environment.fog_height = 2.0
	environment.fog_height_density = 0.055
	world.environment = environment
	add_child(world)


func _create_ground() -> void:
	_block("Village green", Vector3(0, -0.3, 0), Vector3(42, 0.6, 34), "grass", true)
	_block("Main stone path", Vector3(0, 0.025, 0), Vector3(5.2, 0.08, 31), "path", false)
	_block("Cross path", Vector3(0, 0.03, 1), Vector3(28, 0.09, 4.2), "path", false)
	# Broad, irregular worn patches soften the former rectangular crossroads.
	for patch in [
		[Vector3(-1.3, 0.085, -6.0), Vector3(2.2, 0.035, 3.6)],
		[Vector3(1.4, 0.087, 7.3), Vector3(2.6, 0.035, 4.0)],
		[Vector3(-7.2, 0.09, 0.4), Vector3(3.6, 0.035, 2.2)],
		[Vector3(7.0, 0.091, 1.6), Vector3(4.2, 0.035, 2.0)]]:
		_cylinder(self, patch[0], patch[1].x, patch[1].y, materials["path_light"], 10, patch[1].z / patch[1].x)
	# Sparse inset stones establish direction without hundreds of unique props.
	for z in range(-7, 8):
		var side := -1.0 if z % 2 == 0 else 1.0
		_block("Path edge stone", Vector3(side * 2.45, 0.09, float(z) * 1.9),
			Vector3(0.46, 0.12, 1.25), "stone", false)
	# Deterministic clusters add life without expensive particles or unique meshes.
	for at in [Vector3(-6, 0, -9), Vector3(6, 0, 8), Vector3(-14, 0, 2), Vector3(13, 0, -10), Vector3(10, 0, 11)]:
		_grass_cluster(at)
	for at in [Vector3(-3.2, 0.12, 6.5), Vector3(3.1, 0.12, -5.2), Vector3(12, 0.12, 3), Vector3(-13, 0.12, -1)]:
		_cylinder(self, at, 0.34, 0.18, materials["stone_dark"], 7, 0.72)


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
	# Readable braces and a deep upper-story lip give each home a crafted facade.
	for x in [-1.75, 1.75]:
		var brace := _mesh_block(root, Vector3(x, 2.25, 2.69), Vector3(0.22, 1.75, 0.22), materials["timber"])
		brace.rotation.z = x * 0.22
	_mesh_block(root, Vector3(0, 3.28, 2.58), Vector3(7.0, 0.22, 0.42), materials["roof_edge"])
	# Broad crossed roof slabs make a clean stylized pitched-roof silhouette.
	for roof_angle in [-0.48, 0.48]:
		var roof := _mesh_block(root, Vector3(roof_angle * -2.0, 4.05, 0),
			Vector3(4.4, 0.34, 6.1), materials["roof"])
		roof.rotation.z = roof_angle
	# Ridge cap, stone chimney and cap exaggerate the skyline at isometric scale.
	_mesh_block(root, Vector3(0, 5.05, 0), Vector3(0.32, 0.28, 6.35), materials["roof_edge"])
	_mesh_block(root, Vector3(1.75, 4.75, -0.8), Vector3(0.85, 2.2, 0.85), materials["stone_dark"])
	_mesh_block(root, Vector3(1.75, 5.84, -0.8), Vector3(1.05, 0.18, 1.05), materials["stone"])
	var door := _mesh_block(root, Vector3(0, 1.25, 2.69), Vector3(1.45, 2.5, 0.18), materials["timber"])
	door.name = "Recessed wooden door"
	for x in [-1.95, 1.95]:
		_mesh_block(root, Vector3(x, 1.72, 2.70), Vector3(1.22, 1.28, 0.12), materials["timber_dark"])
		_mesh_block(root, Vector3(x, 1.72, 2.78), Vector3(0.88, 0.92, 0.10), materials["water"])
		_mesh_block(root, Vector3(x, 1.72, 2.84), Vector3(0.10, 1.0, 0.08), materials["timber"])
		_mesh_block(root, Vector3(x, 1.72, 2.85), Vector3(0.98, 0.10, 0.08), materials["timber"])
	# Hanging inn/workshop sign reads clearly without adding UI.
	_mesh_block(root, Vector3(-2.75, 2.55, 3.05), Vector3(0.16, 1.35, 0.16), materials["iron"])
	_mesh_block(root, Vector3(-2.2, 2.95, 3.05), Vector3(1.15, 0.12, 0.12), materials["iron"])
	_mesh_block(root, Vector3(-1.78, 2.48, 3.05), Vector3(0.78, 0.72, 0.12), materials["wood_light"])
	# Two foundation stones break the perfectly straight base.
	for x in [-2.3, 2.15]:
		_cylinder(root, Vector3(x, 0.25, 2.72), 0.48, 0.36, materials["stone"], 7, 0.72)


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
	_cylinder(well, Vector3(0, 2.65, 0), 0.28, 3.0, materials["wood_light"], 10)
	_mesh_block(well, Vector3(0, 2.65, 0.42), Vector3(0.12, 0.95, 0.12), materials["iron"])
	_cylinder(well, Vector3(0, 2.18, 0.42), 0.42, 0.42, materials["wood_light"], 10)
	# A compact shingled canopy turns the well into Greyhaven's landmark.
	for roof_angle in [-0.52, 0.52]:
		var canopy := _mesh_block(well, Vector3(roof_angle * -0.65, 3.72, 0), Vector3(1.75, 0.18, 3.8), materials["roof"])
		canopy.rotation.z = roof_angle
	_mesh_block(well, Vector3(0, 4.18, 0), Vector3(0.22, 0.22, 4.0), materials["roof_edge"])

	for tree_position in [Vector3(-16, 0, -10), Vector3(16, 0, 7), Vector3(13, 0, 12), Vector3(-16, 0, 12)]:
		_tree(tree_position)
	for crate_position in [Vector3(-5.5, 0.55, -1.8), Vector3(-6.7, 0.42, -1.6), Vector3(7.6, 0.5, -0.4)]:
		_block("Trade crate", crate_position, Vector3(1.1, crate_position.y * 2.0, 1.1), "timber", true)
	_barrel(Vector3(-7.3, 0, -2.1))
	_barrel(Vector3(8.8, 0, -0.7))
	_cart(Vector3(10.8, 0, 2.7), -0.18)
	_bench(Vector3(2.7, 0, 6.5), PI * 0.5)
	_wood_pile(Vector3(-7.6, 0, 7.0))
	_market_stall(Vector3(-6.5, 0, 3.7))
	_fence_line(Vector3(-15.0, 0, 6.0), Vector3(0, 0, -1), 5)
	_fence_line(Vector3(15.0, 0, -7.0), Vector3(0, 0, 1), 5)


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
	# Ancient gate stones, warning braziers and a peaked marker make the north exit
	# unmistakable even when the floating prompt is out of view.
	for x in [-2.25, 2.25]:
		_block("Dungeon gate pier", at + Vector3(x, 1.8, -0.55), Vector3(0.85, 3.6, 0.95), "stone_dark", true)
		_block("Gate pier cap", at + Vector3(x, 3.65, -0.55), Vector3(1.15, 0.25, 1.2), "stone", false)
		_brazier(at + Vector3(x, 4.05, -0.55))
	var lintel_left := _block("Dungeon gate arch", at + Vector3(-1.05, 4.15, -0.55), Vector3(2.6, 0.55, 0.85), "stone_dark", false)
	lintel_left.rotation.z = -0.34
	var lintel_right := _block("Dungeon gate arch", at + Vector3(1.05, 4.15, -0.55), Vector3(2.6, 0.55, 0.85), "stone_dark", false)
	lintel_right.rotation.z = 0.34
	_mesh_block(lintel_left, Vector3(1.08, 0.15, -0.5), Vector3(0.75, 0.9, 0.15), materials["cloth_red"])

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


func _create_villagers() -> void:
	_villager(Vector3(6.8, 0, 6.2), Color("#47687c"), "Mara  •  Quartermaster")
	_villager(Vector3(-4.8, 0, 3.2), Color("#7d493d"), "Tomas  •  Smith")
	_villager(Vector3(8.5, 0, -5.8), Color("#68754a"), "Greyhaven Scout")


func _villager(at: Vector3, coat: Color, title: String) -> void:
	var root := Node3D.new()
	root.name = "NPC placeholder - " + title
	root.position = at
	add_child(root)
	var coat_material := _material(coat, 0.94)
	_cylinder(root, Vector3(0, 0.95, 0), 0.42, 1.45, coat_material, 8)
	_sphere(root, Vector3(0, 1.95, 0), Vector3(0.72, 0.82, 0.72), materials["skin"])
	_mesh_block(root, Vector3(0, 1.25, -0.18), Vector3(0.9, 0.18, 0.55), materials["timber_dark"])
	var marker := Label3D.new()
	marker.text = "◆\n" + title
	marker.position = Vector3(0, 2.9, 0)
	marker.font_size = 25
	marker.outline_size = 6
	marker.modulate = Color("#ead9a4")
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker.no_depth_test = true
	root.add_child(marker)


func _barrel(at: Vector3) -> void:
	var root := Node3D.new()
	root.name = "Barrel"
	root.position = at
	add_child(root)
	_cylinder(root, Vector3(0, 0.58, 0), 0.48, 1.16, materials["wood_light"], 10)
	for y in [0.18, 0.58, 0.98]:
		_cylinder(root, Vector3(0, y, 0), 0.51, 0.08, materials["iron"], 10)


func _cart(at: Vector3, yaw: float) -> void:
	var root := Node3D.new()
	root.name = "Market handcart"
	root.position = at
	root.rotation.y = yaw
	add_child(root)
	_mesh_block(root, Vector3(0, 0.82, 0), Vector3(2.7, 0.38, 1.55), materials["wood_light"])
	for x in [-1.05, 1.05]:
		var wheel := _cylinder(root, Vector3(x, 0.52, 0.82), 0.62, 0.16, materials["timber_dark"], 10)
		wheel.rotation.x = PI * 0.5
	for x in [-0.42, 0.42]:
		_mesh_block(root, Vector3(x, 0.48, -1.65), Vector3(0.16, 0.16, 2.25), materials["timber"])


func _bench(at: Vector3, yaw: float) -> void:
	var root := Node3D.new()
	root.name = "Village bench"
	root.position = at
	root.rotation.y = yaw
	add_child(root)
	_mesh_block(root, Vector3(0, 0.7, 0), Vector3(2.5, 0.22, 0.65), materials["wood_light"])
	_mesh_block(root, Vector3(0, 1.25, 0.27), Vector3(2.5, 0.75, 0.18), materials["wood_light"])
	for x in [-0.9, 0.9]:
		_mesh_block(root, Vector3(x, 0.35, 0), Vector3(0.18, 0.7, 0.5), materials["timber_dark"])


func _wood_pile(at: Vector3) -> void:
	var root := Node3D.new()
	root.name = "Split firewood pile"
	root.position = at
	add_child(root)
	for row in range(3):
		for column in range(4 - row):
			var log_mesh := _cylinder(root, Vector3(column * 0.42 - 0.65 + row * 0.2, 0.22 + row * 0.38, 0), 0.19, 1.1, materials["wood_light"], 7)
			log_mesh.rotation.x = PI * 0.5


func _market_stall(at: Vector3) -> void:
	var root := Node3D.new()
	root.name = "Greyhaven produce stall"
	root.position = at
	add_child(root)
	for x in [-1.25, 1.25]:
		_mesh_block(root, Vector3(x, 1.45, 0), Vector3(0.18, 2.9, 0.18), materials["timber"])
	_mesh_block(root, Vector3(0, 1.0, 0), Vector3(2.9, 0.25, 1.4), materials["wood_light"])
	for x in [-0.8, 0, 0.8]:
		_cylinder(root, Vector3(x, 1.28, 0), 0.22, 0.16, materials["grass_dry"], 8)
	for stripe in range(5):
		_mesh_block(root, Vector3(-1.2 + stripe * 0.6, 2.9, 0), Vector3(0.62, 0.16, 2.1), materials["cloth_red"] if stripe % 2 == 0 else materials["cloth_gold"])


func _fence_line(start: Vector3, direction: Vector3, count: int) -> void:
	var root := Node3D.new()
	root.name = "Boundary fence"
	add_child(root)
	for index in range(count):
		var at := start + direction * float(index) * 1.8
		_mesh_block(root, at + Vector3(0, 0.7, 0), Vector3(0.18, 1.4, 0.18), materials["timber_dark"])
		if index < count - 1:
			var rail_at := at + direction * 0.9 + Vector3(0, 0.83, 0)
			var rail_size := Vector3(1.95, 0.14, 0.14) if absf(direction.x) > 0.5 else Vector3(0.14, 0.14, 1.95)
			_mesh_block(root, rail_at, rail_size, materials["timber"])


func _grass_cluster(at: Vector3) -> void:
	var root := Node3D.new()
	root.name = "Grass and wildflower cluster"
	root.position = at
	add_child(root)
	for index in range(5):
		var blade := _mesh_block(root, Vector3((index - 2) * 0.18, 0.25, float(index % 2) * 0.15), Vector3(0.08, 0.5 + index * 0.05, 0.08), materials["grass_light"])
		blade.rotation.z = (index - 2) * 0.09


func _brazier(at: Vector3) -> void:
	_cylinder(self, at, 0.42, 0.22, materials["iron"], 8)
	var flame_material := _material(Color("#e17a35"), 0.6)
	flame_material.emission_enabled = true
	flame_material.emission = Color("#d75b24")
	flame_material.emission_energy_multiplier = 1.8
	_sphere(self, at + Vector3(0, 0.38, 0), Vector3(0.42, 0.75, 0.42), flame_material)


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
	# Identical boxes share mesh resources; this keeps the expanded dressing cheap
	# on the mobile renderer while still allowing independently placed instances.
	var key := "%s:%s" % [size, material.resource_name if not material.resource_name.is_empty() else material.get_rid()]
	var box: BoxMesh
	if box_meshes.has(key):
		box = box_meshes[key]
	else:
		box = BoxMesh.new()
		box.size = size
		box.material = material
		box_meshes[key] = box
	var mesh := MeshInstance3D.new()
	mesh.mesh = box
	mesh.position = at
	parent.add_child(mesh)
	return mesh


func _cylinder(parent: Node3D, at: Vector3, radius: float, height: float,
		material: Material, segments: int = 16, depth_scale: float = 1.0) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.top_radius = radius
	shape.bottom_radius = radius * 1.05
	shape.height = height
	shape.radial_segments = segments
	shape.material = material
	var mesh := MeshInstance3D.new()
	mesh.mesh = shape
	mesh.position = at
	mesh.scale.z = depth_scale
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
