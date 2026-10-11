extends Node3D

# DUNGEON VISUALS v2.0 - STYLIZED HEROIC (Godot 4 / Android)
# Replace the script on your EXISTING DungeonVisuals Node3D.
# Visuals only: does not change Player, DungeonCombat, CombatPolish or their collisions.
# Smooth low-poly spheres, rounded bones, tapered armor and a curved cloth cape.
# Requires: Dungeon/Player, Dungeon/DungeonCombat, and the original node names.

@export_range(0.7, 1.5, 0.05) var character_visual_scale: float = 1.0
@export var animate_idle_and_walking: bool = true

var player: CharacterBody3D
var combat: Node3D
var hero: Node3D
var hero_left_leg: Node3D
var hero_right_leg: Node3D
var hero_left_arm: Node3D
var hero_right_arm: Node3D
var hero_cape: Node3D
var sword_pivot: Node3D
var sword_replaced: bool = false

var skeleton: CharacterBody3D
var skeleton_left_leg: Node3D
var skeleton_right_leg: Node3D
var skeleton_left_arm: Node3D
var skeleton_right_arm: Node3D
var skeleton_eye_l: MeshInstance3D
var skeleton_eye_r: MeshInstance3D
var skeleton_parts: Array[MeshInstance3D] = []
var skeleton_swing_timer: float = 0.0
var previous_enemy_cooldown: float = 0.0

var clock: float = 0.0
var hero_steps: float = 0.0
var enemy_steps: float = 0.0
var cached_materials: Dictionary = {}
var unit_sphere: SphereMesh
var hit_material: StandardMaterial3D


func _ready() -> void:
	# Share one sphere mesh among all rounded parts; one enemy + one hero only.
	unit_sphere = SphereMesh.new()
	unit_sphere.radius = 0.5
	unit_sphere.height = 1.0
	unit_sphere.radial_segments = 16
	unit_sphere.rings = 8
	hit_material = _mat("#ffe4ae", 0.0, 0.7, true)
	process_priority = 35


func _process(delta: float) -> void:
	clock += delta
	if player == null:
		player = get_parent().get_node_or_null("Player") as CharacterBody3D
	if combat == null:
		combat = get_parent().get_node_or_null("DungeonCombat") as Node3D

	if player != null and hero == null:
		var facing_root: Node3D = player.get_node_or_null("Character Visual") as Node3D
		if facing_root != null:
			_create_hero(facing_root)

	# DungeonCombat builds its sword with call_deferred(). It may not exist
	# in the same frame that the hero model is first created.
	if hero != null and not sword_replaced:
		_upgrade_player_sword()
	if hero != null and animate_idle_and_walking:
		_animate_hero(delta)

	if combat == null:
		return
	var current_enemy: CharacterBody3D = combat.get("enemy") as CharacterBody3D
	if current_enemy == null or not is_instance_valid(current_enemy):
		skeleton = null
		previous_enemy_cooldown = 0.0
		return
	if current_enemy != skeleton:
		_create_skeleton(current_enemy)
	if animate_idle_and_walking:
		_animate_skeleton(delta)
	_skeleton_hit_feedback()


