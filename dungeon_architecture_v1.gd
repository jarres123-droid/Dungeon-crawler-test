extends Node3D

# DUNGEON ARCHITECTURE v2 - Godot 4.x / Android
# Attach to a NEW Node3D named DungeonArchitecture under your procedural
# Dungeon root. Keep DungeonArt v3, DungeonTextures v1 and all combat nodes.
# Purely architectural VISUAL meshes: existing collisions remain untouched.
# Each room is rebuilt on every procedural scene reload.

@export_enum("Lite", "Balanced", "Detailed") var architecture_quality: int = 1
@export var corridor_arches: bool = true
@export var decorative_floor_inlays: bool = true
@export var replace_square_column_visuals: bool = true
@export var replace_straight_door_lintels: bool = true

const ROOM_SPACING: float = 24.0
const WALL_EDGE: float = 7.60
const EDGE_DIRECTIONS = [
    Vector2i(-1, 0), Vector2i(1, 0),
    Vector2i(0, -1), Vector2i(0, 1)
]

var dungeon: Node3D
var surface_materials: Dictionary = {}
var shapes: Dictionary = {}
var batch_data: Dictionary = {}
var randomizer: RandomNumberGenerator = RandomNumberGenerator.new()
var arch_count: int = 0
var column_count: int = 0
var room_count: int = 0
var wall_relief_count: int = 0


func _ready() -> void:
    call_deferred("_begin_after_generation")


func _begin_after_generation() -> void:
    # Parent _ready() creates the procedural rooms. Other decoration scripts
    # are deferred too, so wait for them before adding architecture.
    await get_tree().process_frame
    await get_tree().process_frame
    if not is_inside_tree():
        return
    dungeon = get_parent() as Node3D
    if dungeon == null or not dungeon.has_method("_are_connected"):
        push_warning("DungeonArchitecture must be a direct child of the procedural Dungeon root.")
        return
    var cells_value = dungeon.get("dungeon_cells")
    if not (cells_value is Array):
        push_warning("DungeonArchitecture could not find the room plan.")
        return
    var cells: Array = cells_value
    if cells.is_empty():
        return

    randomizer.randomize()
    _set_up_materials()
    _prepare_meshes()
    _upgrade_existing_columns()
    if replace_straight_door_lintels:
        _hide_old_lintels()

    for value in cells:
        var cell: Vector2i = value
        _decorate_room_architecture(cell)
        room_count += 1
    _decorate_corridor_architecture(cells)
    _write_batches()
    print("Dungeon Architecture v2: %d rooms, %d arched openings, %d wall reliefs, %d upgraded columns, %d instancing groups." % [
        room_count, arch_count, wall_relief_count, column_count, batch_data.size()
    ])


func _make_material(path: String, base_color: Color, repeat: float = 1.0) -> StandardMaterial3D:
    var mat: StandardMaterial3D = StandardMaterial3D.new()
    mat.albedo_color = base_color
    mat.roughness = 0.91
    var tex: Texture2D = null
    if ResourceLoader.exists(path):
        tex = load(path) as Texture2D
    if tex != null:
        mat.albedo_texture = tex
        mat.uv1_scale = Vector3(repeat, repeat, repeat)
        mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    return mat


