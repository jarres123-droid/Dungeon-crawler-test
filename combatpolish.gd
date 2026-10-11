extends Node3D

# Dungeon Combat Polish v1.0 (Godot 4.x, including Android editor)
# Attach to a NEW Node3D named CombatPolish, under the existing Dungeon root.
# This script observes the existing DungeonCombat values; it does NOT replace
# dungeon_combat.gd, Player.gd, follow_camera.gd, or dungeon_visuals_v1.gd.
#
# Adds: an enemy overhead HP bar, floating hit numbers, hit impact effects,
# mild collision-aware knockback, player damage feedback, and bone fragments
# on victory. Everything is generated in code; no assets or Input Map edits.

@export_range(0.0, 1.5, 0.05) var knockback_distance: float = 0.65
@export_range(0.08, 0.5, 0.02) var knockback_duration: float = 0.17
@export var show_damage_numbers: bool = true
@export var show_enemy_health_bar: bool = true

var combat: Node3D
var player: CharacterBody3D
var enemy: CharacterBody3D
var hp_bar: Node3D
var hp_fill: MeshInstance3D
var last_enemy_position: Vector3 = Vector3.ZERO
var last_player_hp: int = 100
var last_enemy_hp: int = 100
var knockback_direction: Vector3 = Vector3.ZERO
var knockback_remaining: float = 0.0
var initialized: bool = false

var mat_hp_background: StandardMaterial3D
var mat_hp_fill: StandardMaterial3D
var mat_bone: StandardMaterial3D
var bone_box: BoxMesh


func _ready() -> void:
	# Run after the original scripts have spawned the player and enemy.
	process_priority = 50
	mat_hp_background = _make_material(Color("#181b23"))
	mat_hp_fill = _make_material(Color("#69d77b"))
	mat_bone = _make_material(Color("#d3cbb5"))
	bone_box = BoxMesh.new()
	bone_box.size = Vector3(0.13, 0.28, 0.13)
	call_deferred("_find_combat")


func _find_combat() -> void:
	combat = get_parent().get_node_or_null("DungeonCombat") as Node3D
	player = get_parent().get_node_or_null("Player") as CharacterBody3D
	if combat == null or player == null:
		push_warning("CombatPolish: Need DungeonCombat and Player under Dungeon.")
		return
	last_player_hp = int(combat.get("player_health"))
	last_enemy_hp = int(combat.get("enemy_health"))
	_bind_enemy()
	initialized = true
	print("CombatPolish v1 ready: health bar, hit feedback and knockback active.")


func _process(_delta: float) -> void:
	if not initialized:
		return

	# The original combat script creates a new enemy when RESTART is pressed.
	var current_enemy: CharacterBody3D = combat.get("enemy") as CharacterBody3D
	var current_player_hp: int = int(combat.get("player_health"))
	var current_enemy_hp: int = int(combat.get("enemy_health"))

	if current_player_hp < last_player_hp:
		var loss: int = last_player_hp - current_player_hp
		_player_hit_effect(loss)
	last_player_hp = current_player_hp

	if current_enemy_hp < last_enemy_hp:
		var loss: int = last_enemy_hp - current_enemy_hp
		_enemy_hit_effect(loss, current_enemy_hp == 0)
	last_enemy_hp = current_enemy_hp

	# Check health BEFORE enemy changes: the original script queues the enemy
	# for deletion as soon as its HP reaches zero.
	if current_enemy != enemy:
		_bind_enemy()
	# The original script already animates the sword. Leave it untouched.
	_update_bar(current_enemy_hp)

	if enemy != null and is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
		last_enemy_position = enemy.global_position
		if hp_bar != null and is_instance_valid(hp_bar):
			var camera: Camera3D = get_viewport().get_camera_3d()
			if camera != null:
				# A 3D health bar always faces the active follow camera.
				hp_bar.look_at(camera.global_position, Vector3.UP)


func _physics_process(delta: float) -> void:
	if knockback_remaining <= 0.0:
		return
	if enemy == null or not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
		knockback_remaining = 0.0
		return
	var actual_step: float = minf(delta, knockback_remaining)
	var push_speed: float = knockback_distance / maxf(0.05, knockback_duration)
	enemy.move_and_collide(knockback_direction * push_speed * actual_step)
	knockback_remaining -= actual_step


func _bind_enemy() -> void:
	enemy = combat.get("enemy") as CharacterBody3D
	hp_bar = null
	hp_fill = null
	knockback_remaining = 0.0
	if enemy == null or not is_instance_valid(enemy):
		return
	last_enemy_position = enemy.global_position
	if not show_enemy_health_bar:
		return

	hp_bar = Node3D.new()
	hp_bar.name = "Overhead Enemy HP"
	hp_bar.position = Vector3(0.0, 2.12, 0.0)
	enemy.add_child(hp_bar)

	var background: MeshInstance3D = _bar_piece("HP Background", 0.92, 0.14, mat_hp_background)
	background.position.z = 0.015
	hp_bar.add_child(background)

	hp_fill = _bar_piece("HP Fill", 0.83, 0.085, mat_hp_fill)
	hp_fill.position.z = -0.004
	hp_bar.add_child(hp_fill)
	_update_bar(int(combat.get("enemy_health")))