func _create_hero(facing_root: Node3D) -> void:
	# Hide the original blue capsule, not its collision or the combat node.
	for mesh_name in ["Blue Capsule", "Facing Marker"]:
		var placeholder: MeshInstance3D = facing_root.get_node_or_null(mesh_name) as MeshInstance3D
		if placeholder != null:
			placeholder.visible = false

	hero = Node3D.new()
	hero.name = "Stylized Hero v2"
	hero.scale = Vector3.ONE * character_visual_scale
	facing_root.add_child(hero)

	# Layered blue tunic and cuirass: gently tapered and rounded, no blocks.
	_taper(hero, "Blue tunic", Vector3(0, 0.97, 0), 0.34, 0.43, 0.83, "#28689e")
	_ellipsoid(hero, "Lower cloth hem", Vector3(0, 0.62, 0.01), Vector3(0.83, 0.15, 0.61), "#164a74")
	_ellipsoid(hero, "Rounded cuirass", Vector3(0, 1.21, 0.02), Vector3(0.76, 0.66, 0.59), "#859cae", 0.42, 0.39)
	_ellipsoid(hero, "Dark chest centerpiece", Vector3(0, 1.24, 0.298), Vector3(0.41, 0.47, 0.075), "#46647d", 0.24, 0.5)
	_ellipsoid(hero, "Blue tabard", Vector3(0, 0.82, 0.285), Vector3(0.34, 0.56, 0.09), "#3489c4")
	_bone(hero, "Gold tabard seam", Vector3(0, 1.07, 0.343), Vector3(0, 0.60, 0.345), 0.045, "#e2bb66", 0.45, 0.4)
	_ellipsoid(hero, "Broad leather belt", Vector3(0, 0.83, 0), Vector3(0.84, 0.18, 0.65), "#644331")
	_ellipsoid(hero, "Gold belt buckle", Vector3(0, 0.82, 0.342), Vector3(0.20, 0.16, 0.10), "#e6c573", 0.7, 0.3)
	_ellipsoid(hero, "Buckle center", Vector3(0, 0.82, 0.402), Vector3(0.09, 0.08, 0.05), "#3a4f63")

	# Helmet: a round iron dome, visible face, nose guard, gold brow trim.
	_ellipsoid(hero, "Face", Vector3(0, 1.65, 0.10), Vector3(0.49, 0.43, 0.46), "#d5ae8a")
	_ellipsoid(hero, "Helm dome", Vector3(0, 1.82, -0.01), Vector3(0.71, 0.41, 0.69), "#647f95", 0.52, 0.34)
	_ellipsoid(hero, "Helm front", Vector3(0, 1.75, 0.20), Vector3(0.69, 0.20, 0.36), "#849dac", 0.6, 0.32)
	_bone(hero, "Raised golden brow", Vector3(-0.32, 1.75, 0.350), Vector3(0.32, 1.75, 0.350), 0.080, "#d4b26c", 0.55, 0.32)
	_bone(hero, "Nose guard", Vector3(0, 1.75, 0.39), Vector3(0, 1.52, 0.42), 0.08, "#9daeb8", 0.52, 0.3)
	_ellipsoid(hero, "Left eye", Vector3(-0.105, 1.62, 0.324), Vector3(0.060, 0.046, 0.065), "#283039")
	_ellipsoid(hero, "Right eye", Vector3(0.105, 1.62, 0.324), Vector3(0.060, 0.046, 0.065), "#283039")
	_ellipsoid(hero, "Left cheek guard", Vector3(-0.28, 1.55, 0.175), Vector3(0.145, 0.27, 0.26), "#6d889d", 0.4, 0.45)
	_ellipsoid(hero, "Right cheek guard", Vector3(0.28, 1.55, 0.175), Vector3(0.145, 0.27, 0.26), "#6d889d", 0.4, 0.45)
	_ellipsoid(hero, "Helm crest", Vector3(0, 2.04, -0.02), Vector3(0.17, 0.25, 0.54), "#db9c45")

	# Real rounded shoulder caps; arm & leg nodes rotate independently.
	hero_left_arm = _pivot(hero, "Left armored arm", Vector3(-0.47, 1.29, 0))
	hero_right_arm = _pivot(hero, "Right armored arm", Vector3(0.47, 1.29, 0))
	for arm in [hero_left_arm, hero_right_arm]:
		_ellipsoid(arm, "Round pauldron", Vector3(0, -0.05, 0), Vector3(0.52, 0.36, 0.55), "#a5b4bd", 0.5, 0.36)
		_ellipsoid(arm, "Blue sleeve", Vector3(0, -0.29, 0), Vector3(0.30, 0.48, 0.33), "#2a668d")
		_ellipsoid(arm, "Steel forearm", Vector3(0, -0.48, 0.01), Vector3(0.34, 0.34, 0.37), "#708b9d", 0.5, 0.34)
		_ellipsoid(arm, "Gauntlet", Vector3(0, -0.61, 0.07), Vector3(0.32, 0.25, 0.34), "#a4b6c3", 0.55, 0.35)
		_ellipsoid(arm, "Shoulder rivet", Vector3(0, -0.05, 0.285), Vector3(0.09, 0.09, 0.06), "#efc66f", 0.62, 0.3)

	hero_left_leg = _pivot(hero, "Left armored leg", Vector3(-0.19, 0.72, 0))
	hero_right_leg = _pivot(hero, "Right armored leg", Vector3(0.19, 0.72, 0))
	for leg in [hero_left_leg, hero_right_leg]:
		_ellipsoid(leg, "Padded trouser", Vector3(0, -0.23, 0), Vector3(0.32, 0.57, 0.37), "#334458")
		_ellipsoid(leg, "Round knee plate", Vector3(0, -0.42, 0.15), Vector3(0.34, 0.25, 0.25), "#8b9fae", 0.42, 0.44)
		_ellipsoid(leg, "Leather boot", Vector3(0, -0.56, 0.07), Vector3(0.35, 0.30, 0.51), "#594439")
		_ellipsoid(leg, "Boot metal cuff", Vector3(0, -0.48, 0.04), Vector3(0.36, 0.13, 0.40), "#738a98", 0.4, 0.55)

	hero_cape = _pivot(hero, "Draped cape", Vector3(0, 0, 0))
	_add_cape(hero_cape)
	print("DungeonVisuals v2: smooth stylized hero ready")


