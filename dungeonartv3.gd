
extends "res://dungeonartv2.gd"

# DUNGEON ART v3 -- richer procedural dressing for the existing
# procedural generator. Attach this to the SAME DungeonArt node
# you already created in procedural_dungeon.tscn.
# This version focuses on stronger room identity, denser decoration,
# more corridor accents, and better variety while keeping central paths open.

@export_enum("Subtle", "Normal", "Rich") var prop_density: int = 2
@export var extra_magic_lights: bool = true


func _floor_accents(center: Vector3, theme: String) -> void:
	var count: int = 16 if detail_quality == 0 else (34 if detail_quality == 1 else 52)
	if prop_density == 0:
		count = int(round(float(count) * 0.75))
	elif prop_density == 2:
		count = int(round(float(count) * 1.22))

	for i in range(count):
		var x: float = randomizer.randf_range(-6.9, 6.9)
		var z: float = randomizer.randf_range(-6.9, 6.9)
		if absf(x) < 2.1 or absf(z) < 2.1:
			continue
		var at: Vector3 = center + Vector3(x, 0.058, z)
		var roll: float = randomizer.randf()
		if roll < 0.16:
			_orb("stone3", at + Vector3(0.0, 0.05, 0.0), Vector3(0.24, 0.11, 0.18))
		elif roll < 0.30:
			_box("dark", at, Vector3(randomizer.randf_range(0.24, 0.75), 0.016,
				randomizer.randf_range(0.07, 0.16)), randomizer.randf_range(-1.2, 1.2))
		elif roll < 0.40:
			_box("moss" if theme in ["CRYPT", "RUINS", "PRISON"] else "stone4",
				at, Vector3(randomizer.randf_range(0.15, 0.40), 0.012,
				randomizer.randf_range(0.14, 0.42)), randomizer.randf_range(-2.2, 2.2))
		else:
			_box("stone4" if randomizer.randf() < 0.55 else "moss2",
				at, Vector3(randomizer.randf_range(0.14, 0.50), 0.014,
				randomizer.randf_range(0.05, 0.18)), randomizer.randf_range(-1.7, 1.7))

	if detail_quality > 0:
		_corner_rubble(center + Vector3(-5.9, 0.0, 5.9), 6)
		_corner_rubble(center + Vector3(5.9, 0.0, 5.7), 4)
		if theme in ["CRYPT", "RUINS", "PRISON"]:
			_corner_rubble(center + Vector3(-5.9, 0.0, -5.8), 5)
		if theme in ["FORGE", "ARMORY", "ENTRY"]:
			_corner_rubble(center + Vector3(5.9, 0.0, -5.7), 5)

	if theme == "ENTRY":
		_rug(center + Vector3(-3.8, 0, 2.7), "cloth_blue")
	elif theme == "CRYPT":
		_rug(center + Vector3(3.8, 0, 2.7), "cloth_red")
	elif theme == "LIBRARY" or theme == "ARMORY":
		_rug(center + Vector3(-3.8, 0, 2.7), "cloth_purple")
	elif theme == "SANCTUM":
		_rune_circle(center, "gold")
	elif theme == "SHRINE":
		_rune_circle(center, "aqua")


func _wall_masonry(center: Vector3, cell: Vector2i) -> void:
	super._wall_masonry(center, cell)
	if detail_quality == 0:
		return
	# Add deeper-looking wall braces / buttresses for more visual interest.
	for dir in DIRECTIONS:
		var connected: bool = _linked(cell, cell + dir)
		var near: bool = dir.x > 0 or dir.y > 0
		if near:
			continue
		var base_y: float = 1.25
		for u in [-5.6, 5.6]:
			if connected and absf(u) < 2.4:
				continue
			var at: Vector3 = center + Vector3(float(dir.x) * 7.18, base_y, float(dir.y) * 7.18)
			if dir.x != 0:
				at.z += u
				_box("stone0", at, Vector3(0.34, 2.45, 0.92))
				_box("stone4", at + Vector3(-float(dir.x) * 0.08, 1.15, 0.0), Vector3(0.16, 0.13, 1.05))
			else:
				at.x += u
				_box("stone0", at, Vector3(0.92, 2.45, 0.34))
				_box("stone4", at + Vector3(0.0, 1.15, -float(dir.y) * 0.08), Vector3(1.05, 0.13, 0.16))