func _update_bar(hp: int) -> void:
	if hp_fill == null or not is_instance_valid(hp_fill):
		return
	# The working dungeon_combat.gd uses 100 max enemy HP.
	var maximum: int = 100
	var ratio: float = clampf(float(hp) / float(maximum), 0.0, 1.0)
	hp_fill.scale.x = maxf(ratio, 0.001)
	hp_fill.position.x = -0.415 * (1.0 - ratio)
	hp_fill.visible = ratio > 0.0


func _enemy_hit_effect(damage: int, killed: bool) -> void:
	var impact: Vector3 = last_enemy_position + Vector3(0.0, 1.0, 0.0)
	if enemy != null and is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
		impact = enemy.global_position + Vector3(0.0, 1.0, 0.0)

	_impact_flash(impact, Color("#ffd875"))
	if show_damage_numbers:
		_floating_number(impact + Vector3(0.0, 0.5, 0.0), "-%d" % damage, Color("#ffd875"))

	if killed:
		knockback_remaining = 0.0
		_bone_burst(impact)
	elif enemy != null and is_instance_valid(enemy) and player != null:
		knockback_direction = enemy.global_position - player.global_position
		knockback_direction.y = 0.0
		if knockback_direction.length_squared() > 0.0001:
			knockback_direction = knockback_direction.normalized()
			knockback_remaining = knockback_duration


func _player_hit_effect(damage: int) -> void:
	if player == null or not is_instance_valid(player):
		return
	var impact: Vector3 = player.global_position + Vector3(0.0, 1.1, 0.0)
	_impact_flash(impact, Color("#f56a63"))
	if show_damage_numbers:
		_floating_number(impact + Vector3(0.0, 0.45, 0.0), "-%d" % damage, Color("#ff9b98"))


func _impact_flash(at: Vector3, tint: Color) -> void:
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.16
	sphere.height = 0.32
	sphere.radial_segments = 8
	sphere.rings = 4

	var flash: MeshInstance3D = MeshInstance3D.new()
	flash.name = "Temporary Hit Flash"
	flash.mesh = sphere
	flash.material_override = _make_material(tint)
	add_child(flash)
	flash.global_position = at
	var tw: Tween = create_tween()
	tw.tween_property(flash, "scale", Vector3(3.2, 3.2, 3.2), 0.19)
	tw.parallel().tween_property(flash, "transparency", 1.0, 0.19)
	tw.tween_callback(flash.queue_free)


func _floating_number(at: Vector3, value: String, tint: Color) -> void:
	var number: Label3D = Label3D.new()
	number.name = "Floating Damage"
	number.text = value
	number.font_size = 58
	number.pixel_size = 0.004
	number.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	number.no_depth_test = true
	number.modulate = tint
	add_child(number)
	number.global_position = at
	var tw: Tween = create_tween()
	tw.tween_property(number, "global_position", at + Vector3(0, 0.8, 0), 0.62)
	tw.parallel().tween_property(number, "transparency", 1.0, 0.62)
	tw.tween_callback(number.queue_free)


func _bone_burst(at: Vector3) -> void:
	# Decorative fragments only. Existing RESTART behavior remains untouched.
	for i in range(6):
		var bit: MeshInstance3D = MeshInstance3D.new()
		bit.name = "Temporary Bone Fragment"
		bit.mesh = bone_box
		bit.material_override = mat_bone
		add_child(bit)
		bit.global_position = at
		var angle: float = float(i) * TAU / 6.0
		var destination: Vector3 = at + Vector3(cos(angle) * 0.85, 0.35, sin(angle) * 0.85)
		var tw: Tween = create_tween()
		tw.tween_property(bit, "global_position", destination, 0.37)
		tw.parallel().tween_property(bit, "rotation", Vector3(1.8, angle, 1.4), 0.37)
		tw.tween_property(bit, "transparency", 1.0, 0.28)
		tw.tween_callback(bit.queue_free)


func _bar_piece(label: String, width: float, height: float, material: StandardMaterial3D) -> MeshInstance3D:
	var block: BoxMesh = BoxMesh.new()
	block.size = Vector3(width, height, 0.018)
	var obj: MeshInstance3D = MeshInstance3D.new()
	obj.name = label
	obj.mesh = block
	obj.material_override = material
	return obj


func _make_material(tint: Color) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.roughness = 1.0
	return mat