func _add_cape(owner: Node3D) -> void:
	# A curved cloth surface, not a flat box or a row of rectangular strips.
	var cloth: SurfaceTool = SurfaceTool.new()
	cloth.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows: int = 9
	var columns: int = 12
	for r in range(rows):
		for c in range(columns):
			var u0: float = float(c) / float(columns)
			var u1: float = float(c + 1) / float(columns)
			var v0: float = float(r) / float(rows)
			var v1: float = float(r + 1) / float(rows)
			var a: Vector3 = _cape_point(u0, v0)
			var b: Vector3 = _cape_point(u1, v0)
			var d: Vector3 = _cape_point(u0, v1)
			var e: Vector3 = _cape_point(u1, v1)
			cloth.add_vertex(a)
			cloth.add_vertex(b)
			cloth.add_vertex(d)
			cloth.add_vertex(b)
			cloth.add_vertex(e)
			cloth.add_vertex(d)
	cloth.generate_normals()
	var cape_mesh: ArrayMesh = cloth.commit()
	var cape: MeshInstance3D = MeshInstance3D.new()
	cape.name = "Curved navy cape"
	cape.mesh = cape_mesh
	var cape_material: StandardMaterial3D = _mat("#23466e", 0.0, 0.97)
	# The player can turn, so both sides of the cape must render.
	cape_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	cape.material_override = cape_material
	owner.add_child(cape)
	# Gold edging on the shoulders and lower hem makes it readable at phone scale.
	_bone(owner, "Cloak collar", Vector3(-0.37, 1.49, -0.27), Vector3(0.37, 1.49, -0.27), 0.13, "#dfad59")


func _cape_point(u: float, v: float) -> Vector3:
	var centered: float = u * 2.0 - 1.0
	var width: float = 0.35 + 0.20 * v
	var x: float = centered * width
	var y: float = 1.47 - 1.0 * v + 0.05 * cos(centered * PI) * v
	var z: float = -0.30 - 0.10 * v - 0.14 * (1.0 - centered * centered) + 0.055 * sin(u * PI * 4.0) * v
	return Vector3(x, y, z)


