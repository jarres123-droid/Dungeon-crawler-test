extends Node3D
## Reusable Greyhaven building assembler. All visible construction is derived from a
## compact dimensional standard; archetype scenes only select a definition.

@export_enum("small_cottage", "medium_residence", "merchant_shop", "workshop", "important_hall") var archetype := "small_cottage"

const WALL_THICKNESS := 0.24
const FOUNDATION_HEIGHT := 0.48
const ROOF_THICKNESS := 0.24
const TIMBER_DEPTH := 0.28
const TRIM_THICKNESS := 0.16
const DEFAULT_EAVE := 0.62
const SHINGLE_LIFT := 0.055

static var _materials: Dictionary = {}
static var _boxes: Dictionary = {}
static var _roof_meshes: Dictionary = {}

var _spec: Dictionary


func _ready() -> void:
	_prepare_resources()
	_spec = _definition(archetype)
	_build_shell()
	_build_roof()
	_build_openings()
	_build_character_details()
	_add_collision()
	_validate_geometry()


func _definition(kind: String) -> Dictionary:
	var definitions := {
		"small_cottage": {"width": 5.2, "depth": 4.4, "wall_height": 3.0, "pitch": 0.68, "eave": .66, "roof": "roof_moss", "windows": 1, "porch": false, "awning": false, "sign": false, "chimney_x": 1.35, "roof_courses": 6, "facade": "cottage"},
		"medium_residence": {"width": 6.7, "depth": 5.2, "wall_height": 3.65, "pitch": .60, "eave": .74, "roof": "roof_slate", "windows": 2, "porch": true, "awning": false, "sign": false, "chimney_x": 1.75, "roof_courses": 7, "facade": "residence"},
		"merchant_shop": {"width": 7.2, "depth": 5.4, "wall_height": 4.0, "pitch": .54, "eave": .86, "roof": "roof_warm", "windows": 2, "porch": true, "awning": true, "sign": true, "chimney_x": 2.15, "roof_courses": 7, "facade": "merchant"},
		"workshop": {"width": 7.4, "depth": 5.8, "wall_height": 3.45, "pitch": .49, "eave": .82, "roof": "roof_slate", "windows": 1, "porch": false, "awning": true, "sign": true, "chimney_x": 2.25, "roof_courses": 6, "facade": "workshop"},
		"important_hall": {"width": 8.8, "depth": 6.2, "wall_height": 4.45, "pitch": .69, "eave": .94, "roof": "roof_warm", "windows": 3, "porch": true, "awning": false, "sign": false, "chimney_x": 2.55, "roof_courses": 8, "facade": "hall"},
	}
	return definitions[kind]


func _prepare_resources() -> void:
	if not _materials.is_empty():
		return
	var paths := {
		"plaster": "plaster", "timber": "aged_timber", "timber_dark": "dark_structural_wood",
		"stone": "village_stone", "stone_edge": "worn_edges", "iron": "iron",
		"roof_slate": "roof", "roof_moss": "roof", "roof_warm": "roof", "glass": "bronze",
	}
	for key in paths:
		_materials[key] = load("res://assets/materials/%s.tres" % paths[key])
	# Controlled material variants retain shared textures but distinguish silhouettes.
	_materials["roof_moss"] = (_materials["roof_slate"] as Material).duplicate()
	_materials["roof_moss"].albedo_color = Color("#53675c")
	_materials["roof_warm"] = (_materials["roof_slate"] as Material).duplicate()
	_materials["roof_warm"].albedo_color = Color("#594b46")


func _box(parent: Node3D, label: String, at: Vector3, size: Vector3, material_key: String, rotation := Vector3.ZERO) -> MeshInstance3D:
	var cache_key := "%0.3f:%0.3f:%0.3f:%s" % [size.x, size.y, size.z, material_key]
	if not _boxes.has(cache_key):
		var mesh := BoxMesh.new()
		mesh.size = size
		mesh.material = _materials[material_key]
		_boxes[cache_key] = mesh
	var piece := MeshInstance3D.new()
	piece.name = label
	piece.mesh = _boxes[cache_key]
	piece.position = at
	piece.rotation = rotation
	parent.add_child(piece)
	return piece