func _decorate_corridors(cells: Array) -> void:
	super._decorate_corridors(cells)
	for c in cells:
		var cell: Vector2i = c
		for direction in [Vector2i(1, 0), Vector2i(0, 1)]:
			if not _linked(cell, cell + direction):
				continue
			var middle: Vector3 = _center(cell) + Vector3(
				float(direction.x) * SPACING * 0.5, 0.0,
				float(direction.y) * SPACING * 0.5
			)
			# Small side clutter that never blocks the walk lane.
			if direction.x != 0:
				_barrel(middle + Vector3(0.0, 0.0, 2.95))
				if detail_quality > 0:
					_urn(middle + Vector3(0.0, 0.0, -2.95), false)
					_wall_shelf(middle + Vector3(-1.3, 0.0, -3.95), false)
			else:
				_barrel(middle + Vector3(2.95, 0.0, 0.0))
				if detail_quality > 0:
					_urn(middle + Vector3(-2.95, 0.0, 0.0), false)
					_wall_shelf(middle + Vector3(-3.95, 0.0, -1.3), true)
			if detail_quality > 1 or prop_density > 0:
				_corridor_torch_pair(middle, direction)


func _entry_room(center: Vector3) -> void:
	_banner(center + Vector3(-4.7, 0, -7.48), "cloth_blue")
	_banner(center + Vector3(4.0, 0, -7.48), "cloth_red")
	_pile_crates(center + Vector3(-5.3, 0, 3.5))
	_barrel(center + Vector3(5.3, 0, 3.1))
	_barrel(center + Vector3(4.35, 0, 3.6))
	_bench(center + Vector3(-4.45, 0, -4.15))
	_war_table(center + Vector3(4.3, 0, -4.0))
	_weapon_stand(center + Vector3(5.3, 0, -1.2))


func _crypt_room(center: Vector3) -> void:
	_sarcophagus(center + Vector3(-4.6, 0, 3.7))
	_sarcophagus(center + Vector3(4.5, 0, 3.55))
	_sarcophagus(center + Vector3(0.0, 0, -4.6))
	_bones(center + Vector3(-4.35, 0, -3.85))
	_bones(center + Vector3(4.2, 0, -3.85))
	_urn_cluster(center + Vector3(5.1, 0, 2.9))
	_urn_cluster(center + Vector3(-5.1, 0, 2.9))
	_banner(center + Vector3(-3.75, 0, -7.48), "cloth_purple")
	_banner(center + Vector3(3.10, 0, -7.48), "cloth_red")
	_pillar_brazier(center + Vector3(0.0, 0.0, 4.95), false)


func _armory_room(center: Vector3) -> void:
	_weapon_rack(center + Vector3(-4.45, 0, -6.30))
	_weapon_rack(center + Vector3(4.45, 0, -6.30))
	_shield_rack(center + Vector3(-6.35, 0, 0.0), true)
	_shield_rack(center + Vector3(6.35, 0, 0.0), true)
	_pile_crates(center + Vector3(-4.95, 0, 3.55))
	_pile_crates(center + Vector3(3.15, 0, 3.05))
	_barrel(center + Vector3(5.5, 0, 3.45))
	_weapon_stand(center + Vector3(0.0, 0, 4.85))
	_banner(center + Vector3(0, 0, -7.48), "cloth_red")


func _library_room(center: Vector3) -> void:
	_bookcase(center + Vector3(-4.35, 0, -6.35))
	_bookcase(center + Vector3(0.0, 0, -6.35))
	_bookcase(center + Vector3(4.35, 0, -6.35))
	_reading_table(center + Vector3(-4.35, 0, 3.6))
	_reading_table(center + Vector3(4.10, 0, 3.25))
	_scroll_pile(center + Vector3(-3.95, 0, 4.35))
	_scroll_pile(center + Vector3(4.25, 0, 4.05))
	_pile_crates(center + Vector3(0.0, 0, 3.55))