func _upgrade_player_sword() -> void:
	if player == null:
		return
	var visual: Node3D = player.get_node_or_null("Character Visual") as Node3D
	if visual == null:
		return
	sword_pivot = visual.get_node_or_null("Demo Sword Pivot") as Node3D
	if sword_pivot == null:
		return
	# Keep pivot and sword animation. Hide just the old rectangular weapon mesh.
	for old_piece in sword_pivot.get_children():
		if old_piece is MeshInstance3D:
			(old_piece as MeshInstance3D).visible = false
	_ellipsoid(sword_pivot, "Wrapped leather sword grip", Vector3(0, -0.12, 0), Vector3(0.16, 0.50, 0.16), "#644d36")
	_bone(sword_pivot, "Curved golden guard", Vector3(-0.32, 0.20, 0), Vector3(0.32, 0.20, 0), 0.13, "#d9b35b", 0.60, 0.33)
	_ellipsoid(sword_pivot, "Blue guard jewel", Vector3(0, 0.23, 0.115), Vector3(0.15, 0.14, 0.085), "#57c2e7", 0.1, 0.25, true)
	_ellipsoid(sword_pivot, "Steel pommel", Vector3(0, -0.40, 0), Vector3(0.22, 0.20, 0.22), "#d7bd7a", 0.6, 0.28)
	_taper(sword_pivot, "Tapered blade", Vector3(0, 0.72, 0), 0.038, 0.13, 0.89, "#d2e2e8", 0.75, 0.22, 6)
	_taper(sword_pivot, "Sharp blade tip", Vector3(0, 1.23, 0), 0.0, 0.09, 0.21, "#d2e2e8", 0.75, 0.22, 6)
	sword_replaced = true
	print("DungeonVisuals v2: upgraded sword attached to existing combat pivot")