func _set_up_materials() -> void:
    const FLOOR_TEX: String = "res://dungeon_textures/floor_worn.png"
    const DARK_TEX: String = "res://dungeon_textures/floor_cracked.png"
    const STONE_TEX: String = "res://dungeon_textures/wall_weathered.png"
    const MOSS_TEX: String = "res://dungeon_textures/wall_mossy.png"
    const IRON_TEX: String = "res://dungeon_textures/iron_worn.png"
    surface_materials["stone"] = _make_material(STONE_TEX, Color("#b1b7ba"), 1.1)
    surface_materials["aged"] = _make_material(MOSS_TEX, Color("#9a9e95"), 1.0)
    surface_materials["pale"] = _make_material(STONE_TEX, Color("#c9c5b6"), 0.9)
    surface_materials["dark"] = _make_material(DARK_TEX, Color("#80888e"), 1.0)
    surface_materials["floor"] = _make_material(FLOOR_TEX, Color("#abb2b6"), 1.0)
    surface_materials["metal"] = _make_material(IRON_TEX, Color("#b0a999"), 0.8)
    var metal_material: StandardMaterial3D = surface_materials["metal"]
    metal_material.metallic = 0.42
    surface_materials["bronze"] = _make_material(IRON_TEX, Color("#aa905e"), 0.9)
    var bronze_material: StandardMaterial3D = surface_materials["bronze"]
    bronze_material.metallic = 0.52
    surface_materials["aqua"] = StandardMaterial3D.new()
    surface_materials["aqua"].albedo_color = Color("#70b3b1")
    surface_materials["aqua"].emission_enabled = true
    surface_materials["aqua"].emission = Color("#4b8d95")
    surface_materials["aqua"].emission_energy_multiplier = 0.7

    if not ResourceLoader.exists(STONE_TEX):
        push_warning("DungeonArchitecture: PNG textures not found. Falling back to colored stone; check res://dungeon_textures/.")


func _prepare_meshes() -> void:
    shapes["chamfer"] = _make_beveled_cube(0.085)
    var stone_round: CylinderMesh = CylinderMesh.new()
    stone_round.top_radius = 0.50
    stone_round.bottom_radius = 0.50
    stone_round.height = 1.0
    stone_round.radial_segments = 12 if architecture_quality == 0 else 20
    shapes["column"] = stone_round
    var taper: CylinderMesh = CylinderMesh.new()
    taper.top_radius = 0.44
    taper.bottom_radius = 0.50
    taper.height = 1.0
    taper.radial_segments = 10 if architecture_quality == 0 else 16
    shapes["taper"] = taper
    for i in range(9):
        var a0: float = PI * float(i) / 9.0 + 0.008
        var a1: float = PI * float(i + 1) / 9.0 - 0.008
        shapes["arch%d" % i] = _make_arch_wedge(a0, a1)
    var medallion: SphereMesh = SphereMesh.new()
    medallion.radius = 0.50
    medallion.height = 1.0
    medallion.radial_segments = 14
    medallion.rings = 8
    shapes["medallion"] = medallion


# A real chamfered mesh with flat faces, 12 bevels and 8 corner patches,
# shared by all architectural blocks. No CSG or Blender required.
func _make_beveled_cube(bevel: float) -> ArrayMesh:
    var tool: SurfaceTool = SurfaceTool.new()
    tool.begin(Mesh.PRIMITIVE_TRIANGLES)
    var q: float = 0.5 - bevel
    for sign_value in [-1.0, 1.0]:
        for axis in range(3):
            var polygon: Array[Vector3] = []
            for uv in [Vector2(-q, -q), Vector2(q, -q), Vector2(q, q), Vector2(-q, q)]:
                var p: Vector3 = Vector3.ZERO
                if axis == 0:
                    p = Vector3(0.5 * sign_value, uv.x, uv.y)
                elif axis == 1:
                    p = Vector3(uv.x, 0.5 * sign_value, uv.y)
                else:
                    p = Vector3(uv.x, uv.y, 0.5 * sign_value)
                polygon.append(p)
            _emit_quad(tool, polygon[0], polygon[1], polygon[2], polygon[3],
                Vector3.RIGHT * sign_value if axis == 0 else (
                Vector3.UP * sign_value if axis == 1 else Vector3.BACK * sign_value))
    for s1 in [-1.0, 1.0]:
        for s2 in [-1.0, 1.0]:
            # Bevels parallel to the Z axis.
            _emit_quad(tool,
                Vector3(s1 * 0.5, s2 * q, -q), Vector3(s1 * q, s2 * 0.5, -q),
                Vector3(s1 * q, s2 * 0.5, q), Vector3(s1 * 0.5, s2 * q, q),
                Vector3(s1, s2, 0.0))
            # Bevels parallel to the Y axis.
            _emit_quad(tool,
                Vector3(s1 * 0.5, -q, s2 * q), Vector3(s1 * q, -q, s2 * 0.5),
                Vector3(s1 * q, q, s2 * 0.5), Vector3(s1 * 0.5, q, s2 * q),
                Vector3(s1, 0.0, s2))
            # Bevels parallel to the X axis.
            _emit_quad(tool,
                Vector3(-q, s1 * 0.5, s2 * q), Vector3(-q, s1 * q, s2 * 0.5),
                Vector3(q, s1 * q, s2 * 0.5), Vector3(q, s1 * 0.5, s2 * q),
                Vector3(0.0, s1, s2))
            for s3 in [-1.0, 1.0]:
                _emit_triangle(tool,
                    Vector3(s1 * 0.5, s2 * q, s3 * q),
                    Vector3(s1 * q, s2 * 0.5, s3 * q),
                    Vector3(s1 * q, s2 * q, s3 * 0.5),
                    Vector3(s1, s2, s3))
    return tool.commit()