func _build_shell() -> void:
	var w: float = _spec.width
	var d: float = _spec.depth
	var h: float = _spec.wall_height
	_box(self, "Inset plaster wall core", Vector3(0, FOUNDATION_HEIGHT + h * .5, 0), Vector3(w, h, d), "plaster")
	_box(self, "Projecting stone foundation", Vector3(0, FOUNDATION_HEIGHT * .5, 0), Vector3(w + .58, FOUNDATION_HEIGHT, d + .58), "stone")
	_box(self, "Foundation weather course", Vector3(0, FOUNDATION_HEIGHT + .10, 0), Vector3(w + .34, .20, d + .34), "stone_edge")
	# Continuous top plates and real corner posts visibly carry the roof load.
	for z in [-d * .5 - TIMBER_DEPTH * .45, d * .5 + TIMBER_DEPTH * .45]:
		_box(self, "Wall top plate", Vector3(0, FOUNDATION_HEIGHT + h - .16, z), Vector3(w + .34, .32, TIMBER_DEPTH), "timber_dark")
		_box(self, "Wall sill beam", Vector3(0, FOUNDATION_HEIGHT + .30, z), Vector3(w + .22, .25, TIMBER_DEPTH), "timber")
	for x in [-w * .5 - TIMBER_DEPTH * .35, w * .5 + TIMBER_DEPTH * .35]:
		for z in [-d * .5 - TIMBER_DEPTH * .35, d * .5 + TIMBER_DEPTH * .35]:
			_box(self, "Mortised corner post", Vector3(x, FOUNDATION_HEIGHT + h * .5, z), Vector3(TIMBER_DEPTH, h, TIMBER_DEPTH), "timber_dark")
		for y in [FOUNDATION_HEIGHT + h * .36, FOUNDATION_HEIGHT + h * .72]:
			_box(self, "Side wall rail", Vector3(x, y, 0), Vector3(TIMBER_DEPTH, .22, d), "timber")
	# Front framing bays and alternating braces create controlled asymmetry.
	for x in [-w * .27, 0.0, w * .27]:
		_box(self, "Facade stud", Vector3(x, FOUNDATION_HEIGHT + h * .52, d * .5 + .16), Vector3(.23, h * .86, .24), "timber")
	for x in [-w * .36, w * .36]:
		_box(self, "Diagonal timber brace", Vector3(x, FOUNDATION_HEIGHT + h * .63, d * .5 + .19), Vector3(.20, h * .48, .20), "timber", Vector3(0, 0, sign(x) * .43))
	# Layered corner plinths, beam pegs and a shadow line make the shared wall module
	# feel assembled rather than extruded, while remaining dimension-driven.
	for x in [-w * .5 - .22, w * .5 + .22]:
		for z in [-d * .5 - .22, d * .5 + .22]:
			_box(self, "Corner footing block", Vector3(x, .27, z), Vector3(.52, .54, .52), "stone_edge")
	for x in [-w * .27, 0.0, w * .27]:
		_box(self, "Square timber peg", Vector3(x, FOUNDATION_HEIGHT + h * .72, d * .5 + .305), Vector3(.075, .075, .07), "iron")
	_box(self, "Facade shadow course", Vector3(0, FOUNDATION_HEIGHT + .19, d * .5 + .185), Vector3(w - .34, .10, .12), "timber_dark")