func _create_skeleton(new_enemy: CharacterBody3D) -> void:
	skeleton = new_enemy
	skeleton_parts.clear()
	previous_enemy_cooldown = 0.0
	skeleton_swing_timer = 0.0
	# Hide the original enemy capsule & eyes; preserve collision and HP bar.
	for child in skeleton.get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).visible = false
	var skin: Node3D = Node3D.new()
	skin.name = "Stylized Skeleton v2"
	skeleton.add_child(skin)

	# Bones are all smooth ellipsoids; ribs arc outward and back to the sternum.
	_ellipsoid(skin, "Bone pelvis", Vector3(0, 0.73, 0), Vector3(0.52, 0.26, 0.38), "#d8d0b6", 0.0, 0.95, false, true)
	_bone(skin, "Spinal column", Vector3(0, 0.79, 0.0), Vector3(0, 1.31, -0.04), 0.16, "#e4ddc8", 0.0, 0.9, true)
	for h in [0.99, 1.12, 1.24]:
		_ellipsoid(skin, "Spine vertebra", Vector3(0, h, -0.01), Vector3(0.23, 0.13, 0.18), "#e9e1c9", 0.0, 0.94, false, true)
		for side in [-1.0, 1.0]:
			var outer: Vector3 = Vector3(side * 0.32, h + 0.045, 0.065)
			_bone(skin, "Curving side rib", Vector3(side * 0.07, h, -0.04), outer, 0.12, "#e8dfc6", 0.0, 0.92, true)
			_bone(skin, "Front rib tip", outer, Vector3(side * 0.085, h - 0.06, 0.22), 0.105, "#d9cfb4", 0.0, 0.92, true)
	_bone(skin, "Sternum", Vector3(0, 0.95, 0.23), Vector3(0, 1.30, 0.19), 0.12, "#d5cdb9", 0.0, 0.90, true)
	for side in [-1.0, 1.0]:
		_bone(skin, "Bony collar", Vector3(side * 0.10, 1.36, -0.02), Vector3(side * 0.45, 1.28, -0.01), 0.15, "#e9e2ce", 0.0, 0.9, true)

	# Big cartoon-game skull, dark eye sockets and emissive orange eyes.
	_ellipsoid(skin, "Big rounded skull", Vector3(0, 1.67, -0.035), Vector3(0.66, 0.64, 0.60), "#eee5cd", 0.0, 0.85, false, true)
	_ellipsoid(skin, "Cheekbones", Vector3(0, 1.48, 0.19), Vector3(0.56, 0.23, 0.31), "#e1d6ba", 0.0, 0.87, false, true)
	_ellipsoid(skin, "Lower jaw", Vector3(0, 1.35, 0.18), Vector3(0.43, 0.17, 0.30), "#c9bea4", 0.0, 0.9, false, true)
	_ellipsoid(skin, "Nose cavity", Vector3(0, 1.50, 0.307), Vector3(0.085, 0.12, 0.07), "#3c393b", 0.0, 0.9, false, true)
	for side in [-1.0, 1.0]:
		_ellipsoid(skin, "Dark eye socket", Vector3(side * 0.16, 1.68, 0.252), Vector3(0.23, 0.22, 0.10), "#302f35", 0.0, 0.96, false, true)
	skeleton_eye_l = _ellipsoid(skin, "Left glowing eye", Vector3(-0.16, 1.675, 0.313), Vector3(0.11, 0.11, 0.068), "#ff693f", 0.0, 0.5, true, true)
	skeleton_eye_r = _ellipsoid(skin, "Right glowing eye", Vector3(0.16, 1.675, 0.313), Vector3(0.11, 0.11, 0.068), "#ff693f", 0.0, 0.5, true, true)
	for i in range(4):
		var x: float = (float(i) - 1.5) * 0.09
		_ellipsoid(skin, "Short bone teeth", Vector3(x, 1.346, 0.323), Vector3(0.075, 0.10, 0.035), "#fff2d9", 0.0, 0.75, false, true)

	skeleton_left_arm = _pivot(skin, "Left skeleton arm", Vector3(-0.45, 1.28, 0))
	skeleton_right_arm = _pivot(skin, "Right skeleton arm", Vector3(0.45, 1.28, 0))
	for arm in [skeleton_left_arm, skeleton_right_arm]:
		_ellipsoid(arm, "Round shoulder joint", Vector3(0, 0, 0), Vector3(0.29, 0.29, 0.31), "#e6ddc4", 0.0, 0.89, false, true)
		_bone(arm, "Upper arm bone", Vector3(0, -0.10, 0), Vector3(0, -0.36, 0), 0.17, "#d9d0b9", 0.0, 0.89, true)
		_ellipsoid(arm, "Round elbow", Vector3(0, -0.37, 0), Vector3(0.19, 0.18, 0.19), "#f0e6cb", 0.0, 0.89, false, true)
		_bone(arm, "Forearm bone", Vector3(0, -0.40, 0), Vector3(0, -0.65, 0.01), 0.14, "#d9d0b9", 0.0, 0.9, true)
		_ellipsoid(arm, "Clenched bone hand", Vector3(0, -0.68, 0.04), Vector3(0.24, 0.22, 0.23), "#e3d9bf", 0.0, 0.87, false, true)

	skeleton_left_leg = _pivot(skin, "Left skeleton leg", Vector3(-0.18, 0.72, 0))
	skeleton_right_leg = _pivot(skin, "Right skeleton leg", Vector3(0.18, 0.72, 0))
	for leg in [skeleton_left_leg, skeleton_right_leg]:
		_bone(leg, "Thigh bone", Vector3(0, -0.09, 0), Vector3(0, -0.36, 0), 0.21, "#e0d6be", 0.0, 0.89, true)
		_ellipsoid(leg, "Kneecap", Vector3(0, -0.40, 0.045), Vector3(0.24, 0.20, 0.24), "#f0e7d1", 0.0, 0.89, false, true)
		_bone(leg, "Shin bone", Vector3(0, -0.45, 0), Vector3(0, -0.65, 0), 0.15, "#d9d0b9", 0.0, 0.89, true)
		_ellipsoid(leg, "Long bone foot", Vector3(0, -0.69, 0.105), Vector3(0.27, 0.15, 0.41), "#e4d7bc", 0.0, 0.9, false, true)

	# Rusted weapon attached to the same animated right-arm pivot.
	var weapon: Node3D = _pivot(skeleton_right_arm, "Rusty weapon pivot", Vector3(0, -0.64, 0.055))
	weapon.rotation_degrees.x = -13.0
	_ellipsoid(weapon, "Leather wrapped grip", Vector3(0, 0.03, 0), Vector3(0.12, 0.39, 0.12), "#554135", 0.0, 0.95, false, true)
	_bone(weapon, "Rusted sword guard", Vector3(-0.22, 0.22, 0), Vector3(0.22, 0.22, 0), 0.11, "#92603f", 0.4, 0.65, true)
	_taper(weapon, "Rusted steel blade", Vector3(0, 0.61, 0), 0.045, 0.125, 0.70, "#8d9290", 0.48, 0.66, 6, true)
	_taper(weapon, "Sharp rusted tip", Vector3(0, 1.06, 0), 0.0, 0.09, 0.23, "#7e817b", 0.45, 0.69, 6, true)
	print("DungeonVisuals v2: rounded skeleton ready")


