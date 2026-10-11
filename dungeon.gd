extends Node3D

# Starter dungeon room for Godot 4.
# Attach this script to a Node3D root named Dungeon.

func _ready() -> void:
	build_dungeon()
	setup_camera()
	setup_lighting()


func build_dungeon() -> void:
	var stone := Color("#676b70")
	var floor_color := Color("#494d52")
	var pillar_color := Color("#85817a")
	var wood := Color("#65462e")

	add_block("Stone Floor", Vector3(0, -0.25, 0), Vector3(16, 0.5, 16), floor_color)
	add_block("Back Wall", Vector3(0, 1.5, -8), Vector3(16, 3, 0.8), stone)
	add_block("Left Wall", Vector3(-8, 1.5, 0), Vector3(0.8, 3, 16), stone)
	add_block("Right Wall", Vector3(8, 1.5, 0), Vector3(0.8, 3, 16), stone)
	add_block("Front Left", Vector3(-5, 1.5, 8), Vector3(6, 3, 0.8), stone)
	add_block("Front Right", Vector3(5, 1.5, 8), Vector3(6, 3, 0.8), stone)

	for x in [-5, 5]:
		for z in [-4, 4]:
			add_block("Stone Pillar", Vector3(x, 1.5, z), Vector3(1.2, 3, 1.2), pillar_color)

	add_block("Treasure Platform", Vector3(0, 0.15, -5), Vector3(3, 0.3, 2), wood)


func add_block(block_name: String, location: Vector3, dimensions: Vector3, block_color: Color) -> void:
	var body := StaticBody3D.new()
	body.name = block_name
	body.position = location
	add_child(body)

	var mesh := BoxMesh.new()
	mesh.size = dimensions
	var material := StandardMaterial3D.new()
	material.albedo_color = block_color
	material.roughness = 0.9
	mesh.material = material

	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	body.add_child(visual)

	var shape := BoxShape3D.new()
	shape.size = dimensions
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)


func setup_camera() -> void:
	var camera := Camera3D.new()
	add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 30.0
	camera.position = Vector3(20, 24, 20)
	camera.look_at(Vector3.ZERO)
	camera.current = true


func setup_lighting() -> void:
	var sunlight := DirectionalLight3D.new()
	add_child(sunlight)
	sunlight.rotation_degrees = Vector3(-50, -25, 0)
	sunlight.light_energy = 1.5
	sunlight.shadow_enabled = true