func _build_roof() -> void:
	var w: float = _spec.width
	var d: float = _spec.depth
	var h: float = _spec.wall_height
	var pitch: float = _spec.pitch
	var run: float = w * .5 + _spec.eave
	var rise := run * tan(pitch)
	var wall_top := FOUNDATION_HEIGHT + h
	var roof_depth: float = d + _spec.eave * 2.0
	# Vertical-cut prisms share exactly one ridge face (x=0); unlike rotated boxes,
	# their finite thickness cannot cross into the opposite roof half.
	for side in [-1, 1]:
		var mesh := _roof_prism(run, rise, roof_depth, ROOF_THICKNESS, side, _spec.roof)
		var slope := MeshInstance3D.new()
		slope.name = "Mirrored roof slope" if side < 0 else "Roof slope"
		slope.mesh = mesh
		slope.position.y = wall_top
		add_child(slope)
	# A three-part ridge reads as laid caps rather than one extruded bar.
	_box(self, "Ridge shadow", Vector3(0, wall_top + rise + .08, 0), Vector3(.46, .18, roof_depth + .24), "timber_dark")
	_box(self, "Ridge cap", Vector3(0, wall_top + rise + .20, 0), Vector3(.34, .22, roof_depth + .34), _spec.roof)
	for z in [-roof_depth * .5 - .16, roof_depth * .5 + .16]:
		_box(self, "Ridge end cap", Vector3(0, wall_top + rise + .20, z), Vector3(.48, .30, .16), "timber")
	for x in [-run, run]:
		_box(self, "Eave fascia", Vector3(x, wall_top - .11, 0), Vector3(.26, .44, roof_depth + .16), "timber_dark")
		_box(self, "Eave drip trim", Vector3(x + sign(x) * .075, wall_top - .31, 0), Vector3(.15, .12, roof_depth + .22), "timber")
	for z in [-roof_depth * .5, roof_depth * .5]:
		for side in [-1, 1]:
			var center_x: float = side * run * .5
			var center_y: float = wall_top + rise * .5 - .13
			var length := sqrt(run * run + rise * rise)
			_box(self, "Gable bargeboard", Vector3(center_x, center_y, z), Vector3(length, .20, .22), "timber", Vector3(0, 0, -side * pitch))
	# Gable studs terminate under the calculated ridge rather than inside a slab.
	for z in [-d * .5 - .14, d * .5 + .14]:
		_box(self, "Gable king post", Vector3(0, wall_top + rise * .46, z), Vector3(.24, rise * .90, .24), "timber_dark")
		_box(self, "Gable collar tie", Vector3(0, wall_top + rise * .30, z + sign(z) * .02), Vector3(w * .48, .18, .25), "timber")
	# Exposed rafter tails establish believable support beneath the deep eaves.
	for z_index in range(7):
		var rafter_z := -d * .5 + d * float(z_index) / 6.0
		for side in [-1, 1]:
			_box(self, "Exposed rafter tail", Vector3(side * (w * .5 + _spec.eave * .52), wall_top - .20, rafter_z), Vector3(_spec.eave * 1.25, .16, .15), "timber_dark", Vector3(0, 0, -side * pitch))
	# Narrow staggered shingle ribbons catch light without crossing the roof shell.
	for side in [-1, 1]:
		for course in range(1, int(_spec.roof_courses) + 1):
			var fraction := float(course) / float(_spec.roof_courses + 1)
			var x: float = side * run * fraction
			var y: float = wall_top + rise * (1.0 - fraction) + SHINGLE_LIFT
			_box(self, "Raised shingle course", Vector3(x, y, 0), Vector3(.12, .075, roof_depth - .16), _spec.roof, Vector3(0, 0, -side * pitch))
			for seam in range(-3, 4):
				var stagger := .34 if course % 2 == 0 else 0.0
				var seam_z := float(seam) * roof_depth / 7.0 + stagger
				if abs(seam_z) < roof_depth * .46:
					_box(self, "Shingle joint", Vector3(x + side * .015, y + .025, seam_z), Vector3(.15, .045, .055), "timber_dark", Vector3(0, 0, -side * pitch))


func _roof_prism(run: float, rise: float, depth: float, thickness: float, side: int, material_key: String) -> ArrayMesh:
	var key := "%0.2f:%0.2f:%0.2f:%d:%s" % [run, rise, depth, side, material_key]
	if _roof_meshes.has(key):
		return _roof_meshes[key]
	var ridge_x := 0.0
	var eave_x: float = side * run
	var z := depth * .5
	var vertices := PackedVector3Array([
		Vector3(ridge_x, rise, -z), Vector3(eave_x, 0, -z), Vector3(eave_x, -thickness, -z), Vector3(ridge_x, rise - thickness, -z),
		Vector3(ridge_x, rise, z), Vector3(eave_x, 0, z), Vector3(eave_x, -thickness, z), Vector3(ridge_x, rise - thickness, z),
	])
	var indices := PackedInt32Array([0,1,5, 0,5,4, 3,7,6, 3,6,2, 0,4,7, 0,7,3, 1,2,6, 1,6,5, 0,3,2, 0,2,1, 4,5,6, 4,6,7])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, _materials[material_key])
	_roof_meshes[key] = mesh
	return mesh


