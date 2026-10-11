extends Node3D

# Godot 4.x: optional visual-only upgrade for the phone dungeon project.
# Attach to a NEW Node3D named DungeonVisuals under the existing Dungeon root.
# Keeps Player.gd and dungeon_combat.gd unchanged.
# Adds a stylized armored adventurer, a skeleton, and basic walk/hit animation.

var player: CharacterBody3D
var combat: Node3D
var hero_skin: Node3D
var hero_left_leg: Node3D
var hero_right_leg: Node3D
var hero_left_arm: Node3D
var hero_right_arm: Node3D
var enemy_ref: CharacterBody3D
var enemy_left_leg: Node3D
var enemy_right_leg: Node3D
var enemy_left_arm: Node3D
var enemy_right_arm: Node3D
var enemy_meshes: Array[MeshInstance3D] = []
var hero_step: float = 0.0
var enemy_step: float = 0.0
var enemy_attack_time: float = 0.0
var previous_enemy_cooldown: float = 0.0
var cached_materials: Dictionary = {}
var damage_material: StandardMaterial3D


func _ready() -> void:
	damage_material = _material("#ffe58a")


func _process(delta: float) -> void:
	# The combat script creates the enemy at runtime. Looking it up here
	# also handles pressing RESTART, which creates a brand-new enemy.
	if player == null:
		player = get_parent().get_node_or_null("Player") as CharacterBody3D
	if combat == null:
		combat = get_parent().get_node_or_null("DungeonCombat") as Node3D

	if player != null and hero_skin == null:
		var facing_root: Node3D = player.get_node_or_null("Character Visual") as Node3D
		if facing_root != null:
			_create_hero(facing_root)

	if hero_skin != null and is_instance_valid(hero_skin):
		_animate_hero(delta)

	if combat == null:
		return

	var current_enemy: CharacterBody3D = combat.get("enemy") as CharacterBody3D
	if current_enemy == null or not is_instance_valid(current_enemy):
		enemy_ref = null
		previous_enemy_cooldown = 0.0
		return

	if current_enemy != enemy_ref:
		_create_skeleton(current_enemy)

	_animate_skeleton(delta)


func _create_hero(facing_root: Node3D) -> void:
	# Hide ONLY the original placeholder meshes; preserve collision and sword.
	var capsule: MeshInstance3D = facing_root.get_node_or_null("Blue Capsule") as MeshInstance3D
	var marker: MeshInstance3D = facing_root.get_node_or_null("Facing Marker") as MeshInstance3D
	if capsule != null:
		capsule.visible = false
	if marker != null:
		marker.visible = false

	hero_skin = Node3D.new()
	hero_skin.name = "Procedural Adventurer"
	facing_root.add_child(hero_skin)

	# Cloak, tunic, leather belt and steel breastplate.
	_box(hero_skin, "Red cloak", Vector3(0.69, 0.85, 0.12), Vector3(0, 0.90, -0.28), "#753e42")
	_box(hero_skin, "Tunic", Vector3(0.72, 0.67, 0.45), Vector3(0, 1.02, 0), "#27485d")
	_box(hero_skin, "Breastplate", Vector3(0.55, 0.47, 0.49), Vector3(0, 1.13, 0.04), "#899aa5")
	_box(hero_skin, "Leather belt", Vector3(0.78, 0.15, 0.48), Vector3(0, 0.76, 0), "#503728")
	_box(hero_skin, "Belt buckle", Vector3(0.17, 0.16, 0.09), Vector3(0, 0.76, 0.29), "#d9bd72")

	# Face and helm: all meshes face local positive Z.
	_sphere(hero_skin, "Face", 0.23, Vector3(0, 1.56, 0.04), "#dab59a")
	_box(hero_skin, "Helmet crown", Vector3(0.56, 0.24, 0.53), Vector3(0, 1.78, 0.00), "#657784")
	_box(hero_skin, "Helmet visor", Vector3(0.57, 0.09, 0.10), Vector3(0, 1.63, 0.26), "#9dabb4")
	_box(hero_skin, "Nose guard", Vector3(0.08, 0.28, 0.10), Vector3(0, 1.50, 0.30), "#a4afb3")
	_box(hero_skin, "Left eye", Vector3(0.055, 0.04, 0.04), Vector3(-0.10, 1.57, 0.255), "#222629")
	_box(hero_skin, "Right eye", Vector3(0.055, 0.04, 0.04), Vector3(0.10, 1.57, 0.255), "#222629")

	hero_left_leg = _pivot(hero_skin, "Left leg", Vector3(-0.19, 0.70, 0))
	hero_right_leg = _pivot(hero_skin, "Right leg", Vector3(0.19, 0.70, 0))
	for leg in [hero_left_leg, hero_right_leg]:
		_box(leg, "Trouser", Vector3(0.27, 0.49, 0.28), Vector3(0, -0.26, 0), "#3d3a40")
		_box(leg, "Boot", Vector3(0.30, 0.30, 0.35), Vector3(0, -0.55, 0.065), "#533d2f")

	hero_left_arm = _pivot(hero_skin, "Left arm", Vector3(-0.47, 1.26, 0))
	hero_right_arm = _pivot(hero_skin, "Right arm", Vector3(0.47, 1.26, 0))
	for arm in [hero_left_arm, hero_right_arm]:
		_box(arm, "Shoulder plate", Vector3(0.32, 0.23, 0.41), Vector3(0, -0.06, 0), "#83939b")
		_box(arm, "Sleeve", Vector3(0.25, 0.40, 0.27), Vector3(0, -0.32, 0), "#284657")
		_box(arm, "Gauntlet", Vector3(0.27, 0.22, 0.29), Vector3(0, -0.56, 0.02), "#81929b")

	print("DungeonVisuals: adventurer ready.")


