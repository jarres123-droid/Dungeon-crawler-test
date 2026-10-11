extends Node3D

## Runtime builder shared by the authored asset scenes in this kit.  The scenes are
## deliberately composed from a small mesh palette so repeated props share GPU
## resources, while layered profiles, braces and hardware avoid primitive silhouettes.
@export_enum("house_small", "house_medium", "house_workshop", "roof_module", "chimney", "door", "window", "shutters", "beam", "foundation", "barrel", "crate_stack", "sacks", "cart", "wagon_wheel", "bench", "fence", "sign", "lantern", "woodpile", "market_stall", "table", "smithy_props", "well", "planter", "greyhaven_entrance", "column", "column_damaged", "arch", "corridor_support", "wall_trim", "wall_buttress", "brazier", "torch", "dungeon_door", "iron_gate", "dungeon_table", "rubble", "chains", "floor_decal") var asset_kind: String = "barrel"

static var materials: Dictionary = {}

func _ready() -> void:
	if materials.is_empty():
		_make_materials()
	build()

func _make_materials() -> void:
	var shared := {
		"timber": "aged_timber", "dark_wood": "dark_structural_wood", "plaster": "plaster",
		"stone": "village_stone", "stone_light": "worn_edges", "dungeon": "dungeon_stone",
		"iron": "iron", "bronze": "bronze", "roof": "roof", "dirt": "dirt", "leaf": "grass"
	}
	for key in shared:
		materials[key] = load("res://assets/materials/%s.tres" % shared[key])
	var palette := {
		"timber": ["#765238", 0.88], "dark_wood": ["#352720", 0.92],
		"wood": ["#9a7048", 0.86], "plaster": ["#c9bea2", 0.96],
		"stone": ["#747b76", 0.95], "stone_light": ["#9ba098", 0.94],
		"dungeon": ["#4a555c", 0.97], "iron": ["#252c30", 0.72],
		"bronze": ["#a8783f", 0.68], "roof": ["#344c52", 0.91],
		"red": ["#8f4038", 0.91], "canvas": ["#c69c5d", 0.95],
		"leaf": ["#526f48", 0.98], "dirt": ["#665143", 1.0],
		"ember": ["#ff8b35", 0.45], "black": ["#11171b", 1.0]
	}
	for key in palette:
		if materials.has(key):
			continue
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(palette[key][0])
		m.roughness = palette[key][1]
		if key == "ember":
			m.emission_enabled = true; m.emission = Color("#ff6a22"); m.emission_energy_multiplier = 2.4
		materials[key] = m

func build() -> void:
	match asset_kind:
		"house_small", "house_medium", "house_workshop": _house()
		"roof_module": _box(Vector3.ZERO, Vector3(4.2, .32, 5.5), "roof", Vector3(0, 0, .48))
		"chimney": _chimney()
		"door": _door()
		"window": _window(false)
		"shutters": _window(true)
		"beam": _box(Vector3(0, 1.5, 0), Vector3(.3, 3.0, .3), "timber")
		"foundation": _box(Vector3.ZERO, Vector3(3.0, .5, 1.0), "stone")
		"barrel": _barrel()
		"crate_stack": _crates()
		"sacks": _sacks()
		"cart": _cart()
		"wagon_wheel": _wheel(Vector3.ZERO)
		"bench": _bench()
		"fence": _fence()
		"sign": _sign()
		"lantern": _lantern(Vector3.ZERO)
		"woodpile": _woodpile()
		"market_stall": _market()
		"table": _dungeon_table()
		"smithy_props": _smithy()
		"well": _well()
		"planter": _planter()
		"greyhaven_entrance": _entrance()
		"column": _column(false)
		"column_damaged": _column(true)
		"arch": _arch()
		"corridor_support": _support()
		"wall_trim": _box(Vector3(0, .2, 0), Vector3(4.0, .4, .35), "stone_light")
		"wall_buttress": _buttress()
		"brazier": _brazier()
		"torch": _torch()
		"dungeon_door": _door()
		"iron_gate": _gate()
		"dungeon_table": _dungeon_table()
		"rubble": _rubble()
		"chains": _chains()
		"floor_decal": _floor_detail()