func _build_openings() -> void:
	var w: float = _spec.width
	var d: float = _spec.depth
	var front := d * .5 + .19
	# Recessed door leaf, projecting jambs/lintel, threshold and iron hardware.
	_box(self, "Recessed plank door", Vector3(0, 1.52, front), Vector3(1.30, 2.45, .16), "timber_dark")
	for x in [-.77, .77]:
		_box(self, "Door jamb", Vector3(x, 1.58, front + .09), Vector3(.18, 2.66, .20), "timber")
	_box(self, "Door lintel", Vector3(0, 2.91, front + .09), Vector3(1.72, .22, .20), "timber")
	_box(self, "Door hood", Vector3(0, 3.08, front + .29), Vector3(1.98, .16, .55), _spec.roof, Vector3(-.16, 0, 0))
	_box(self, "Stone doorstep", Vector3(0, .18, front + .38), Vector3(1.72, .25, .72), "stone_edge")
	_box(self, "Door strap hinge", Vector3(.32, 1.48, front + .18), Vector3(.50, .09, .08), "iron")
	_box(self, "Door lower strap", Vector3(.32, .78, front + .18), Vector3(.50, .09, .08), "iron")
	_box(self, "Door handle", Vector3(-.38, 1.48, front + .23), Vector3(.09, .22, .09), "iron")
	var count: int = _spec.windows
	for index in count:
		var side := -1.0 if index % 2 == 0 else 1.0
		var x: float = side * (w * (.29 if count < 3 else (.22 + index * .08)))
		_window(Vector3(x, 1.80 + (index % 2) * .10, front + .03), index != 1)


func _window(at: Vector3, shutters: bool) -> void:
	_box(self, "Window frame", at, Vector3(1.22, 1.34, .17), "timber_dark")
	_box(self, "Lead glass", at + Vector3(0, 0, .11), Vector3(.88, .96, .08), "glass")
	_box(self, "Window mullion", at + Vector3(0, 0, .18), Vector3(.09, 1.02, .07), "timber")
	_box(self, "Window transom", at + Vector3(0, 0, .18), Vector3(.94, .09, .07), "timber")
	_box(self, "Window header", at + Vector3(0, .74, .08), Vector3(1.48, .18, .28), "timber")
	_box(self, "Projecting sill", at + Vector3(0, -.76, .12), Vector3(1.42, .18, .34), "stone_edge")
	if shutters:
		for side in [-1, 1]:
			_box(self, "Open shutter", at + Vector3(side * .87, 0, .06), Vector3(.42, 1.25, .13), "timber", Vector3(0, side * .18, 0))