func _prison_room(center: Vector3) -> void:
	_iron_cage(center + Vector3(-4.75, 0, 3.7))
	_iron_cage(center + Vector3(4.75, 0, 3.7))
	_bench(center + Vector3(0.0, 0, -4.1))
	_bones(center + Vector3(-4.55, 0, -3.9))
	_bones(center + Vector3(4.45, 0, -3.75))
	for x in [-5.3, -4.5, 4.5, 5.3]:
		_chain(center + Vector3(x, 2.56, -6.95))
	_banner(center + Vector3(0.0, 0, -7.48), "cloth_red")


func _forge_room(center: Vector3) -> void:
	_forge_hearth(center + Vector3(-4.95, 0, -5.75))
	_anvil(center + Vector3(-4.55, 0, 3.55))
	_pile_crates(center + Vector3(4.1, 0, 3.0))
	_barrel(center + Vector3(5.3, 0, 3.6))
	_tool_bench(center + Vector3(4.15, 0, -4.0))
	_coal_pile(center + Vector3(-3.7, 0, -4.1))
	_weapon_stand(center + Vector3(5.5, 0, -1.0))


func _shrine_room(center: Vector3) -> void:
	_altar(center + Vector3(0.0, 0, 0.0), true)
	_pillar_brazier(center + Vector3(-5.0, 0, 4.7), true)
	_pillar_brazier(center + Vector3(5.0, 0, 4.7), true)
	_banner(center + Vector3(-4.0, 0, -7.48), "cloth_purple")
	_banner(center + Vector3(3.0, 0, -7.48), "cloth_blue")
	_cylinder("stone4", center + Vector3(-4.8, 0.24, -3.95), 0.48, 0.44)
	_cylinder("stone4", center + Vector3(4.8, 0.24, -3.95), 0.48, 0.44)
	_orb("violet", center + Vector3(-4.8, 0.78, -3.95), Vector3(0.30, 0.60, 0.30))
	_orb("aqua", center + Vector3(4.8, 0.78, -3.95), Vector3(0.30, 0.60, 0.30))


func _ruins_room(center: Vector3) -> void:
	for i in range(22 if detail_quality == 2 else 14):
		var x: float = randomizer.randf_range(-6.5, 6.2)
		var z: float = randomizer.randf_range(-6.2, 6.4)
		if absf(x) < 2.2 and absf(z) < 2.2:
			continue
		_box("stone3" if randomizer.randf() < 0.5 else "stone4",
			center + Vector3(x, 0.14, z),
			Vector3(randomizer.randf_range(0.18, 0.9), 0.18,
			randomizer.randf_range(0.18, 0.78)), randomizer.randf_range(-1.4, 1.4))
	_broken_column(center + Vector3(-5.2, 0, 3.7))
	_broken_column(center + Vector3(4.7, 0, -4.0))
	_bones(center + Vector3(4.1, 0, 3.7))
	_banner(center + Vector3(3.65, 0, -7.48), "cloth_red")
	_barrel(center + Vector3(4.35, 0, 2.95))
	_orb("moss2", center + Vector3(-4.4, 0.13, -3.85), Vector3(0.8, 0.16, 0.5))


func _sanctum_room(center: Vector3) -> void:
	_altar(center + Vector3(-4.15, 0, 3.55), true)
	_banner(center + Vector3(-4.65, 0, -7.48), "cloth_purple")
	_banner(center + Vector3(3.2, 0, -7.48), "cloth_blue")
	_pillar_brazier(center + Vector3(4.95, 0.0, 4.65), true)
	_pillar_brazier(center + Vector3(-0.4, 0.0, 4.65), true)
	_treasure_pile(center + Vector3(4.9, 0, -4.1))
	_treasure_pile(center + Vector3(0.3, 0, -4.0))
	_urn_cluster(center + Vector3(5.0, 0, 3.2))
	_orb("violet", center + Vector3(4.75, 0.70, -4.35), Vector3(0.48, 0.81, 0.48))
	_cylinder("stone3", center + Vector3(4.75, 0.23, -4.35), 0.48, 0.43)


