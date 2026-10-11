extends SceneTree

const GENERATOR_SCRIPT := preload("res://dungeonprocedural.gd")
const TEST_SEED: int = 24681357
var failed: bool = false


func _initialize() -> void:
	var first: Node = _generate(TEST_SEED)
	var second: Node = _generate(TEST_SEED)
	var random_run: Node = _generate(0)

	_assert(first.validate_connectivity(), "fixed-seed layout is connected")
	_assert(second.validate_connectivity(), "repeated fixed-seed layout is connected")
	_assert(random_run.validate_connectivity(), "random layout is connected")
	_assert(first.dungeon_cells.size() == first.rooms_to_generate, "requested room count was generated")
	_assert(_plan_signature(first) == _plan_signature(second), "fixed seed reproduces the room plan")
	_assert(first.get_active_seed() == TEST_SEED, "fixed seed is reported as active")
	_assert(random_run.get_active_seed() != 0, "random mode reports the generated seed")

	var broken: Node = _generate(TEST_SEED)
	broken.connections.clear()
	_assert(not broken.validate_connectivity(), "connectivity validator rejects a disconnected plan")

	first.free()
	second.free()
	random_run.free()
	broken.free()
	if failed:
		quit(1)
	else:
		print("Dungeon generation validation passed.")
		quit(0)


func _generate(seed_value: int) -> Node:
	var generator: Node = GENERATOR_SCRIPT.new()
	generator.debug_seed = seed_value
	generator._configure_rng()
	generator._generate_connected_plan()
	return generator


func _plan_signature(generator: Node) -> String:
	var cells: PackedStringArray = []
	for cell in generator.dungeon_cells:
		cells.append(str(cell))
	cells.sort()
	var edges: PackedStringArray = []
	for edge in generator.connections.keys():
		edges.append(str(edge))
	edges.sort()
	return "|".join(cells) + "::" + "|".join(edges)


func _assert(condition: bool, description: String) -> void:
	if condition:
		return
	failed = true
	push_error("Dungeon generation validation failed: %s" % description)