func _animate_hero(delta: float) -> void:
	if player == null:
		return
	var speed: float = Vector2(player.velocity.x, player.velocity.z).length()
	var weight: float = clampf(speed / 4.0, 0.0, 1.0)
	hero_steps += delta * (5.0 + speed * 0.9) * weight
	var stride: float = sin(hero_steps) * 0.62 * weight
	var smoothing: float = minf(1.0, delta * 12.0)
	var dodging: bool = player.has_method("is_dodging") and bool(player.call("is_dodging"))
	if dodging:
		stride = 0.0
	hero_left_leg.rotation.x = lerpf(hero_left_leg.rotation.x, stride, smoothing)
	hero_right_leg.rotation.x = lerpf(hero_right_leg.rotation.x, -stride, smoothing)
	hero_left_arm.rotation.x = lerpf(hero_left_arm.rotation.x, -stride * 0.46, smoothing)
	var right_arm_target: float = stride * 0.24
	if sword_pivot != null and is_instance_valid(sword_pivot):
		# Match the working sword swing without taking over its pivot/tween.
		right_arm_target += sword_pivot.rotation.x * 0.50
	hero_right_arm.rotation.x = lerpf(hero_right_arm.rotation.x, right_arm_target, smoothing)
	hero.position.y = sin(clock * 2.7) * 0.016 + absf(sin(hero_steps)) * 0.038 * weight
	if hero_cape != null:
		hero_cape.rotation.x = sin(clock * 2.8) * 0.035 + weight * 0.055
		hero_cape.rotation.z = sin(hero_steps) * 0.025 * weight


func _animate_skeleton(delta: float) -> void:
	if skeleton == null or not is_instance_valid(skeleton):
		return
	var speed: float = Vector2(skeleton.velocity.x, skeleton.velocity.z).length()
	var walking: float = clampf(speed / 1.65, 0.0, 1.0)
	enemy_steps += delta * 7.5 * walking
	var stride: float = sin(enemy_steps) * 0.55 * walking
	var smoothing: float = minf(1.0, delta * 11.0)
	skeleton_left_leg.rotation.x = lerpf(skeleton_left_leg.rotation.x, stride, smoothing)
	skeleton_right_leg.rotation.x = lerpf(skeleton_right_leg.rotation.x, -stride, smoothing)
	skeleton_left_arm.rotation.x = lerpf(skeleton_left_arm.rotation.x, -stride * 0.5, smoothing)

	# EnemyCombat resets its cooldown when an enemy ATTACKS.
	var cooldown: float = float(combat.get("enemy_cooldown"))
	if cooldown > previous_enemy_cooldown + 0.35:
		skeleton_swing_timer = 0.38
	previous_enemy_cooldown = cooldown
	skeleton_swing_timer = maxf(0.0, skeleton_swing_timer - delta)
	var strike: float = stride * 0.23
	if skeleton_swing_timer > 0.0:
		var progress: float = (0.38 - skeleton_swing_timer) / 0.38
		strike = -1.15 * sin(progress * PI)
	skeleton_right_arm.rotation.x = lerpf(skeleton_right_arm.rotation.x, strike, smoothing)
	# Subtle glow pulse is safe on mobile; shared materials are not modified.
	if skeleton_eye_l != null and is_instance_valid(skeleton_eye_l):
		var pulse: float = 1.0 + 0.13 * sin(clock * 4.6)
		skeleton_eye_l.scale = Vector3(0.11, 0.11, 0.068) * pulse
		skeleton_eye_r.scale = Vector3(0.11, 0.11, 0.068) * pulse