func _create_skeleton(new_enemy: CharacterBody3D) -> void:
	enemy_ref = new_enemy
	enemy_meshes.clear()
	previous_enemy_cooldown = 0.0
	enemy_attack_time = 0.0

	# The old red capsule and yellow eyes belong to combat logic. Hide them,
	# rather than deleting them, so combat continues to run unchanged.
	for original in enemy_ref.get_children():
		if original is MeshInstance3D:
			(original as MeshInstance3D).visible = false

	var skin := Node3D.new()
	skin.name = "Procedural Skeleton"
	enemy_ref.add_child(skin)

	_enemy_box(skin, "Pelvis", Vector3(0.53, 0.19, 0.30), Vector3(0, 0.72, 0), "#c8c4ad")
	_enemy_box(skin, "Spine", Vector3(0.15, 0.51, 0.19), Vector3(0, 0.99, 0), "#ddd7c1")
	for height in [0.95, 1.07, 1.18]:
		_enemy_box(skin, "Rib left", Vector3(0.31, 0.10, 0.20), Vector3(-0.20, height, 0.04), "#c8c4ad")
		_enemy_box(skin, "Rib right", Vector3(0.31, 0.10, 0.20), Vector3(0.20, height, 0.04), "#c8c4ad")

	_enemy_sphere(skin, "Skull", 0.26, Vector3(0, 1.43, 0.04), "#dfdac8")
	_enemy_box(skin, "Jaw", Vector3(0.32, 0.12, 0.24), Vector3(0, 1.24, 0.17), "#c8c4ad")
	_enemy_box(skin, "Left eye socket", Vector3(0.12, 0.11, 0.06), Vector3(-0.105, 1.45, 0.27), "#292b30")
	_enemy_box(skin, "Right eye socket", Vector3(0.12, 0.11, 0.06), Vector3(0.105, 1.45, 0.27), "#292b30")
	_enemy_box(skin, "Left glow", Vector3(0.055, 0.052, 0.064), Vector3(-0.105, 1.45, 0.32), "#eb5e4e")
	_enemy_box(skin, "Right glow", Vector3(0.055, 0.052, 0.064), Vector3(0.105, 1.45, 0.32), "#eb5e4e")
	_enemy_box(skin, "Rusty chest strap", Vector3(0.64, 0.11, 0.14), Vector3(0, 1.13, 0.18), "#7c4937")

	enemy_left_leg = _pivot(skin, "Left skeleton leg", Vector3(-0.18, 0.73, 0))
	enemy_right_leg = _pivot(skin, "Right skeleton leg", Vector3(0.18, 0.73, 0))
	for leg in [enemy_left_leg, enemy_right_leg]:
		_enemy_box(leg, "Leg bone", Vector3(0.15, 0.47, 0.15), Vector3(0, -0.27, 0), "#c8c4ad")
		_enemy_box(leg, "Knee", Vector3(0.22, 0.13, 0.20), Vector3(0, -0.49, 0), "#e5decb")
		_enemy_box(leg, "Foot", Vector3(0.24, 0.14, 0.35), Vector3(0, -0.64, 0.10), "#c8c4ad")

	enemy_left_arm = _pivot(skin, "Left skeleton arm", Vector3(-0.43, 1.19, 0))
	enemy_right_arm = _pivot(skin, "Right skeleton arm", Vector3(0.43, 1.19, 0))
	for arm in [enemy_left_arm, enemy_right_arm]:
		_enemy_sphere(arm, "Shoulder joint", 0.13, Vector3(0, 0, 0), "#ddd7c1")
		_enemy_box(arm, "Arm bone", Vector3(0.13, 0.51, 0.14), Vector3(0, -0.27, 0), "#c8c4ad")
		_enemy_box(arm, "Bone hand", Vector3(0.19, 0.17, 0.20), Vector3(0, -0.56, 0), "#e5decb")

	# Short rusted blade: attaches to the skeleton's moving right arm.
	_enemy_box(enemy_right_arm, "Rusty grip", Vector3(0.10, 0.30, 0.11), Vector3(0.0, -0.68, 0.04), "#5b4332")
	_enemy_box(enemy_right_arm, "Rusty blade", Vector3(0.15, 0.64, 0.09), Vector3(0.0, -1.08, 0.04), "#7d8483")

	print("DungeonVisuals: skeleton ready.")


