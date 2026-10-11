extends Node3D

# Godot 4.x mobile combat demo.
# Attach to a NEW Node3D named DungeonCombat directly under Dungeon.
# Requires an existing CharacterBody3D sibling named Player.
# Does not replace Dungeon.gd, Player.gd, follow_camera.gd, or dungeon_details.gd.

const PLAYER_MAX_HEALTH: int = 100
const ENEMY_MAX_HEALTH: int = 100
const PLAYER_DAMAGE: int = 25
const ENEMY_DAMAGE: int = 12
const PLAYER_ATTACK_RANGE: float = 2.55
# The weapon now hits only within this forward-facing cone.
# 120 degrees = 60 degrees to the left + 60 degrees to the right.
# Change to 90 for more precision, or 150 to make aiming easier.
const PLAYER_ATTACK_ARC_DEGREES: float = 120.0
const ENEMY_ATTACK_RANGE: float = 1.55
const ENEMY_CHASE_RANGE: float = 10.0
const ENEMY_SPEED: float = 1.65
const PLAYER_COOLDOWN: float = 0.55
const ENEMY_COOLDOWN: float = 1.35
const ENEMY_START: Vector3 = Vector3(3.0, 0.1, -2.0)

var player: CharacterBody3D
var enemy: CharacterBody3D
var enemy_visual: MeshInstance3D
var sword_pivot: Node3D
var attack_button: Button
var dodge_button: Button
var sword_icon: Texture2D
var dodge_icon: Texture2D
var player_label: Label
var enemy_label: Label
var message_label: Label
var player_start: Vector3
var player_health: int = PLAYER_MAX_HEALTH
var enemy_health: int = ENEMY_MAX_HEALTH
var player_cooldown: float = 0.0
var enemy_cooldown: float = 0.0
var flash_timer: float = 0.0
var encounter_finished: bool = false
var initialized: bool = false
var sword_tween: Tween

var enemy_normal_material: StandardMaterial3D
var enemy_hit_material: StandardMaterial3D


func _ready() -> void:
	# Children become ready before Dungeon.gd creates its room in _ready().
	# Deferring also ensures Player.gd has created its visible character.
	call_deferred("_initialize_combat")


func _initialize_combat() -> void:
	player = get_parent().get_node_or_null("Player") as CharacterBody3D
	if player == null:
		push_error("DungeonCombat: Could not find a CharacterBody3D named Player under Dungeon.")
		return

	player_start = player.global_position
	enemy_normal_material = _material(Color("#bb3539"))
	enemy_hit_material = _material(Color("#ffe184"))
	_create_sword()
	_create_hud()
	_spawn_enemy()
	initialized = true
	_update_hud()
	_refresh_dodge_button()
	print("DungeonCombat ready: sword attack + directional dodge roll.")
	if not player.has_method("start_dodge"):
		push_warning("DungeonCombat: Attach Player_joystick_dodge_v1.gd to Player to activate dodge.")


func _physics_process(delta: float) -> void:
	if not initialized:
		return
	_refresh_dodge_button()
	if encounter_finished:
		return

	player_cooldown = maxf(0.0, player_cooldown - delta)
	enemy_cooldown = maxf(0.0, enemy_cooldown - delta)
	flash_timer = maxf(0.0, flash_timer - delta)

	if enemy == null or not is_instance_valid(enemy):
		return

	if enemy_visual != null:
		if flash_timer > 0.0:
			enemy_visual.material_override = enemy_hit_material
		else:
			enemy_visual.material_override = enemy_normal_material

	var offset: Vector3 = player.global_position - enemy.global_position
	offset.y = 0.0
	var distance: float = offset.length()

	if distance < ENEMY_CHASE_RANGE and distance > ENEMY_ATTACK_RANGE:
		var move_direction: Vector3 = offset.normalized()
		enemy.velocity.x = move_direction.x * ENEMY_SPEED
		enemy.velocity.z = move_direction.z * ENEMY_SPEED
		enemy.rotation.y = atan2(move_direction.x, move_direction.z)
	else:
		enemy.velocity.x = 0.0
		enemy.velocity.z = 0.0

	if not enemy.is_on_floor():
		enemy.velocity.y -= 18.0 * delta
	else:
		enemy.velocity.y = -0.05
	enemy.move_and_slide()

	# Re-measure after movement so enemy hits only when truly nearby.
	offset = player.global_position - enemy.global_position
	offset.y = 0.0
	if offset.length() <= ENEMY_ATTACK_RANGE and enemy_cooldown <= 0.0:
		enemy_cooldown = ENEMY_COOLDOWN
		_damage_player(ENEMY_DAMAGE)