func _accent_existing_pillars_and_chests() -> void:
	super._accent_existing_pillars_and_chests()
	for node in generator.get_children():
		if not (node is Node3D):
			continue
		var block: Node3D = node as Node3D
		if String(block.name).begins_with("Column") and not String(block.name).begins_with("Column cap") and not String(block.name).begins_with("Column foot"):
			var p: Vector3 = block.position
			_box("stone4", Vector3(p.x, 2.78, p.z), Vector3(1.12, 0.09, 1.12))
			_orb("bronze", Vector3(p.x + 0.28, 2.86, p.z + 0.28), Vector3(0.08, 0.06, 0.08))
		elif String(block.name).begins_with("Loot chest body"):
			var base: Vector3 = block.position - Vector3(0, 0.42, 0)
			_treasure_pile(base + Vector3(0.0, 0.02, -0.8))


func _corner_rubble(at: Vector3, pieces: int) -> void:
	for i in range(pieces):
		var p: Vector3 = at + Vector3(randomizer.randf_range(-0.7, 0.7), 0.12,
			randomizer.randf_range(-0.7, 0.7))
		if randomizer.randf() < 0.55:
			_orb("stone2", p, Vector3(randomizer.randf_range(0.14, 0.32),
				randomizer.randf_range(0.09, 0.18), randomizer.randf_range(0.12, 0.28)))
		else:
			_box("stone3", p, Vector3(randomizer.randf_range(0.12, 0.35),
				randomizer.randf_range(0.08, 0.16), randomizer.randf_range(0.12, 0.28)),
				randomizer.randf_range(-1.2, 1.2))


func _urn(at: Vector3, fancy: bool = false) -> void:
	_cylinder("stone4" if not fancy else "bronze", at + Vector3(0, 0.42, 0), 0.32, 0.66)
	_cylinder("stone3" if not fancy else "gold", at + Vector3(0, 0.78, 0), 0.22, 0.16)
	_orb("stone4" if not fancy else "gold", at + Vector3(0, 0.97, 0), Vector3(0.16, 0.12, 0.16))
	_cylinder("dark", at + Vector3(0, 0.08, 0), 0.20, 0.12)


func _urn_cluster(at: Vector3) -> void:
	_urn(at, true)
	_urn(at + Vector3(0.62, 0, 0.18), false)
	_urn(at + Vector3(0.18, 0, 0.65), false)
	_add_blocking_prop(at + Vector3(0.31, 0.48, 0.30), Vector3(1.05, 1.0, 1.05))


func _treasure_pile(at: Vector3) -> void:
	_box("wood2", at + Vector3(0, 0.04, 0), Vector3(1.0, 0.08, 0.7))
	for i in range(18 if detail_quality > 0 else 10):
		var dx: float = randomizer.randf_range(-0.42, 0.42)
		var dz: float = randomizer.randf_range(-0.24, 0.24)
		_orb("gold", at + Vector3(dx, 0.12 + randomizer.randf_range(0.0, 0.20), dz),
			Vector3(0.09, 0.03, 0.09))
	_orb("aqua", at + Vector3(-0.14, 0.29, 0.08), Vector3(0.14, 0.10, 0.11))
	_orb("violet", at + Vector3(0.16, 0.27, -0.02), Vector3(0.12, 0.10, 0.12))


func _war_table(at: Vector3) -> void:
	_box("wood2", at + Vector3(0, 0.86, 0), Vector3(2.55, 0.16, 1.45))
	for x in [-1.05, 1.05]:
		for z in [-0.52, 0.52]:
			_box("wood", at + Vector3(x, 0.43, z), Vector3(0.14, 0.86, 0.14))
	_box("parchment", at + Vector3(0, 0.95, 0), Vector3(1.55, 0.03, 0.90))
	_box("cloth_blue", at + Vector3(0.45, 0.98, 0.10), Vector3(0.45, 0.03, 0.26), -0.25)
	_orb("gold", at + Vector3(-0.35, 1.04, -0.20), Vector3(0.16, 0.05, 0.16))
	_add_blocking_prop(at + Vector3(0, 0.45, 0), Vector3(2.55, 0.92, 1.45))