func _skeleton_hit_feedback() -> void:
	if combat == null or skeleton == null or not is_instance_valid(skeleton):
		return
	var flashing: bool = float(combat.get("flash_timer")) > 0.0
	for visual in skeleton_parts:
		if is_instance_valid(visual):
			visual.material_override = hit_material if flashing else _restore_material(visual)


func _restore_material(visual: MeshInstance3D) -> StandardMaterial3D:
	# material_overlay would not restore per-mesh color after a flash.
	# Store the original instance material in metadata when each part is built.
	return visual.get_meta("normal_material") as StandardMaterial3D


func _pivot(parent: Node3D, label: String, at: Vector3) -> Node3D:
	var node: Node3D = Node3D.new()
	node.name = label
	node.position = at
	parent.add_child(node)
	return node


func _mat(hex_color: String, metallic: float = 0.0, roughness: float = 0.8, glow: bool = false) -> StandardMaterial3D:
	var key: String = "%s|%.2f|%.2f|%s" % [hex_color, metallic, roughness, str(glow)]
	if cached_materials.has(key):
		return cached_materials[key] as StandardMaterial3D
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(hex_color)
	material.metallic = metallic
	material.roughness = roughness
	if glow:
		material.emission_enabled = true
		material.emission = Color(hex_color)
		material.emission_energy_multiplier = 1.6
	cached_materials[key] = material
	return material


func _part(parent: Node3D, label: String, mesh: Mesh, where: Vector3, tint: String, metallic: float = 0.0, roughness: float = 0.8, glow: bool = false, is_enemy: bool = false) -> MeshInstance3D:
	var part: MeshInstance3D = MeshInstance3D.new()
	part.name = label
	part.mesh = mesh
	part.position = where
	var material: StandardMaterial3D = _mat(tint, metallic, roughness, glow)
	part.material_override = material
	if is_enemy:
		part.set_meta("normal_material", material)
		skeleton_parts.append(part)
	parent.add_child(part)
	return part


func _ellipsoid(parent: Node3D, label: String, center: Vector3, diameters: Vector3, tint: String, metallic: float = 0.0, roughness: float = 0.8, glow: bool = false, is_enemy: bool = false) -> MeshInstance3D:
	var part: MeshInstance3D = _part(parent, label, unit_sphere, center, tint, metallic, roughness, glow, is_enemy)
	part.scale = diameters
	return part


func _bone(parent: Node3D, label: String, start: Vector3, finish: Vector3, width: float, tint: String, metallic: float = 0.0, roughness: float = 0.8, is_enemy: bool = false) -> MeshInstance3D:
	var segment: Vector3 = finish - start
	var part: MeshInstance3D = _ellipsoid(parent, label, (start + finish) * 0.5, Vector3(width, segment.length() + width * 0.2, width), tint, metallic, roughness, false, is_enemy)
	if segment.length_squared() > 0.00001:
		var direction: Vector3 = segment.normalized()
		# Vertical up or down bones already look correct without rotation.
		if absf(direction.y) < 0.999:
			part.quaternion = Quaternion(Vector3.UP, direction)
	return part


func _taper(parent: Node3D, label: String, center: Vector3, top: float, bottom: float, height: float, tint: String, metallic: float = 0.0, roughness: float = 0.8, sides: int = 12, is_enemy: bool = false) -> MeshInstance3D:
	var cylinder: CylinderMesh = CylinderMesh.new()
	cylinder.top_radius = top
	cylinder.bottom_radius = bottom
	cylinder.height = height
	cylinder.radial_segments = sides
	cylinder.rings = 1
	return _part(parent, label, cylinder, center, tint, metallic, roughness, false, is_enemy)