func _spawn_enemy() -> void:
	enemy = CharacterBody3D.new()
	enemy.name = "Red Dungeon Enemy"
	enemy.collision_layer = 1
	enemy.collision_mask = 1
	add_child(enemy)
	enemy.global_position = ENEMY_START

	var shape := CapsuleShape3D.new()
	shape.radius = 0.40
	shape.height = 1.65
	var collider := CollisionShape3D.new()
	collider.name = "Enemy Collision"
	collider.shape = shape
	collider.position.y = 0.825
	enemy.add_child(collider)

	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.40
	body_mesh.height = 1.65
	enemy_visual = MeshInstance3D.new()
	enemy_visual.name = "Red Enemy Body"
	enemy_visual.mesh = body_mesh
	enemy_visual.position.y = 0.825
	enemy_visual.material_override = enemy_normal_material
	enemy.add_child(enemy_visual)

	# Two yellow eyes make it easy to tell which way the enemy faces.
	_make_box(enemy, "Left Eye", Vector3(0.12, 0.12, 0.07), Vector3(-0.17, 1.11, 0.38), Color("#ffda61"))
	_make_box(enemy, "Right Eye", Vector3(0.12, 0.12, 0.07), Vector3(0.17, 1.11, 0.38), Color("#ffda61"))


func _create_sword() -> void:
	var character_visual := player.get_node_or_null("Character Visual") as Node3D
	if character_visual == null:
		# Still works even if you replace the player's visual later.
		character_visual = player

	sword_pivot = Node3D.new()
	sword_pivot.name = "Demo Sword Pivot"
	sword_pivot.position = Vector3(0.56, 0.81, 0.15)
	character_visual.add_child(sword_pivot)

	_make_box(sword_pivot, "Sword Grip", Vector3(0.13, 0.50, 0.13), Vector3(0.0, -0.10, 0.0), Color("#593b26"))
	_make_box(sword_pivot, "Crossguard", Vector3(0.56, 0.12, 0.17), Vector3(0.0, 0.18, 0.0), Color("#d2ae5d"))
	_make_box(sword_pivot, "Steel Blade", Vector3(0.15, 1.06, 0.10), Vector3(0.0, 0.76, 0.0), Color("#c7d4dc"))
	_make_box(sword_pivot, "Pommel", Vector3(0.22, 0.20, 0.20), Vector3(0.0, -0.40, 0.0), Color("#d2ae5d"))


