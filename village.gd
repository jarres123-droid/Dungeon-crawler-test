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
	materials["grass"] = _material(Color("#52733f"), 0.92, "grass", 4.2, 0.68)
	materials["grass_light"] = _material(Color("#71904f"), 0.90, "grass", 3.6, 0.65)
	materials["grass_dry"] = _material(Color("#948951"), 0.94, "grass", 4.0, 0.60)
	materials["path"] = _material(Color("#9e7650"), 0.86, "earth_path", 3.3, 0.72)
	materials["path_light"] = _material(Color("#b98c5a"), 0.83, "earth_path", 2.8, 0.68)
	materials["path_dark"] = _material(Color("#74513c"), 0.90, "earth_path", 3.1, 0.72)
	materials["path_edge"] = _material(Color("#856744"), 0.92, "earth_path", 4.8, 0.62)
	materials["stone"] = _material(Color("#92958c"), 0.78, "warm_stone", 2.2, 0.76)
	materials["stone_light"] = _material(Color("#bab6aa"), 0.74, "warm_stone", 1.9, 0.72)
	materials["stone_dark"] = _material(Color("#596662"), 0.84, "warm_stone", 2.2, 0.78)
	materials["plaster"] = _material(Color("#ead9b8"), 0.92, "lime_plaster", 2.2)
	materials["timber"] = _material(Color("#875233"), 0.72, "oak_timber", 1.8, 0.72)
	materials["timber_dark"] = _material(Color("#412b25"), 0.80, "oak_timber", 1.8, 0.68)
	materials["wood_light"] = _material(Color("#aa7040"), 0.68, "oak_timber", 1.8, 0.74)
	materials["roof"] = _material(Color("#385963"), 0.76, "slate_roof", 2.35, 0.82)
	materials["roof_edge"] = _material(Color("#223e46"), 0.82, "slate_roof", 2.35, 0.78)
	materials["iron"] = _material(Color("#293638"), 0.48, "aged_iron", 1.8, 0.82)
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


func _material(color: Color, roughness: float, texture_key: String = "", repeat: float = 1.0,
		normal_strength: float = 0.55) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	# Keep enough tint to separate adjacent materials. The previous near-white tint
	# lifted every textured surface into the same pastel value range.
	result.albedo_color = color.lightened(0.38) if texture_key != "" else color
	result.roughness = roughness
	if texture_key != "":
		var root := "res://assets/textures/premium/%s_" % texture_key
		result.albedo_texture = load(root + "albedo.png") as Texture2D
		result.normal_enabled = true
		result.normal_texture = load(root + "normal.png") as Texture2D
		result.normal_scale = normal_strength
		result.roughness_texture = load(root + "roughness.png") as Texture2D
		result.uv1_scale = Vector3(repeat, repeat, repeat)
		result.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return result


func _create_environment() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "Warm afternoon sun"
	sun.rotation_degrees = Vector3(-52.0, -38.0, 0.0)
	sun.light_color = Color("#ffd9a0")
	sun.light_energy = 1.28
	sun.light_angular_distance = 0.65
	sun.shadow_enabled = true
	sun.shadow_bias = 0.055
	sun.directional_shadow_max_distance = 50.0
	add_child(sun)
	# A very soft cool fill preserves form in the sun's shadow without flattening it.
	var sky_fill := DirectionalLight3D.new()
	sky_fill.name = "Cool skylight fill"
	sky_fill.rotation_degrees = Vector3(-38.0, 142.0, 0.0)
	sky_fill.light_color = Color("#719db5")
	sky_fill.light_energy = 0.18
	sky_fill.shadow_enabled = false
	add_child(sky_fill)

	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#527b8d")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#668ba0")
	environment.ambient_light_energy = 0.31
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 0.88
	environment.adjustment_enabled = true
	environment.adjustment_brightness = 0.98
	environment.adjustment_contrast = 1.11
	environment.adjustment_saturation = 1.12
	environment.glow_enabled = true
	environment.glow_intensity = 0.22
	environment.glow_bloom = 0.025
	# This compact isometric view does not need aerial perspective; even low-density
	# fog veiled the texture and shadow detail across the entire playable area.
	environment.fog_enabled = false
	world.environment = environment
	add_child(world)


