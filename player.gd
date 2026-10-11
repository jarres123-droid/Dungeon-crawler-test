extends CharacterBody3D

# Starter mobile player controller for Godot 4.
# Attach to a CharacterBody3D child of your Dungeon scene.
# Creates a visible capsule, collision, and touchscreen direction buttons.

const MOVE_SPEED: float = 4.0
const GRAVITY: float = 18.0

var held: Dictionary = {
	"left": false,
	"right": false,
	"up": false,
	"down": false,
}
var model: Node3D


func _ready() -> void:
	_make_character()
	_make_touch_controls()


func _physics_process(delta: float) -> void:
	var touch_x: float = 0.0
	var touch_y: float = 0.0

	if held["left"]:
		touch_x -= 1.0
	if held["right"]:
		touch_x += 1.0
	if held["up"]:
		touch_y -= 1.0
	if held["down"]:
		touch_y += 1.0

	# Keyboard arrows work too, if you connect a keyboard later.
	var movement_input: Vector2 = Input.get_vector(
		"ui_left", "ui_right", "ui_up", "ui_down"
	) + Vector2(touch_x, touch_y)
	movement_input = movement_input.limit_length(1.0)

	var move_direction := Vector3.ZERO
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		var camera_right: Vector3 = camera.global_transform.basis.x
		var camera_forward: Vector3 = -camera.global_transform.basis.z
		camera_right.y = 0.0
		camera_forward.y = 0.0
		camera_right = camera_right.normalized()
		camera_forward = camera_forward.normalized()
		move_direction = (
			camera_right * movement_input.x
			- camera_forward * movement_input.y
		).normalized()
	else:
		move_direction = Vector3(
			movement_input.x, 0.0, movement_input.y
		).normalized()

	velocity.x = move_direction.x * MOVE_SPEED
	velocity.z = move_direction.z * MOVE_SPEED
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = -0.05

	move_and_slide()

	# Turn the simple character to face its direction of travel.
	if move_direction.length_squared() > 0.001:
		var facing: float = atan2(move_direction.x, move_direction.z)
		model.rotation.y = lerp_angle(model.rotation.y, facing, minf(1.0, delta * 12.0))


func _make_character() -> void:
	model = Node3D.new()
	model.name = "Character Visual"
	add_child(model)

	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.35
	body_mesh.height = 1.8

	var blue := StandardMaterial3D.new()
	blue.albedo_color = Color("#3677cf")
	body_mesh.material = blue

	var body_visual := MeshInstance3D.new()
	body_visual.name = "Blue Capsule"
	body_visual.mesh = body_mesh
	body_visual.position.y = 0.9
	model.add_child(body_visual)

	# White marker indicates which way the character is facing.
	var marker_mesh := BoxMesh.new()
	marker_mesh.size = Vector3(0.25, 0.25, 0.15)
	var white := StandardMaterial3D.new()
	white.albedo_color = Color.WHITE
	marker_mesh.material = white

	var marker := MeshInstance3D.new()
	marker.name = "Facing Marker"
	marker.mesh = marker_mesh
	marker.position = Vector3(0.0, 1.15, 0.34)
	model.add_child(marker)

	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8

	var collision := CollisionShape3D.new()
	collision.name = "Player Collision"
	collision.shape = capsule
	collision.position.y = 0.9
	add_child(collision)


func _make_touch_controls() -> void:
	var hud := CanvasLayer.new()
	hud.name = "Mobile Controls"
	hud.layer = 10
	add_child(hud)

	var layout := Control.new()
	layout.name = "Direction Pad"
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(layout)

	_add_direction_button(layout, "UP", "up", 125, -250)
	_add_direction_button(layout, "LEFT", "left", 28, -172)
	_add_direction_button(layout, "RIGHT", "right", 222, -172)
	_add_direction_button(layout, "DOWN", "down", 125, -94)


func _add_direction_button(
	parent: Control,
	title: String,
	direction: String,
	x: float,
	y: float
) -> void:
	var button := Button.new()
	button.text = title
	button.focus_mode = Control.FOCUS_NONE
	button.anchor_left = 0.0
	button.anchor_right = 0.0
	button.anchor_top = 1.0
	button.anchor_bottom = 1.0
	button.offset_left = x
	button.offset_top = y
	button.offset_right = x + 92.0
	button.offset_bottom = y + 70.0
	parent.add_child(button)

	button.button_down.connect(_set_held.bind(direction, true))
	button.button_up.connect(_set_held.bind(direction, false))


func _set_held(direction: String, pressed: bool) -> void:
	held[direction] = pressed