# Arch stones are extruded sectors of a true semicircular ring.
# They create recognizable curved doorways instead of rectangular lintels.
func _make_arch_wedge(start_angle: float, end_angle: float) -> ArrayMesh:
    var inner_r: float = 1.84
    var outer_r: float = 2.12
    var thick: float = 0.50
    var a: Vector2 = Vector2(cos(start_angle), sin(start_angle))
    var b: Vector2 = Vector2(cos(end_angle), sin(end_angle))
    var ia: Vector3 = Vector3(a.x * inner_r, a.y * inner_r, 0)
    var oa: Vector3 = Vector3(a.x * outer_r, a.y * outer_r, 0)
    var ib: Vector3 = Vector3(b.x * inner_r, b.y * inner_r, 0)
    var ob: Vector3 = Vector3(b.x * outer_r, b.y * outer_r, 0)
    var forward: Vector3 = Vector3(0, 0, thick * 0.5)
    var backward: Vector3 = Vector3(0, 0, -thick * 0.5)
    var center_angle: float = (start_angle + end_angle) * 0.5
    var radial: Vector3 = Vector3(cos(center_angle), sin(center_angle), 0)
    var tangent_a: Vector3 = Vector3(-a.y, a.x, 0)
    var tangent_b: Vector3 = Vector3(-b.y, b.x, 0)
    var tool: SurfaceTool = SurfaceTool.new()
    tool.begin(Mesh.PRIMITIVE_TRIANGLES)
    _emit_quad(tool, ia + forward, oa + forward, ob + forward, ib + forward, Vector3.BACK)
    _emit_quad(tool, ia + backward, ib + backward, ob + backward, oa + backward, Vector3.FORWARD)
    _emit_quad(tool, oa + forward, oa + backward, ob + backward, ob + forward, radial)
    _emit_quad(tool, ia + forward, ib + forward, ib + backward, ia + backward, -radial)
    _emit_quad(tool, ia + forward, ia + backward, oa + backward, oa + forward, -tangent_a)
    _emit_quad(tool, ib + forward, ob + forward, ob + backward, ib + backward, tangent_b)
    return tool.commit()


func _emit_quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3,
        d: Vector3, hint: Vector3) -> void:
    _emit_triangle(tool, a, b, c, hint)
    _emit_triangle(tool, a, c, d, hint)


func _emit_triangle(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3,
        hint: Vector3) -> void:
    var n: Vector3 = hint.normalized()
    if (b - a).cross(c - a).dot(n) < 0.0:
        var temp: Vector3 = b
        b = c
        c = temp
    for v in [a, b, c]:
        tool.set_normal(n)
        var uv: Vector2 = Vector2(v.x, v.y)
        if absf(n.y) >= absf(n.x) and absf(n.y) >= absf(n.z):
            uv = Vector2(v.x, v.z)
        elif absf(n.x) >= absf(n.z):
            uv = Vector2(v.z, v.y)
        tool.set_uv(uv)
        tool.add_vertex(v)