func _create_ground() -> void:
	_block("Village green", Vector3(0, -0.3, 0), Vector3(42, 0.6, 34), "grass", true)
	_block("Main stone path", Vector3(0, 0.025, 0), Vector3(5.2, 0.08, 31), "path", false)
	_block("Cross path", Vector3(0, 0.03, 1), Vector3(28, 0.09, 4.2), "path", false)
	# Low, irregular shoulders blend the path into turf while keeping its strong
	# navigational silhouette. Paired darker strips imply years of cart wear.
	for data in [
		[Vector3(-2.55, .064, -4.8), .68, 20.0, 1.0], [Vector3(2.55, .065, 4.9), .72, 18.5, 1.0],
		[Vector3(-7.4, .068, -1.22), .74, 12.5, 1.8], [Vector3(7.2, .069, 3.18), .70, 13.0, 1.7]]:
		_cylinder(self, data[0], data[1], .035, materials["path_edge"], 12, data[2])
	for x in [-1.18, 1.18]:
		_block("Soft cart rut", Vector3(x, .083, 0), Vector3(.34, .025, 28.5), "path_dark", false)
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
	for at in [Vector3(-3.0,0,-7.0), Vector3(3.0,0,-3.5), Vector3(-8.5,0,3.4), Vector3(8.8,0,-1.6)]:
		_grass_cluster(at)
	for at in [Vector3(-3.2, 0.12, 6.5), Vector3(3.1, 0.12, -5.2), Vector3(12, 0.12, 3), Vector3(-13, 0.12, -1)]:
		_cylinder(self, at, 0.34, 0.18, materials["stone_dark"], 7, 0.72)


func _create_houses() -> void:
	# Placement stays Greyhaven-specific; construction and proportions live in the
	# reusable building kit. Existing anchors retain their recognizable footprint.
	var placements := [
		["medium_residence", Vector3(-9.5, 0, -5.5), 0.08],
		["workshop", Vector3(9.8, 0, -4.0), -0.12],
		["small_cottage", Vector3(-10.5, 0, 8.0), PI * 0.55],
		["merchant_shop", Vector3(10.8, 0, 8.8), -PI * 0.52],
		["important_hall", Vector3(-12.2, 0, -13.0), 0.04],
	]
	for placement in placements:
		_asset("greyhaven/buildings/archetypes/%s" % placement[0], placement[1], placement[2])


func _legacy_house(at: Vector3, yaw: float, plaster_tint: Color) -> void:
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
	# Reusable authored well replaces the former primitive assembly.
	_asset("village/well", Vector3(5.4, 0, 4.4))

	for tree_position in [Vector3(-16, 0, -10), Vector3(16, 0, 7), Vector3(13, 0, 12), Vector3(-16, 0, 12)]:
		_tree(tree_position)
	_asset("village/crate_stack", Vector3(-6.0, 0, -1.8), 0.12)
	_asset("village/crate_stack", Vector3(7.7, 0, -0.5), -0.2)
	_asset("village/barrel", Vector3(-7.3, 0, -2.1))
	_asset("village/barrel", Vector3(8.8, 0, -0.7))
	_asset("village/cart", Vector3(10.8, 0, 2.7), -0.18)
	_asset("village/bench", Vector3(2.7, 0, 6.5), PI * 0.5)
	_asset("village/woodpile", Vector3(-7.6, 0, 7.0))
	_asset("village/market_stall", Vector3(-6.5, 0, 3.7))
	_asset("village/smithy_props", Vector3(7.2, 0, -6.8), 0.2)
	_asset("village/planter", Vector3(4.0, 0, 7.5))
	for index in range(5):
		_asset("village/fence", Vector3(-15.0, 0, 6.0-index*3.0), PI*.5)
		_asset("village/fence", Vector3(15.0, 0, -7.0+index*3.0), PI*.5)


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
	_asset("village/greyhaven_entrance", at)

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


func _asset(path: String, at: Vector3, yaw: float = 0.0) -> Node3D:
	var scene: PackedScene = load("res://assets/%s.tscn" % path)
	var instance := scene.instantiate() as Node3D
	instance.position = at
	instance.rotation.y = yaw
	add_child(instance)
	return instance


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
