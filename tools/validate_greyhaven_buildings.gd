extends SceneTree

const ARCHETYPES := ["small_cottage", "medium_residence", "merchant_shop", "workshop", "important_hall"]

func _initialize() -> void:
	for archetype in ARCHETYPES:
		var path := "res://assets/greyhaven/buildings/archetypes/%s.tscn" % archetype
		var packed := load(path) as PackedScene
		assert(packed != null, "Missing building archetype: " + path)
		var building := packed.instantiate()
		root.add_child(building)
		await process_frame
		assert(building.get_meta("geometry_validated", false), archetype + " did not validate")
		assert(building.get_meta("roof_run", 0.0) > 0.0, archetype + " has invalid roof run")
		assert(building.get_meta("roof_rise", 0.0) > 0.0, archetype + " has invalid roof rise")
		assert(building.find_child("Roof slope", true, false) != null, archetype + " is missing a roof half")
		assert(building.find_child("Mirrored roof slope", true, false) != null, archetype + " is missing its mirrored roof half")
		assert(building.find_child("Ridge shadow", true, false) != null, archetype + " is missing layered ridge construction")
		assert(building.find_child("Exposed rafter tail", true, false) != null, archetype + " is missing roof support detail")
		assert(building.find_child("Corner footing block", true, false) != null, archetype + " is missing foundation corner modules")
		building.queue_free()
		await process_frame
	print("Greyhaven building validation: 5 archetypes passed")
	quit(0)