# Instances are grouped by mesh+material, not one draw call per brick.
func _stamp(shape_key: String, material_key: String, at: Vector3,
        dimensions: Vector3, angle: float = 0.0) -> void:
    var key: String = shape_key + ":" + material_key
    if not batch_data.has(key):
        batch_data[key] = []
    var basis: Basis = Basis.from_euler(Vector3(0.0, angle, 0.0))
    var tx: Transform3D = Transform3D(basis.scaled(dimensions), at)
    batch_data[key].append(tx)


func _block(material_key: String, at: Vector3, dimensions: Vector3, angle: float = 0.0) -> void:
    _stamp("chamfer", material_key, at, dimensions, angle)


func _round(shape_key: String, material_key: String, at: Vector3, dimensions: Vector3) -> void:
    _stamp(shape_key, material_key, at, dimensions)


func _write_batches() -> void:
    for key in batch_data.keys():
        var parts: PackedStringArray = String(key).split(":")
        var geo: Mesh = shapes[parts[0]]
        var inst: Array = batch_data[key]
        if inst.is_empty():
            continue
        var mesh_multi: MultiMesh = MultiMesh.new()
        mesh_multi.transform_format = MultiMesh.TRANSFORM_3D
        mesh_multi.mesh = geo
        mesh_multi.instance_count = inst.size()
        for i in range(inst.size()):
            mesh_multi.set_instance_transform(i, inst[i])
        var item: MultiMeshInstance3D = MultiMeshInstance3D.new()
        item.name = "Architecture " + String(key)
        item.multimesh = mesh_multi
        item.material_override = surface_materials[parts[1]]
        add_child(item)


func _linked(cell: Vector2i, neighbor: Vector2i) -> bool:
    return bool(dungeon.call("_are_connected", cell, neighbor))


func _room_center(cell: Vector2i) -> Vector3:
    return Vector3(float(cell.x) * ROOM_SPACING, 0.0, float(cell.y) * ROOM_SPACING)


func _decorate_room_architecture(cell: Vector2i) -> void:
    var center: Vector3 = _room_center(cell)
    var is_exit: bool = cell == dungeon.get("exit_cell")
    var is_entry: bool = cell == Vector2i.ZERO

    for side in EDGE_DIRECTIONS:
        var linked: bool = _linked(cell, cell + side)
        var behind: bool = side.x < 0 or side.y < 0
        if linked:
            if behind:
                _build_arch(center, side, "pale" if is_exit else "stone")
            else:
                _build_low_entrance(center, side)
        else:
            if behind:
                _build_wall_features(center, side, cell, is_exit)
            else:
                _build_low_wall_cap(center, side)

    if decorative_floor_inlays:
        _add_perimeter_floor_border(center, cell, is_exit, is_entry)

    # A little architecture-specific asymmetry in the corners, not the combat lane.
    if architecture_quality > 0:
        _round("medallion", "bronze" if is_exit else "dark",
            center + Vector3(5.80, 0.12, 5.80), Vector3(0.70, 0.06, 0.70))
        if not is_entry:
            _round("medallion", "aged", center + Vector3(-5.72, 0.12, 5.75),
                Vector3(0.55, 0.05, 0.55))