func _weapon_stand(at: Vector3) -> void:
	_cylinder("wood2", at + Vector3(0, 0.44, 0), 0.44, 0.88)
	_box("iron", at + Vector3(0, 0.97, 0), Vector3(0.08, 1.0, 0.08))
	_box("iron2", at + Vector3(0, 1.32, 0), Vector3(0.58, 0.07, 0.12))
	_box("iron2", at + Vector3(0, 1.06, 0), Vector3(0.12, 0.07, 0.58))
	_box("iron", at + Vector3(0.0, 1.65, 0), Vector3(0.12, 0.54, 0.12))
	_box("bronze", at + Vector3(0, 1.92, 0), Vector3(0.24, 0.06, 0.24))
	_add_blocking_prop(at + Vector3(0, 0.45, 0), Vector3(1.0, 0.9, 1.0))


func _shield_rack(at: Vector3, along_x: bool = true) -> void:
	if along_x:
		_box("wood2", at + Vector3(0, 1.2, 0), Vector3(0.20, 2.2, 1.8))
		for z in [-0.55, 0.0, 0.55]:
			_orb("cloth_red", at + Vector3(0.14, 1.35, z), Vector3(0.52, 0.58, 0.11))
			_box("iron", at + Vector3(0.23, 1.35, z), Vector3(0.05, 0.10, 0.13))
	else:
		_box("wood2", at + Vector3(0, 1.2, 0), Vector3(1.8, 2.2, 0.20))
		for x in [-0.55, 0.0, 0.55]:
			_orb("cloth_red", at + Vector3(x, 1.35, 0.14), Vector3(0.11, 0.58, 0.52))
			_box("iron", at + Vector3(x, 1.35, 0.23), Vector3(0.13, 0.10, 0.05))
	_add_blocking_prop(at + Vector3(0, 1.1, 0), Vector3(0.9 if along_x else 1.8, 2.2, 1.8 if along_x else 0.9))


func _reading_table(at: Vector3) -> void:
	_box("wood2", at + Vector3(0, 0.82, 0), Vector3(2.05, 0.14, 1.20))
	for x in [-0.82, 0.82]:
		for z in [-0.40, 0.40]:
			_box("wood", at + Vector3(x, 0.41, z), Vector3(0.12, 0.82, 0.12))
	_box("parchment", at + Vector3(-0.25, 0.92, 0.0), Vector3(0.52, 0.03, 0.38), 0.25)
	_box("cloth_blue", at + Vector3(0.30, 0.92, -0.10), Vector3(0.30, 0.14, 0.18))
	_orb("gold", at + Vector3(0.62, 1.00, 0.22), Vector3(0.10, 0.16, 0.10))
	_add_blocking_prop(at + Vector3(0, 0.42, 0), Vector3(2.05, 0.9, 1.2))


func _scroll_pile(at: Vector3) -> void:
	for i in range(5):
		_box("parchment", at + Vector3(randomizer.randf_range(-0.18, 0.18),
			0.14 + float(i) * 0.03, randomizer.randf_range(-0.14, 0.14)),
			Vector3(0.26, 0.05, 0.12), randomizer.randf_range(-0.8, 0.8))
	_box("cloth_red", at + Vector3(0.10, 0.18, 0.0), Vector3(0.04, 0.08, 0.16))


func _forge_hearth(at: Vector3) -> void:
	_box("stone0", at + Vector3(0, 0.55, 0), Vector3(1.65, 1.10, 1.25))
	_box("stone4", at + Vector3(0, 1.12, 0), Vector3(1.35, 0.12, 1.0))
	_orb("ember", at + Vector3(0, 0.90, 0), Vector3(0.58, 0.22, 0.48))
	_orb("ember", at + Vector3(0.18, 0.96, 0.10), Vector3(0.26, 0.16, 0.21))
	_add_blocking_prop(at + Vector3(0, 0.55, 0), Vector3(1.65, 1.10, 1.25))
	if detail_quality > 0:
		var light: OmniLight3D = OmniLight3D.new()
		light.position = at + Vector3(0, 1.20, 0.15)
		light.light_color = Color("#ff9c52")
		light.light_energy = 1.1
		light.omni_range = 5.7
		add_child(light)
		torch_lights.append(light)


