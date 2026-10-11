extends CharacterBody3D

# Mobile analog joystick upgrade for the original DungeonCrawler Player.
# Attach to the existing Player CharacterBody3D in place of Player.gd.
# Keeps the "Character Visual" node so DungeonVisuals and DungeonCombat
# still attach the adventurer and sword to the correct character.
# Works with Godot 4.x on Android. Supports a second finger on ATTACK.

const MOVE_SPEED: float = 4.0
const GRAVITY: float = 18.0
const STICK_DIAMETER: float = 224.0
const STICK_RANGE: float = 77.0
const KNOB_DIAMETER: float = 78.0
const DEAD_ZONE: float = 0.14
const LEFT_MARGIN: float = 44.0
const BOTTOM_MARGIN: float = 42.0

var model: Node3D
var joystick_input: Vector2 = Vector2.ZERO
var active_touch: int = -1   # -1 = no touch; -2 = desktop mouse
var joystick_base: Panel
var joystick_knob: Panel


func _ready() -> void:
	_make_character()
	_make_joystick()


func _physics_process(delta: float) -> void:
	# Keyboard arrows still work if a keyboard is connected.
	var keyboard_input: Vector2 = Input.get_vector(
		"ui_left", "ui_right", "ui_up", "ui_down"
	)
	var movement_input: Vector2 = (joystick_input + keyboard_input).limit_length(1.0)

	# Walk relative to the active isometric camera, just like original Player.gd.
	var move_direction: Vector3 = Vector3.ZERO
	var camera: Camera3D = get_viewport().get_camera_3d()
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
		move_direction = Vector3(movement_input.x, 0.0, movement_input.y).normalized()

	# Unlike the four buttons, partial stick tilt means partial speed.
	var speed_multiplier: float = movement_input.length()
	velocity.x = move_direction.x * MOVE_SPEED * speed_multiplier
	velocity.z = move_direction.z * MOVE_SPEED * speed_multiplier
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = -0.05
	move_and_slide()

	# Keep the original visual node + facing convention for sword swings.
	if move_direction.length_squared() > 0.001:
		var facing: float = atan2(move_direction.x, move_direction.z)
		model.rotation.y = lerp_angle(
			model.rotation.y, facing, minf(1.0, delta * 12.0)
		)


func _input(event: InputEvent) -> void:
	# Only the finger that STARTS on the joystick can drive movement.
	# A second finger anywhere else can press the existing ATTACK button.
	if event is InputEventScreenTouch:
		if event.pressed:
			if active_touch == -1 and _is_over_stick(event.position):
				active_touch = event.index
				_move_stick(event.position)
		elif event.index == active_touch:
			_release_stick()
	elif event is InputEventScreenDrag:
		if event.index == active_touch:
			_move_stick(event.position)

	# Desktop fallback for testing the same scene using a mouse.
	# Ignoring emulated mouse clicks on Android avoids duplicate touch tracking.
	elif not OS.has_feature("mobile"):
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT:
				if event.pressed:
					if active_touch == -1 and _is_over_stick(event.position):
						active_touch = -2
						_move_stick(event.position)
				elif active_touch == -2:
					_release_stick()
		elif event is InputEventMouseMotion and active_touch == -2:
			_move_stick(event.position)


func _is_over_stick(screen_position: Vector2) -> bool:
	if joystick_base == null:
		return false
	var center: Vector2 = joystick_base.get_global_rect().get_center()
	return screen_position.distance_to(center) <= STICK_DIAMETER * 0.54


func _move_stick(screen_position: Vector2) -> void:
	var center: Vector2 = joystick_base.get_global_rect().get_center()
	var displacement: Vector2 = (screen_position - center).limit_length(STICK_RANGE)
	var raw_input: Vector2 = displacement / STICK_RANGE

	# Small dead zone prevents accidental creeping when releasing the stick.
	var strength: float = raw_input.length()
	if strength < DEAD_ZONE:
		joystick_input = Vector2.ZERO
	else:
		var adjusted_strength: float = (strength - DEAD_ZONE) / (1.0 - DEAD_ZONE)
		joystick_input = raw_input.normalized() * adjusted_strength

	var knob_start: float = (STICK_DIAMETER - KNOB_DIAMETER) * 0.5
	joystick_knob.position = Vector2(knob_start, knob_start) + displacement