func _build_arch(center: Vector3, side: Vector2i, material_key: String) -> void:
    var at: Vector3 = center + Vector3(
        float(side.x) * (WALL_EDGE - 0.09), 1.00,
        float(side.y) * (WALL_EDGE - 0.09)
    )
    var yaw: float = PI * 0.5 if side.x != 0 else 0.0
    for i in range(9):
        # A slightly oversized, recessed ring gives the opening visible depth
        # while the original arch remains the bright foreground silhouette.
        var recess: Vector3 = at + Vector3(float(side.x) * 0.10, 0.0, float(side.y) * 0.10)
        _stamp("arch%d" % i, "dark", recess, Vector3(1.10, 1.08, 1.12), yaw)
        var stone: String = material_key
        if i % 4 == 0 and architecture_quality > 0:
            stone = "pale"
        if i == 4:
            stone = "pale"  # Prominent crown keystone.
        _stamp("arch%d" % i, stone, at, Vector3.ONE, yaw)
    arch_count += 1
    # Proper visible side piers; 4m opening stays clear, no collision added.
    for sign_value in [-1.0, 1.0]:
        var offset: Vector3 = Vector3(0, 0, sign_value * 2.33) if side.x != 0 else Vector3(sign_value * 2.33, 0, 0)
        var pier: Vector3 = at + offset
        _block("aged", pier + Vector3(0, -0.08, 0), Vector3(0.57, 1.88, 0.60))
        var inner_offset: Vector3 = Vector3(-float(side.x) * 0.10, 0.0, -float(side.y) * 0.10)
        _block("stone", pier + inner_offset + Vector3(0, -0.05, 0), Vector3(0.68, 1.54, 0.72))
        _block("pale", pier + Vector3(0, 0.85, 0), Vector3(0.78, 0.17, 0.76))
        _block("dark", pier + Vector3(0, -0.89, 0), Vector3(0.75, 0.13, 0.74))
        if architecture_quality > 0:
            _round("medallion", "bronze", pier + Vector3(0, 1.04, 0),
                Vector3(0.13, 0.13, 0.13))
    # Inlaid flat threshold does not obstruct walking across the door.
    _threshold(center, side)


func _threshold(center: Vector3, side: Vector2i) -> void:
    var p: Vector3 = center + Vector3(float(side.x) * 7.75, 0.095, float(side.y) * 7.75)
    var size: Vector3 = Vector3(3.65, 0.045, 0.50)
    if side.x != 0:
        size = Vector3(0.50, 0.045, 3.65)
    _block("pale", p, size)
    for t in [-1.45, 1.45]:
        var corner: Vector3 = p + Vector3(0, 0.018, t) if side.x != 0 else p + Vector3(t, 0.018, 0)
        _round("medallion", "bronze", corner, Vector3(0.18, 0.038, 0.18))


func _build_low_entrance(center: Vector3, side: Vector2i) -> void:
    _threshold(center, side)
    # Low front walls preserve visibility with the isometric camera.
    var at: Vector3 = center + Vector3(float(side.x) * 7.55, 0, float(side.y) * 7.55)
    for s in [-1.0, 1.0]:
        var p: Vector3 = at + (Vector3(0, 0, s * 2.42) if side.x != 0 else Vector3(s * 2.42, 0, 0))
        _block("pale", p + Vector3(0, 0.79, 0), Vector3(0.48, 0.45, 0.48))
        _block("dark", p + Vector3(0, 1.03, 0), Vector3(0.57, 0.12, 0.56))


func _build_wall_features(center: Vector3, side: Vector2i, cell: Vector2i, is_exit: bool) -> void:
    # Raised piers are attached to the far -X/-Z walls, never in the room center.
    for offset in [-5.7, 5.7]:
        var p: Vector3 = center + Vector3(float(side.x) * 7.20, 0.0, float(side.y) * 7.20)
        if side.x != 0:
            p.z += offset
        else:
            p.x += offset
        _block("aged", p + Vector3(0, 1.28, 0), Vector3(0.62, 2.36, 0.72))
        _block("pale", p + Vector3(0, 2.54, 0), Vector3(0.83, 0.16, 0.89))
        _block("dark", p + Vector3(0, 0.19, 0), Vector3(0.79, 0.25, 0.88))
    _build_wall_relief(center, side, cell, is_exit)
    if architecture_quality == 0:
        return
    var boss: Vector3 = center + Vector3(float(side.x) * 7.20, 1.62, float(side.y) * 7.20)
    _round("medallion", "bronze" if is_exit else "stone", boss,
        Vector3(0.28, 0.55, 0.66) if side.x != 0 else Vector3(0.66, 0.55, 0.28))
    _round("medallion", "aqua" if is_exit else "dark", boss + Vector3(
        -float(side.x) * 0.15, 0.0, -float(side.y) * 0.15),
        Vector3(0.14, 0.20, 0.20) if side.x != 0 else Vector3(0.20, 0.20, 0.14))


