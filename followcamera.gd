extends Camera3D

# Smooth isometric follow camera for Godot 4.
# Attach this script to a Camera3D named FollowCamera,
# added directly beneath the Dungeon node (beside Player).

const CAMERA_OFFSET: Vector3 = Vector3(20.0, 24.0, 20.0)
const FOLLOW_SPEED: float = 6.0

@onready var player: Node3D = get_node_or_null("../Player") as Node3D


func _ready() -> void:
	if player == null:
		push_error("FollowCamera: Could not find ../Player. Put this camera directly under Dungeon, beside Player.")
		return

	projection = Camera3D.PROJECTION_ORTHOGONAL
	size = 14.0

	# Start in position, looking toward the character.
	global_position = player.global_position + CAMERA_OFFSET
	look_at(player.global_position + Vector3(0.0, 1.0, 0.0), Vector3.UP)

	# dungeon.gd creates its own camera in its _ready() function.
	# Waiting until the end of this frame ensures this camera becomes active.
	call_deferred("make_current")


func _process(delta: float) -> void:
	if player == null:
		return

	var target_position: Vector3 = player.global_position + CAMERA_OFFSET
	var smoothing: float = clampf(FOLLOW_SPEED * delta, 0.0, 1.0)
	global_position = global_position.lerp(target_position, smoothing)