func _release_stick() -> void:
	active_touch = -1
	joystick_input = Vector2.ZERO
	var knob_start: float = (STICK_DIAMETER - KNOB_DIAMETER) * 0.5
	joystick_knob.position = Vector2(knob_start, knob_start)


func _make_joystick() -> void:
	var hud: CanvasLayer = CanvasLayer.new()
	hud.name = "Mobile Joystick HUD"
	hud.layer = 10
	add_child(hud)

	joystick_base = Panel.new()
	joystick_base.name = "Joystick Base"
	joystick_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	joystick_base.anchor_left = 0.0
	joystick_base.anchor_right = 0.0
	joystick_base.anchor_top = 1.0
	joystick_base.anchor_bottom = 1.0
	joystick_base.offset_left = LEFT_MARGIN
	joystick_base.offset_right = LEFT_MARGIN + STICK_DIAMETER
	joystick_base.offset_top = -BOTTOM_MARGIN - STICK_DIAMETER
	joystick_base.offset_bottom = -BOTTOM_MARGIN
	joystick_base.add_theme_stylebox_override(
		"panel",
		_circle_style(Color(0.09, 0.14, 0.21, 0.55), Color(0.72, 0.82, 0.96, 0.67), 4)
	)
	hud.add_child(joystick_base)

	joystick_knob = Panel.new()
	joystick_knob.name = "Moveable Thumbstick"
	joystick_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	joystick_knob.size = Vector2(KNOB_DIAMETER, KNOB_DIAMETER)
	var knob_start: float = (STICK_DIAMETER - KNOB_DIAMETER) * 0.5
	joystick_knob.position = Vector2(knob_start, knob_start)
	joystick_knob.add_theme_stylebox_override(
		"panel",
		_circle_style(Color(0.56, 0.77, 0.95, 0.84), Color(0.92, 0.97, 1.0, 0.93), 3)
	)
	joystick_base.add_child(joystick_knob)


func _circle_style(fill_color: Color, outline_color: Color, border_width: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill_color
	style.set_corner_radius_all(200)
	style.border_color = outline_color
	style.set_border_width_all(border_width)
	style.anti_aliasing = true
	return style


func _make_character() -> void:
	# This is kept compatible with the original starter Player.gd so the
	# other working scripts can still find and attach to "Character Visual".
	model = Node3D.new()
	model.name = "Character Visual"
	add_child(model)

	var body_mesh: CapsuleMesh = CapsuleMesh.new()
	body_mesh.radius = 0.35
	body_mesh.height = 1.8
	var blue: StandardMaterial3D = StandardMaterial3D.new()
	blue.albedo_color = Color("#3677cf")
	body_mesh.material = blue
	var body_visual: MeshInstance3D = MeshInstance3D.new()
	body_visual.name = "Blue Capsule"
	body_visual.mesh = body_mesh
	body_visual.position.y = 0.9
	model.add_child(body_visual)

	var marker_mesh: BoxMesh = BoxMesh.new()
	marker_mesh.size = Vector3(0.25, 0.25, 0.15)
	var white: StandardMaterial3D = StandardMaterial3D.new()
	white.albedo_color = Color.WHITE
	marker_mesh.material = white
	var marker: MeshInstance3D = MeshInstance3D.new()
	marker.name = "Facing Marker"
	marker.mesh = marker_mesh
	marker.position = Vector3(0.0, 1.15, 0.34)
	model.add_child(marker)

	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.name = "Player Collision"
	collision.shape = capsule
	collision.position.y = 0.9
	add_child(collision)