func _build_wall_relief(center: Vector3, side: Vector2i, cell: Vector2i, is_exit: bool) -> void:
    # Shallow courses sit against existing solid walls. They are visual-only,
    # leave the room footprint unchanged, and share the normal material batches.
    var normal: Vector3 = Vector3(-float(side.x), 0.0, -float(side.y))
    var wall_center: Vector3 = center + Vector3(
        float(side.x) * 7.48, 0.0, float(side.y) * 7.48
    )
    var horizontal: Vector3 = Vector3(10.4, 0.16, 0.18)
    var upright: Vector3 = Vector3(0.20, 1.72, 0.18)
    if side.x != 0:
        horizontal = Vector3(0.18, 0.16, 10.4)
        upright = Vector3(0.18, 1.72, 0.20)

    _block("dark", wall_center + normal * 0.05 + Vector3(0, 0.20, 0), horizontal)
    _block("pale" if is_exit else "stone",
        wall_center + normal * 0.075 + Vector3(0, 2.72, 0), horizontal)

    # A deterministic per-room variation avoids a repetitive grid without
    # introducing more materials or per-instance draw calls.
    var variation: int = absi(cell.x * 31 + cell.y * 17) % 3
    var offsets: Array[float] = []
    offsets.assign([0.0] if variation == 0 else [-2.75, 2.75])
    if variation == 2 and architecture_quality > 1:
        offsets.assign([-3.45, 0.0, 3.45])
    for offset in offsets:
        var p: Vector3 = wall_center + normal * 0.09 + Vector3(0, 1.42, 0)
        if side.x != 0:
            p.z += offset
        else:
            p.x += offset
        _block("aged", p, upright)
        _block("pale", p + Vector3(0, 0.94, 0),
            Vector3(0.31, 0.12, 0.31))
    wall_relief_count += 1


func _build_low_wall_cap(center: Vector3, side: Vector2i) -> void:
    if architecture_quality == 0:
        return
    var p: Vector3 = center + Vector3(float(side.x) * 7.57, 1.39, float(side.y) * 7.57)
    var size: Vector3 = Vector3(15.0, 0.16, 0.84)
    if side.x != 0:
        size = Vector3(0.84, 0.16, 15.0)
    _block("pale", p, size)


func _add_perimeter_floor_border(center: Vector3, cell: Vector2i,
        is_exit: bool, is_entry: bool) -> void:
    # Existing floor textures remain visible; only slim edge stone inlays are added.
    var steps: int = 9 if architecture_quality == 0 else 13
    var span: float = 13.2
    for i in range(steps):
        var u: float = -6.6 + float(i) * span / float(steps - 1)
        for side in EDGE_DIRECTIONS:
            # Avoid the central door lane if this side is connected.
            if _linked(cell, cell + side) and absf(u) < 2.15:
                continue
            var p: Vector3 = center + Vector3(u, 0.075, float(side.y) * 6.72)
            var s: Vector3 = Vector3(0.80, 0.045, 0.28)
            if side.x != 0:
                p = center + Vector3(float(side.x) * 6.72, 0.075, u)
                s = Vector3(0.28, 0.045, 0.80)
            var material_key: String = "pale" if is_exit else ("dark" if (i + cell.x + cell.y) % 5 == 0 else "floor")
            _block(material_key, p, s)
    if is_entry:
        _block("bronze", center + Vector3(-4.4, 0.083, -4.8), Vector3(1.5, 0.025, 0.07))
    if is_exit:
        for i in range(8):
            var angle: float = TAU * float(i) / 8.0
            var p: Vector3 = center + Vector3(cos(angle) * 3.1, 0.072, sin(angle) * 3.1)
            _round("medallion", "bronze", p, Vector3(0.25, 0.04, 0.25))