func _tool_bench(at: Vector3) -> void:
	_bench(at)
	_box("iron2", at + Vector3(0.55, 0.78, 0.0), Vector3(0.34, 0.06, 0.10), 0.3)
	_box("iron", at + Vector3(-0.35, 0.78, 0.05), Vector3(0.55, 0.06, 0.08), -0.4)
	_box("wood3", at + Vector3(0.0, 0.79, -0.18), Vector3(0.18, 0.08, 0.18))


func _coal_pile(at: Vector3) -> void:
	for i in range(12):
		_orb("dark", at + Vector3(randomizer.randf_range(-0.45, 0.45),
			0.10 + randomizer.randf_range(0.0, 0.08), randomizer.randf_range(-0.38, 0.38)),
			Vector3(randomizer.randf_range(0.12, 0.24), 0.08, randomizer.randf_range(0.10, 0.22)))


func _broken_column(at: Vector3) -> void:
	_cylinder("stone3", at + Vector3(0, 0.36, 0), 0.52, 0.72)
	_cylinder("stone4", at + Vector3(0, 0.76, 0), 0.62, 0.11)
	_box("stone0", at + Vector3(0.55, 0.25, 0.18), Vector3(0.82, 0.24, 0.36), 0.35)
	_box("stone0", at + Vector3(-0.42, 0.15, -0.24), Vector3(0.56, 0.20, 0.30), -0.45)
	_add_blocking_prop(at + Vector3(0, 0.36, 0), Vector3(1.25, 0.72, 1.1))


func _pillar_brazier(at: Vector3, magic: bool = false) -> void:
	_cylinder("stone4", at + Vector3(0, 0.35, 0), 0.62, 0.70)
	_cylinder("bronze", at + Vector3(0, 0.86, 0), 0.45, 0.16)
	_orb("violet" if magic else "ember", at + Vector3(0, 1.15, 0), Vector3(0.36, 0.42, 0.36))
	if detail_quality > 0 or extra_magic_lights:
		var light: OmniLight3D = OmniLight3D.new()
		light.position = at + Vector3(0, 1.25, 0)
		light.light_color = Color("#8f82ff") if magic else Color("#ffb066")
		light.light_energy = 0.95 if magic else 0.85
		light.omni_range = 5.2
		add_child(light)
		torch_lights.append(light)
	_add_blocking_prop(at + Vector3(0, 0.36, 0), Vector3(1.25, 0.72, 1.25))


func _wall_shelf(at: Vector3, along_z: bool) -> void:
	if along_z:
		_box("wood2", at + Vector3(0, 1.15, 0), Vector3(0.18, 0.09, 1.15))
		_box("parchment", at + Vector3(0.05, 1.26, 0.25), Vector3(0.24, 0.05, 0.16), 0.3)
		_orb("gold", at + Vector3(0.04, 1.28, -0.28), Vector3(0.10, 0.12, 0.10))
	else:
		_box("wood2", at + Vector3(0, 1.15, 0), Vector3(1.15, 0.09, 0.18))
		_box("parchment", at + Vector3(0.25, 1.26, 0.05), Vector3(0.24, 0.05, 0.16), -0.2)
		_orb("gold", at + Vector3(-0.28, 1.28, 0.04), Vector3(0.10, 0.12, 0.10))


func _corridor_torch_pair(middle: Vector3, direction: Vector2i) -> void:
	if direction.x != 0:
		_add_wall_sconce(middle + Vector3(-1.0, 0.0, -3.98), false)
		if detail_quality > 1:
			_add_wall_sconce(middle + Vector3(1.0, 0.0, 3.98), false)
	else:
		_add_wall_sconce(middle + Vector3(-3.98, 0.0, -1.0), false)
		if detail_quality > 1:
			_add_wall_sconce(middle + Vector3(3.98, 0.0, 1.0), false)