func _box(at: Vector3, size: Vector3, mat: String, tilt := Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new(); mesh.size = size; mesh.material = materials[mat]
	var node := MeshInstance3D.new(); node.mesh = mesh; node.position = at; node.rotation = tilt; add_child(node); return node

func _cyl(at: Vector3, radius: float, height: float, mat: String, sides := 10, rotation := Vector3.ZERO) -> MeshInstance3D:
	var mesh := CylinderMesh.new(); mesh.top_radius = radius * 0.92; mesh.bottom_radius = radius; mesh.height = height; mesh.radial_segments = sides; mesh.material = materials[mat]
	var node := MeshInstance3D.new(); node.mesh = mesh; node.position = at; node.rotation = rotation; add_child(node); return node

func _house() -> void:
	var medium := asset_kind != "house_small"; var w := 6.8 if medium else 5.5; var h := 3.5 if medium else 3.0; var d := 5.2 if medium else 4.3
	_box(Vector3(0,h*.5,0), Vector3(w,h,d), "plaster")
	# A stepped masonry plinth, continuous sill, and wrapped corner posts make the
	# shell read as a supported timber building rather than a decorated box.
	_box(Vector3(0,.16,0), Vector3(w+.62,.32,d+.62), "stone")
	_box(Vector3(0,.43,0), Vector3(w+.35,.24,d+.35), "stone_light")
	_box(Vector3(0,.67,d*.515), Vector3(w+.18,.25,.28), "dark_wood")
	for x in [-w*.46, 0.0, w*.46]: _box(Vector3(x,h*.52,d*.515), Vector3(.30,h*.98,.28), "timber")
	for x in [-w*.46,w*.46]:
		_box(Vector3(x,h*.52,-d*.515), Vector3(.30,h*.98,.28), "dark_wood")
		# Side-wall rails connect the corner posts without turning the entire side
		# elevation into a solid timber slab.
		for y in [.67, h*.9]:
			_box(Vector3(x,y,0), Vector3(.32,.25,d+.18), "timber")
	for x in [-w*.23,w*.23]: _box(Vector3(x,h*.58,d*.54), Vector3(.22,h*.72,.22), "dark_wood", Vector3(0,0,x*.18))
	_box(Vector3(0,h*.9,d*.52), Vector3(w+.28,.30,.32), "dark_wood")
	_box(Vector3(0,h*.9,-d*.52), Vector3(w+.28,.30,.32), "dark_wood")
	# Deep roof planes include a shadowed under-roof, clean fascia, exposed rafter
	# tails and a raised ridge.  The few extra shared boxes remain mobile-friendly.
	for angle in [-.48,.48]:
		var x_sign: float = signf(angle)
		_box(Vector3(-angle*1.08,h+1.00,0), Vector3(w*.69,.48,d+1.18), "dark_wood", Vector3(0,0,angle))
		_box(Vector3(-angle*1.10,h+1.10,0), Vector3(w*.68,.30,d+1.12), "roof", Vector3(0,0,angle))
		_box(Vector3(-angle*2.13,h+.15,0), Vector3(.25,.50,d+1.28), "dark_wood", Vector3(0,0,angle))
		for z in [-d*.44, 0.0, d*.44]:
			_box(Vector3(-angle*2.02,h+.04,z), Vector3(.34,.25,.38), "timber", Vector3(0,0,angle))
		# Slim raised courses catch sunlight and suggest overlapping slate rows.
		for course in range(1, 4):
			var rise := float(course) * .46
			_box(Vector3(-x_sign*(1.72-rise*.88), h+.37+rise*.48, 0), Vector3(.12,.12,d+1.15), "roof", Vector3(0,0,angle))
	_box(Vector3(0,h+2.04,0), Vector3(.40,.34,d+1.30), "dark_wood")
	_box(Vector3(0,h+2.22,0), Vector3(.25,.18,d+1.38), "roof")
	# Framed, recessed opening with a lintel and stone threshold.
	_box(Vector3(0,1.25,d*.525), Vector3(1.32,2.35,.22), "dark_wood")
	for x in [-.78,.78]: _box(Vector3(x,1.35,d*.59), Vector3(.18,2.62,.20), "timber")
	_box(Vector3(0,2.67,d*.59), Vector3(1.75,.22,.22), "timber")
	_box(Vector3(0,.19,d*.66), Vector3(1.72,.22,.62), "stone_light")
	for x in [-w*.3,w*.3]:
		_box(Vector3(x,1.65,d*.55), Vector3(1.15,1.18,.18), "dark_wood"); _box(Vector3(x,1.65,d*.575), Vector3(.78,.82,.12), "bronze")
		_box(Vector3(x,1.65,d*.59), Vector3(.09,.9,.08), "timber"); _box(Vector3(x,1.65,d*.59), Vector3(.86,.09,.08), "timber")
		_box(Vector3(x,2.39,d*.58), Vector3(1.42,.16,.18), "timber")
	_box(Vector3(w*.28,h+1.22,-.6), Vector3(.78,2.0,.78), "stone"); _box(Vector3(w*.28,h+2.22,-.6), Vector3(1.0,.2,1.0), "stone_light")
	if asset_kind == "house_workshop": _box(Vector3(-w*.25,2.5,d*.68), Vector3(2.2,.18,1.25), "red", Vector3(.18,0,0))

func _chimney() -> void:
	_box(Vector3(0, 1.0, 0), Vector3(.85, 2.0, .85), "stone")
	_box(Vector3(0, 2.05, 0), Vector3(1.08, .2, 1.08), "stone_light")

func _window(with_shutters: bool) -> void:
	_box(Vector3.ZERO, Vector3(1.35, 1.35, .18), "dark_wood")
	_box(Vector3(0, 0, .12), Vector3(.92, .92, .08), "bronze")
	_box(Vector3(0, 0, .18), Vector3(.09, 1.0, .07), "timber")
	_box(Vector3(0, 0, .18), Vector3(1.0, .09, .07), "timber")
	if with_shutters:
		for x in [-.92, .92]: _box(Vector3(x, 0, .05), Vector3(.48, 1.28, .12), "wood", Vector3(0, .12 * sign(x), 0))

func _sacks() -> void:
	for data in [[Vector3(-.38,.38,0),.42,.72],[Vector3(.35,.32,.08),.38,.62],[Vector3(0,.82,0),.34,.55]]:
		_cyl(data[0], data[1], data[2], "canvas", 8, Vector3(0,0,.08))

func _barrel() -> void:
	_cyl(Vector3(0,.58,0),.5,1.16,"wood",12)
	for y in [.14,.56,.98]: _cyl(Vector3(0,y,0),.525,.075,"iron",12)
	for a in range(0,360,45): _box(Vector3(sin(deg_to_rad(a))*.48,.58,cos(deg_to_rad(a))*.48),Vector3(.055,1.02,.055),"dark_wood",Vector3(0,deg_to_rad(a),0))

func _crates() -> void:
	for data in [[Vector3(-.55,.5,0),Vector3(1,1,1),0.0],[Vector3(.55,.4,.12),Vector3(.82,.8,.82),.12],[Vector3(-.18,1.36,.04),Vector3(.9,.74,.9),-.08]]:
		_box(data[0],data[1],"wood",Vector3(0,data[2],0)); _box(data[0]+Vector3(0,0,data[1].z*.52),Vector3(data[1].x*.92,.12,.08),"dark_wood",Vector3(0,0,.7))

func _wheel(at: Vector3, rot := Vector3(PI*.5,0,0)) -> void:
	_cyl(at,.66,.16,"dark_wood",12,rot); _cyl(at,.42,.18,"black",12,rot)
	for a in range(0,360,45): _box(at+Vector3(cos(deg_to_rad(a))*.32,sin(deg_to_rad(a))*.32,0),Vector3(.65,.08,.12),"wood",Vector3(0,0,deg_to_rad(a)))

func _cart() -> void:
	_box(Vector3(0,.9,0),Vector3(2.55,.3,1.5),"wood"); _box(Vector3(0,1.25,-.65),Vector3(2.7,.8,.15),"timber")
	_wheel(Vector3(-1.05,.62,.8)); _wheel(Vector3(1.05,.62,.8))
	for x in [-.42,.42]: _box(Vector3(x,.48,-1.7),Vector3(.15,.15,2.5),"dark_wood",Vector3(-.04,0,0))

func _bench() -> void:
	_box(Vector3(0,.72,0),Vector3(2.65,.22,.7),"wood"); _box(Vector3(0,1.28,.3),Vector3(2.65,.72,.16),"wood",Vector3(-.1,0,0))
	for x in [-.92,.92]: _box(Vector3(x,.37,0),Vector3(.2,.72,.55),"dark_wood",Vector3(0,0,x*.04))

func _fence() -> void:
	for x in [-1.5,1.5]: _box(Vector3(x,.75,0),Vector3(.25,1.5,.25),"dark_wood",Vector3(0,0,x*.025)); _box(Vector3(x,1.55,0),Vector3(.34,.28,.34),"wood",Vector3(0,.78,0))
	for y in [.58,1.12]: _box(Vector3(0,y,0),Vector3(3.05,.17,.17),"timber",Vector3(0,0,.035 if y<1 else -.025))

func _sign() -> void:
	_box(Vector3(0,1.35,0),Vector3(.22,2.7,.22),"dark_wood"); _box(Vector3(.62,2.35,0),Vector3(1.25,.15,.15),"iron"); _box(Vector3(1.04,1.82,0),Vector3(1.25,.75,.14),"wood",Vector3(0,0,.04)); _cyl(Vector3(.5,2.22,0),.07,.25,"iron",8,Vector3(PI*.5,0,0))

func _lantern(at: Vector3) -> void:
	_box(at+Vector3(0,.28,0),Vector3(.42,.56,.42),"bronze"); _box(at+Vector3(0,.3,0),Vector3(.28,.4,.28),"ember"); _cyl(at+Vector3(0,.63,0),.22,.1,"iron",8)

func _woodpile() -> void:
	for row in range(3):
		for col in range(4-row): _cyl(Vector3((col-(3-row)*.5)*.42,.2+row*.36,0),.18,1.15,"wood",7,Vector3(PI*.5,0,0))

func _market() -> void:
	for x in [-1.35,1.35]: _box(Vector3(x,1.5,0),Vector3(.2,3,.2),"dark_wood")
	_box(Vector3(0,1,0),Vector3(3,.26,1.5),"wood")
	for i in range(5): _box(Vector3(-1.2+i*.6,3.0,0),Vector3(.61,.16,2.15),"red" if i%2==0 else "canvas",Vector3(0,0,(-.08+i*.04)))

func _smithy() -> void:
	_box(Vector3(0,.65,0),Vector3(1.25,.5,.62),"iron"); _box(Vector3(.42,.95,0),Vector3(.6,.22,.75),"iron"); _box(Vector3(-.8,.45,0),Vector3(.25,.9,.25),"dark_wood"); _box(Vector3(-.8,.95,0),Vector3(.75,.18,.18),"iron")

func _well() -> void:
	_cyl(Vector3(0,.58,0),1.42,1.16,"stone",12); _cyl(Vector3(0,1.18,0),1.58,.2,"stone_light",12); _cyl(Vector3(0,1.25,0),1.12,.1,"black",12)
	for x in [-1.28,1.28]: _box(Vector3(x,2.2,0),Vector3(.22,2.4,.22),"dark_wood")
	_box(Vector3(0,3.32,0),Vector3(3.2,.25,.3),"timber"); _cyl(Vector3(0,2.55,0),.25,2.75,"wood",10,Vector3(0,0,PI*.5))
	for a in [-.5,.5]: _box(Vector3(-a*.68,3.85,0),Vector3(1.8,.2,3.8),"roof",Vector3(0,0,a))

func _planter() -> void:
	_cyl(Vector3(0,.42,0),.72,.84,"stone",10); _cyl(Vector3(0,.88,0),.64,.12,"dirt",10)
	for a in range(0,360,72): _cyl(Vector3(cos(deg_to_rad(a))*.28,1.25,sin(deg_to_rad(a))*.28),.14,.72,"leaf",7,Vector3(0,0,deg_to_rad(a)*.08))

func _entrance() -> void:
	for z in range(4): _box(Vector3(0,.12+z*.18,1.5-z*.58),Vector3(6-z*.45,.24,1.0),"stone")
	_box(Vector3(0,.55,-1.0),Vector3(4.6,.35,3.0),"stone"); _box(Vector3(0,.76,-.95),Vector3(3.25,.14,2.1),"black")
	for x in [-2.45,2.45]:
		_box(Vector3(x,2.35,-1.55),Vector3(1.05,3.45,1.2),"dungeon"); _box(Vector3(x,4.18,-1.55),Vector3(1.35,.35,1.45),"stone_light"); _box(Vector3(x,1.5,-.88),Vector3(.18,2.1,.18),"iron")
		_lantern(Vector3(x,4.62,-1.55))
	for x in [-1.25,1.25]: _box(Vector3(x,4.65,-1.55),Vector3(2.8,.62,1.0),"stone",Vector3(0,0,-.35 if x<0 else .35))
	_box(Vector3(0,5.42,-1.55),Vector3(.7,1.15,.55),"bronze",Vector3(0,0,.78)); _box(Vector3(0,2.55,-1.45),Vector3(3.3,.18,.18),"iron")
	for x in [-1.25,-.75,-.25,.25,.75,1.25]: _box(Vector3(x,1.75,-1.45),Vector3(.1,1.75,.12),"iron")

func _column(damaged: bool) -> void:
	_box(Vector3(0,.16,0),Vector3(1.5,.32,1.5),"stone"); _box(Vector3(0,.42,0),Vector3(1.2,.22,1.2),"stone_light")
	_cyl(Vector3(0,1.62,0),.52,2.35 if damaged else 2.65,"dungeon",8,Vector3(0,0,.1 if damaged else 0.0))
	if not damaged: _box(Vector3(0,3.05,0),Vector3(1.4,.35,1.4),"stone")
	else: _box(Vector3(.52,.25,.62),Vector3(.55,.3,.4),"dungeon",Vector3(.2,.3,.1))

func _arch() -> void:
	for x in [-1.8,1.8]: _box(Vector3(x,1.7,0),Vector3(.75,3.4,.8),"dungeon"); _box(Vector3(x,3.45,0),Vector3(1.0,.28,1.0),"stone")
	for x in [-1.15,1.15]: _box(Vector3(x,4.0,0),Vector3(2.0,.65,.85),"stone",Vector3(0,0,-.34 if x<0 else .34))
	_box(Vector3(0,4.55,0),Vector3(.65,.65,.88),"stone_light",Vector3(0,0,.78))

func _support() -> void: _arch(); _box(Vector3(0,4.8,0),Vector3(4.8,.28,1.05),"iron")
func _buttress() -> void:
	_box(Vector3(0,1.5,0),Vector3(1.1,3,.9),"dungeon",Vector3(0,0,-.1)); _box(Vector3(0,.22,.4),Vector3(1.65,.44,1.5),"stone")
func _brazier() -> void:
	for a in range(0,360,90): _box(Vector3(cos(deg_to_rad(a))*.42,.78,sin(deg_to_rad(a))*.42),Vector3(.1,1.1,.1),"iron",Vector3(0,0,cos(deg_to_rad(a))*.28))
	_cyl(Vector3(0,1.28,0),.7,.28,"iron",10); _cyl(Vector3(0,1.58,0),.3,.65,"ember",8)
func _torch() -> void:
	_box(Vector3(0,.7,0),Vector3(.16,1.4,.16),"dark_wood",Vector3(0,0,.2)); _box(Vector3(0,1.3,0),Vector3(.5,.12,.5),"iron"); _cyl(Vector3(.12,1.65,0),.2,.58,"ember",8)
func _door() -> void:
	_box(Vector3(0,1.55,0),Vector3(2.65,3.1,.3),"dark_wood")
	for x in [-.82,0.0,.82]: _box(Vector3(x,1.55,.18),Vector3(.16,2.9,.12),"wood")
	for y in [.45,1.55,2.65]: _box(Vector3(0,y,.25),Vector3(2.8,.16,.12),"iron")
	_cyl(Vector3(.72,1.5,.36),.14,.14,"bronze",8,Vector3(PI*.5,0,0))
func _gate() -> void:
	for x in [-1.35,-.9,-.45,0.0,.45,.9,1.35]: _box(Vector3(x,1.65,0),Vector3(.11,3.3,.11),"iron"); _box(Vector3(x,3.35,0),Vector3(.19,.32,.19),"iron",Vector3(0,.78,0))
	for y in [.45,2.0]: _box(Vector3(0,y,0),Vector3(3.1,.14,.14),"iron")
func _dungeon_table() -> void:
	_box(Vector3(0,1,0),Vector3(2.8,.25,1.35),"dark_wood")
	for x in [-1.05,1.05]:
		for z in [-.45,.45]: _box(Vector3(x,.48,z),Vector3(.2,.95,.2),"wood",Vector3(0,0,x*.025))
	_box(Vector3(0,1.18,0),Vector3(1.0,.04,.72),"canvas",Vector3(0,.18,0))
func _rubble() -> void:
	for data in [[Vector3(-.6,.18,0),Vector3(.7,.35,.55)],[Vector3(.12,.22,.1),Vector3(.55,.45,.7)],[Vector3(.65,.14,-.2),Vector3(.48,.28,.4)]]: _box(data[0],data[1],"dungeon",Vector3(.15,.25,.12))
func _chains() -> void:
	for i in range(7): _cyl(Vector3(sin(i*.8)*.12,2.5-i*.32,0),.085,.32,"iron",8,Vector3(0,0,sin(i)*.35))
func _floor_detail() -> void:
	_cyl(Vector3(0,.015,0),1.0,.03,"bronze",12); _cyl(Vector3(0,.035,0),.68,.035,"black",12)