func _build_character_details() -> void:
	var w: float = _spec.width
	var d: float = _spec.depth
	var h: float = _spec.wall_height
	var front := d * .5
	if _spec.porch:
		_box(self, "Porch deck", Vector3(0, .35, front + .88), Vector3(w * .56, .25, 1.55), "timber")
		for x in [-w * .23, w * .23]:
			_box(self, "Porch post", Vector3(x, 1.55, front + 1.35), Vector3(.24, 2.50, .24), "timber_dark")
			_box(self, "Carved support bracket", Vector3(x - sign(x) * .22, 2.64, front + 1.31), Vector3(.55, .18, .20), "timber", Vector3(0, 0, sign(x) * .42))
		_box(self, "Porch beam", Vector3(0, 2.82, front + 1.34), Vector3(w * .58, .26, .28), "timber_dark")
		for x in [-w * .18, 0.0, w * .18]:
			_box(self, "Porch deck board seam", Vector3(x, .485, front + .88), Vector3(.055, .025, 1.48), "timber_dark")
	if _spec.awning:
		_box(self, "Shop awning", Vector3(0, 2.72, front + .82), Vector3(w * .58, .20, 1.55), "roof_warm", Vector3(-.16, 0, 0))
		for x in [-w * .25, w * .25]:
			_box(self, "Awning bracket", Vector3(x, 2.23, front + .48), Vector3(.18, .18, 1.0), "timber", Vector3(-.48, 0, 0))
	if _spec.sign:
		_box(self, "Sign bracket", Vector3(-w * .34, 3.10, front + .60), Vector3(1.12, .13, .13), "iron")
		_box(self, "Hanging trade sign", Vector3(-w * .20, 2.58, front + .60), Vector3(.92, .78, .14), "timber")
	_build_archetype_accent(front)
	# Chimney starts below the roof but exits only one selected plane, clear of ridge.
	var run: float = w * .5 + _spec.eave
	var rise: float = run * tan(_spec.pitch)
	var cx: float = _spec.chimney_x
	var roof_y: float = FOUNDATION_HEIGHT + h + rise * (1.0 - abs(cx) / run)
	_box(self, "Stone chimney", Vector3(cx, roof_y + .62, -.55), Vector3(.76, 1.65, .78), "stone")
	_box(self, "Chimney cap", Vector3(cx, roof_y + 1.48, -.55), Vector3(.98, .18, 1.0), "stone_edge")
	_box(self, "Chimney crown", Vector3(cx, roof_y + 1.62, -.55), Vector3(.72, .12, .74), "stone")


func _build_archetype_accent(front: float) -> void:
	var w: float = _spec.width
	var h: float = _spec.wall_height
	match String(_spec.facade):
		"cottage":
			_box(self, "Cottage herb shelf", Vector3(-w * .27, 1.02, front + .34), Vector3(1.28, .13, .48), "timber")
			for x in [-w * .35, -w * .19]:
				_box(self, "Cottage shelf bracket", Vector3(x, .83, front + .19), Vector3(.12, .44, .12), "timber_dark", Vector3(0, 0, sign(x) * .22))
		"residence":
			_box(self, "Residence porch crown", Vector3(0, 3.02, front + 1.34), Vector3(w * .34, .17, .34), "timber")
			for x in [-w * .15, w * .15]:
				_box(self, "Residence balustrade", Vector3(x, .92, front + 1.40), Vector3(.13, .82, .13), "timber")
		"merchant":
			_box(self, "Merchant display counter", Vector3(w * .25, 1.02, front + .42), Vector3(w * .28, .18, .68), "timber")
			_box(self, "Merchant fascia", Vector3(0, 3.00, front + 1.40), Vector3(w * .61, .34, .18), "timber_dark")
		"workshop":
			_box(self, "Workshop loading platform", Vector3(w * .22, .30, front + .82), Vector3(w * .39, .38, 1.42), "stone")
			_box(self, "Workshop reinforced lintel", Vector3(0, h - .18, front + .24), Vector3(w * .56, .34, .34), "timber_dark")
		"hall":
			_box(self, "Hall jetty beam", Vector3(0, h * .73, front + .27), Vector3(w * .82, .34, .38), "timber_dark")
			for x in [-w * .34, -w * .17, w * .17, w * .34]:
				_box(self, "Hall carved corbel", Vector3(x, h * .68, front + .38), Vector3(.24, .72, .26), "timber", Vector3(0, 0, sign(x) * .34))


func _add_collision() -> void:
	var body := StaticBody3D.new()
	body.name = "Building collision"
	var shape := BoxShape3D.new()
	shape.size = Vector3(_spec.width, _spec.wall_height, _spec.depth)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = FOUNDATION_HEIGHT + _spec.wall_height * .5
	body.add_child(collision)
	add_child(body)


func _validate_geometry() -> void:
	var run: float = _spec.width * .5 + _spec.eave
	var rise: float = run * tan(_spec.pitch)
	assert(run > _spec.width * .5, "Roof eave must project beyond the wall")
	assert(rise > 0.0, "Roof ridge must be above the wall plate")
	assert(_spec.chimney_x < run - .45, "Chimney must remain inside the roof edge")
	set_meta("roof_run", run)
	set_meta("roof_rise", rise)
	set_meta("ridge_height", FOUNDATION_HEIGHT + _spec.wall_height + rise)
	set_meta("geometry_validated", true)