func _make_box(owner: Node3D, label: String, dimensions: Vector3, offset: Vector3, tint: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	var visual := MeshInstance3D.new()
	visual.name = label
	visual.mesh = mesh
	visual.material_override = _material(tint)
	visual.position = offset
	owner.add_child(visual)
	return visual


func _material(tint: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.roughness = 0.8
	return mat


func _create_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Combat HUD"
	layer.layer = 20
	add_child(layer)

	var ui := Control.new()
	ui.name = "Combat UI"
	layer.add_child(ui)
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE

	player_label = _make_label(ui, "PLAYER HP: 100 / 100", 20.0, 13.0, 400.0, 46.0)
	enemy_label = _make_label(ui, "ENEMY HP: 100 / 100", 20.0, 57.0, 400.0, 46.0)
	message_label = _make_label(ui, "Move closer, then tap ATTACK.", 20.0, 104.0, 700.0, 48.0)
	message_label.add_theme_font_size_override("font_size", 23)

	sword_icon = _embedded_png(SWORD_ICON_B64)
	dodge_icon = _embedded_png(DODGE_ICON_B64)

	# Touch-friendly circular actions: sword on lower right, dodge just above it.
	attack_button = _make_action_circle(
		ui, "Attack or Restart Button", 126.0, 34.0, 45.0,
		Color("#a43d39"), Color("#f8c7ad")
	)
	attack_button.icon = sword_icon
	attack_button.text = "" if sword_icon != null else "ATK"
	attack_button.tooltip_text = "Sword attack"
	attack_button.pressed.connect(_on_attack_pressed)

	dodge_button = _make_action_circle(
		ui, "Dodge Button", 108.0, 176.0, 132.0,
		Color("#235c80"), Color("#b9e6fd")
	)
	dodge_button.icon = dodge_icon
	dodge_button.text = "" if dodge_icon != null else "ROLL"
	dodge_button.tooltip_text = "Dodge roll"
	dodge_button.pressed.connect(_on_dodge_pressed)



# PNGs are embedded directly so Android users copy only TWO .gd files.
const SWORD_ICON_B64: String = "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"
const DODGE_ICON_B64: String = "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"


func _embedded_png(encoded: String) -> Texture2D:
	var picture: Image = Image.new()
	var result: int = picture.load_png_from_buffer(Marshalls.base64_to_raw(encoded))
	if result != OK:
		push_warning("Combat UI: Could not decode embedded button icon.")
		return null
	return ImageTexture.create_from_image(picture)


func _button_circle(fill: Color, rim: Color) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = rim
	box.set_border_width_all(4)
	box.set_corner_radius_all(200)
	box.anti_aliasing = true
	return box


func _make_action_circle(
	owner: Control, caption: String, diameter: float,
	right_margin: float, bottom_margin: float,
	fill: Color, rim: Color
) -> Button:
	var action: Button = Button.new()
	action.name = caption
	action.focus_mode = Control.FOCUS_NONE
	action.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	action.alignment = HORIZONTAL_ALIGNMENT_CENTER
	action.add_theme_font_size_override("font_size", 20)
	action.add_theme_color_override("font_color", Color("#fffaf5"))
	action.anchor_left = 1.0
	action.anchor_right = 1.0
	action.anchor_top = 1.0
	action.anchor_bottom = 1.0
	action.offset_left = -right_margin - diameter
	action.offset_right = -right_margin
	action.offset_top = -bottom_margin - diameter
	action.offset_bottom = -bottom_margin
	action.add_theme_stylebox_override("normal", _button_circle(fill, rim))
	action.add_theme_stylebox_override("hover", _button_circle(fill.lightened(0.12), rim))
	action.add_theme_stylebox_override("pressed", _button_circle(fill.darkened(0.22), rim))
	action.add_theme_stylebox_override("disabled", _button_circle(fill.darkened(0.53), rim.darkened(0.45)))
	action.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	owner.add_child(action)
	return action


func _refresh_dodge_button() -> void:
	if dodge_button == null:
		return
	if player == null or not player.has_method("can_dodge"):
		dodge_button.disabled = true
		return
	dodge_button.disabled = encounter_finished or not bool(player.call("can_dodge"))


func _on_dodge_pressed() -> void:
	if not initialized or encounter_finished or player == null:
		return
	if not player.has_method("start_dodge"):
		return
	if bool(player.call("start_dodge")):
		message_label.text = "DODGE! Enemy attacks cannot hurt you while rolling."
	_refresh_dodge_button()


func _make_label(owner: Control, caption: String, x: float, y: float, width: float, height: float) -> Label:
	var label := Label.new()
	label.text = caption
	label.position = Vector2(x, y)
	label.size = Vector2(width, height)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 29)
	label.add_theme_color_override("font_color", Color("#f7f0e1"))
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	owner.add_child(label)
	return label


func _on_attack_pressed() -> void:
	if not initialized:
		return
	if encounter_finished:
		_restart_encounter()
		return
	if player_cooldown > 0.0:
		return
	if player.has_method("is_dodging") and bool(player.call("is_dodging")):
		return  # No attacking during a roll.

	player_cooldown = PLAYER_COOLDOWN
	_animate_sword()
	if enemy == null or not is_instance_valid(enemy):
		return

	# Damage applies only to a target close enough AND in front of the hero.
	var to_enemy: Vector3 = enemy.global_position - player.global_position
	to_enemy.y = 0.0
	if to_enemy.length() > PLAYER_ATTACK_RANGE:
		message_label.text = "Too far away! Move closer."
	elif _enemy_is_in_attack_arc(to_enemy):
		_damage_enemy(PLAYER_DAMAGE)
	else:
		message_label.text = "Miss! Face the skeleton before attacking."


func _enemy_is_in_attack_arc(to_enemy: Vector3) -> bool:
	# Player_joystick_v1.gd turns "Character Visual" toward movement.
	# This player's local +Z points in the direction it faces.
	var character_visual: Node3D = player.get_node_or_null("Character Visual") as Node3D
	var facing: Vector3 = player.global_transform.basis.z
	if character_visual != null:
		facing = character_visual.global_transform.basis.z
	facing.y = 0.0

	# Treat nearly overlapping bodies as inside the arc.
	if to_enemy.length_squared() < 0.0001:
		return true
	if facing.length_squared() < 0.0001:
		return false

	# Dot product >= cos(half-arc) means the enemy is in front.
	var alignment: float = facing.normalized().dot(to_enemy.normalized())
	var minimum_alignment: float = cos(deg_to_rad(PLAYER_ATTACK_ARC_DEGREES * 0.5))
	return alignment >= minimum_alignment


func _animate_sword() -> void:
	if sword_pivot == null:
		return
	if sword_tween != null and sword_tween.is_running():
		sword_tween.kill()

	# The sword is a child of the player's Character Visual node.
	# Player.gd rotates that node so local +Z points in the facing direction.
	# Rotate the sword forward around local X, not sideways around local Z.
	# The small Y/Z changes add a diagonal slash across the player's front.
	sword_pivot.rotation = Vector3(-0.65, 0.30, -0.10)
	sword_tween = create_tween()
	sword_tween.tween_property(
		sword_pivot, "rotation", Vector3(1.20, -0.25, 0.17), 0.20
	)
	sword_tween.tween_property(
		sword_pivot, "rotation", Vector3.ZERO, 0.18
	)


func _damage_enemy(amount: int) -> void:
	enemy_health = maxi(0, enemy_health - amount)
	flash_timer = 0.20
	message_label.text = "Hit! -%d enemy HP" % amount
	if enemy_health == 0:
		encounter_finished = true
		enemy.queue_free()
		enemy = null
		enemy_visual = null
		message_label.text = "VICTORY! Tap RESTART for another fight."
		attack_button.icon = null
		attack_button.text = "RESTART"
		_refresh_dodge_button()
	_update_hud()


func _damage_player(amount: int) -> void:
	# This is an arcade dodge window, not physical collision avoidance.
	if player.has_method("is_dodging") and bool(player.call("is_dodging")):
		message_label.text = "DODGED!"
		return
	player_health = maxi(0, player_health - amount)
	message_label.text = "The enemy hit you! -%d HP" % amount
	if player_health == 0:
		encounter_finished = true
		player.velocity = Vector3.ZERO
		player.set_physics_process(false)
		message_label.text = "DEFEAT! Tap RESTART to try again."
		attack_button.icon = null
		attack_button.text = "RESTART"
		_refresh_dodge_button()
	_update_hud()


func _restart_encounter() -> void:
	if enemy != null and is_instance_valid(enemy):
		enemy.queue_free()
		enemy = null
	player_health = PLAYER_MAX_HEALTH
	enemy_health = ENEMY_MAX_HEALTH
	player_cooldown = 0.0
	enemy_cooldown = 0.0
	flash_timer = 0.0
	encounter_finished = false
	player.global_position = player_start
	player.velocity = Vector3.ZERO
	player.set_physics_process(true)
	if player.has_method("reset_dodge"):
		player.call("reset_dodge")
	if sword_pivot != null:
		sword_pivot.rotation = Vector3.ZERO
	_spawn_enemy()
	attack_button.text = "" if sword_icon != null else "ATK"
	attack_button.icon = sword_icon
	_refresh_dodge_button()
	message_label.text = "New fight! Move with joystick; sword and dodge on right."
	_update_hud()


func _update_hud() -> void:
	if player_label != null:
		player_label.text = "PLAYER HP: %d / %d" % [player_health, PLAYER_MAX_HEALTH]
	if enemy_label != null:
		enemy_label.text = "ENEMY HP: %d / %d" % [enemy_health, ENEMY_MAX_HEALTH]