func _animate_hero(delta: float) -> void:
	var moving: float = Vector2(player.velocity.x, player.velocity.z).length()
	if moving > 0.2:
		hero_step += delta * 9.0
	var swing: float = sin(hero_step) * 0.48 if moving > 0.2 else 0.0
	var blend: float = minf(1.0, delta * 12.0)
	hero_left_leg.rotation.x = lerpf(hero_left_leg.rotation.x, swing, blend)
	hero_right_leg.rotation.x = lerpf(hero_right_leg.rotation.x, -swing, blend)
	hero_left_arm.rotation.x = lerpf(hero_left_arm.rotation.x, -swing * 0.55, blend)
	hero_right_arm.rotation.x = lerpf(hero_right_arm.rotation.x, swing * 0.35, blend)


func _animate_skeleton(delta: float) -> void:
	if enemy_ref == null or not is_instance_valid(enemy_ref):
		return
	var moving: float = Vector2(enemy_ref.velocity.x, enemy_ref.velocity.z).length()
	if moving > 0.2:
		enemy_step += delta * 9.0
	var swing: float = sin(enemy_step) * 0.47 if moving > 0.2 else 0.0
	var blend: float = minf(1.0, delta * 12.0)
	enemy_left_leg.rotation.x = lerpf(enemy_left_leg.rotation.x, swing, blend)
	enemy_right_leg.rotation.x = lerpf(enemy_right_leg.rotation.x, -swing, blend)
	enemy_left_arm.rotation.x = lerpf(enemy_left_arm.rotation.x, -swing * 0.55, blend)

	# The existing combat script resets this cooldown when an enemy hits.
	var current_cooldown: float = float(combat.get("enemy_cooldown"))
	if previous_enemy_cooldown < 0.10 and current_cooldown > 0.90:
		enemy_attack_time = 0.32
	previous_enemy_cooldown = current_cooldown
	enemy_attack_time = maxf(0.0, enemy_attack_time - delta)
	var arm_target: float = swing * 0.45
	if enemy_attack_time > 0.0:
		arm_target = -1.10 * sin((0.32 - enemy_attack_time) / 0.32 * PI)
	enemy_right_arm.rotation.x = lerpf(enemy_right_arm.rotation.x, arm_target, blend)

	# Preserve the original combat hit timing, but flash the new meshes.
	var hit_now: bool = float(combat.get("flash_timer")) > 0.0
	for part in enemy_meshes:
		if is_instance_valid(part):
			part.material_override = damage_material if hit_now else null


func _pivot(owner: Node3D, label: String, offset: Vector3) -> Node3D:
	var node := Node3D.new()
	node.name = label
	node.position = offset
	owner.add_child(node)
	return node


func _material(color_hex: String) -> StandardMaterial3D:
	if cached_materials.has(color_hex):
		return cached_materials[color_hex] as StandardMaterial3D
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color_hex)
	material.roughness = 0.82
	cached_materials[color_hex] = material
	return material


func _box(owner: Node3D, label: String, size: Vector3, offset: Vector3, color_hex: String) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _material(color_hex)
	var visual := MeshInstance3D.new()
	visual.name = label
	visual.mesh = mesh
	visual.position = offset
	owner.add_child(visual)
	return visual


func _sphere(owner: Node3D, label: String, radius: float, offset: Vector3, color_hex: String) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	mesh.material = _material(color_hex)
	var visual := MeshInstance3D.new()
	visual.name = label
	visual.mesh = mesh
	visual.position = offset
	owner.add_child(visual)
	return visual


func _enemy_box(owner: Node3D, label: String, size: Vector3, offset: Vector3, color_hex: String) -> void:
	enemy_meshes.append(_box(owner, label, size, offset, color_hex))


func _enemy_sphere(owner: Node3D, label: String, radius: float, offset: Vector3, color_hex: String) -> void:
	enemy_meshes.append(_sphere(owner, label, radius, offset, color_hex))