func _decorate_corridor_architecture(cells: Array) -> void:
    for value in cells:
        var cell: Vector2i = value
        for side in [Vector2i(1, 0), Vector2i(0, 1)]:
            if not _linked(cell, cell + side):
                continue
            var p: Vector3 = _room_center(cell) + Vector3(
                float(side.x) * ROOM_SPACING * 0.5, 0.0,
                float(side.y) * ROOM_SPACING * 0.5
            )
            if corridor_arches:
                # One vaulted rib centered in each passage, instead of a solid wall.
                var yaw: float = PI * 0.5 if side.x != 0 else 0.0
                _corridor_rib(p, yaw, side)
            # Small worn cobbles along the side edges only. Clear 4m central walkway.
            if architecture_quality > 0:
                for i in range(4):
                    var along: float = -2.7 + float(i) * 1.8
                    for sign_value in [-1.0, 1.0]:
                        var stone_at: Vector3 = p + (Vector3(along, 0.078, sign_value * 1.66)
                            if side.x != 0 else Vector3(sign_value * 1.66, 0.078, along))
                        _block("floor" if i % 2 == 0 else "dark", stone_at,
                            Vector3(0.62, 0.045, 0.26) if side.x != 0 else Vector3(0.26, 0.045, 0.62))


func _corridor_rib(p: Vector3, yaw: float, side: Vector2i) -> void:
    var arch_center: Vector3 = p + Vector3(0, 0.66, 0)
    # A slightly smaller copy of the room arch. No physics collision added.
    for i in range(9):
        _stamp("arch%d" % i, "dark", arch_center, Vector3(0.98, 0.98, 0.96), yaw)
        _stamp("arch%d" % i, "stone" if i % 3 else "pale", arch_center,
            Vector3(0.92, 0.92, 0.90), yaw)
    arch_count += 1
    for sign_value in [-1.0, 1.0]:
        var edge: Vector3 = (Vector3(0, 0.0, sign_value * 2.00)
            if side.x != 0 else Vector3(sign_value * 2.00, 0.0, 0))
        _block("aged", p + edge + Vector3(0, 0.44, 0), Vector3(0.44, 0.90, 0.47))
        _block("pale", p + edge + Vector3(0, 0.93, 0), Vector3(0.54, 0.12, 0.54))


func _upgrade_existing_columns() -> void:
    if not replace_square_column_visuals:
        return
    for node in dungeon.get_children():
        if not (node is Node3D):
            continue
        if String(node.name) != "Column":
            continue
        var column: Node3D = node as Node3D
        # Only hide the original mesh; leave the original StaticBody3D and
        # CollisionShape3D active so the player still collides correctly.
        for child in column.get_children():
            if child is MeshInstance3D:
                child.visible = false
        var p: Vector3 = column.position - Vector3(0.0, 1.38, 0.0)
        _block("dark", p + Vector3(0, 0.12, 0), Vector3(1.24, 0.24, 1.24))
        _block("pale", p + Vector3(0, 0.32, 0), Vector3(1.10, 0.16, 1.10))
        _round("taper", "stone", p + Vector3(0, 1.41, 0), Vector3(0.96, 2.15, 0.96))
        _round("column", "pale", p + Vector3(0, 2.49, 0), Vector3(1.06, 0.12, 1.06))
        _block("pale", p + Vector3(0, 2.69, 0), Vector3(1.35, 0.26, 1.35))
        if architecture_quality > 0:
            for height in [0.47, 2.32]:
                _round("column", "bronze", p + Vector3(0, height, 0),
                    Vector3(1.03, 0.055, 1.03))
        column_count += 1
    # Old square caps/feet are visual-only, so hiding these does NOT alter collision.
    for node in dungeon.get_children():
        if not (node is Node3D):
            continue
        if String(node.name) == "Column cap" or String(node.name) == "Column foot":
            for child in node.get_children():
                if child is MeshInstance3D:
                    child.visible = false


func _hide_old_lintels() -> void:
    # The generated flat lintel otherwise runs through the curved new arch.
    # Only visual meshes are hidden, NEVER collision shapes.
    for node in dungeon.get_children():
        if not (node is Node3D):
            continue
        if String(node.name) == "Stone door lintel":
            for child in node.get_children():
                if child is MeshInstance3D:
                    child.visible = false
