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
	print("DungeonCombat ready: move toward the red enemy and tap ATTACK.")


func _physics_process(delta: float) -> void:
	if not initialized or encounter_finished:
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

	attack_button = Button.new()
	attack_button.name = "Attack or Restart Button"
	attack_button.text = "ATTACK"
	attack_button.focus_mode = Control.FOCUS_NONE
	attack_button.add_theme_font_size_override("font_size", 30)
	attack_button.anchor_left = 1.0
	attack_button.anchor_right = 1.0
	attack_button.anchor_top = 1.0
	attack_button.anchor_bottom = 1.0
	attack_button.offset_left = -245.0
	attack_button.offset_right = -28.0
	attack_button.offset_top = -158.0
	attack_button.offset_bottom = -50.0
	ui.add_child(attack_button)
	attack_button.pressed.connect(_on_attack_pressed)


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

	player_cooldown = PLAYER_COOLDOWN
	_animate_sword()
	if enemy == null or not is_instance_valid(enemy):
		return

	# Mobile-friendly automatic targeting: the sword hits a nearby enemy.
	var distance_vector: Vector3 = enemy.global_position - player.global_position
	distance_vector.y = 0.0
	if distance_vector.length() <= PLAYER_ATTACK_RANGE:
		_damage_enemy(PLAYER_DAMAGE)
	else:
		message_label.text = "Too far away! Move closer."


func _animate_sword() -> void:
	if sword_pivot == null:
		return
	if sword_tween != null and sword_tween.is_running():
		sword_tween.kill()
	sword_pivot.rotation.z = 0.45
	sword_tween = create_tween()
	sword_tween.tween_property(sword_pivot, "rotation", Vector3(0.0, 0.0, -1.25), 0.13)
	sword_tween.tween_property(sword_pivot, "rotation", Vector3.ZERO, 0.19)


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
		attack_button.text = "RESTART"
	_update_hud()


func _damage_player(amount: int) -> void:
	player_health = maxi(0, player_health - amount)
	message_label.text = "The enemy hit you! -%d HP" % amount
	if player_health == 0:
		encounter_finished = true
		player.velocity = Vector3.ZERO
		player.set_physics_process(false)
		message_label.text = "DEFEAT! Tap RESTART to try again."
		attack_button.text = "RESTART"
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
	if sword_pivot != null:
		sword_pivot.rotation = Vector3.ZERO
	_spawn_enemy()
	attack_button.text = "ATTACK"
	message_label.text = "New fight! Move closer and tap ATTACK."
	_update_hud()


func _update_hud() -> void:
	if player_label != null:
		player_label.text = "PLAYER HP: %d / %d" % [player_health, PLAYER_MAX_HEALTH]
	if enemy_label != null:
		enemy_label.text = "ENEMY HP: %d / %d" % [enemy_health, ENEMY_MAX_HEALTH]
