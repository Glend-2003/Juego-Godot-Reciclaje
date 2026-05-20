extends Node3D

const FOREST_SCENE := preload("res://Meshy_AI_Floating_Forest_Islan_0520035441_texture.glb")
const FLOOR_TOP_Y := 1.75
const FOREST_SCALE := 1.0
const FOREST_RING_DEPTH := 6         # anillos extra de islas por FUERA del hangar
const FOREST_TILE_OVERLAP := 0.92    # <1 = solape leve para evitar huecos
const FOREST_Y_OFFSET := -6.5        # afinación manual: positivo = sube las islas

@onready var angar: Node3D = $Angar
@onready var floor_body: StaticBody3D = $Floor
@onready var floor_shape: CollisionShape3D = $Floor/CollisionShape3D

func _ready() -> void:
	await get_tree().process_frame
	var aabb := _world_aabb(angar)
	var floor_y := aabb.position.y
	var ceiling_y := aabb.position.y + aabb.size.y
	print("Angar AABB (world):")
	print("  min Y (piso real)  = ", floor_y)
	print("  max Y (techo)      = ", ceiling_y)
	print("  size               = ", aabb.size)

	print("Floor (manual) global Y = ", floor_body.global_position.y)

	_spawn_forest(aabb)
	_spawn_invisible_walls(aabb)

func _spawn_invisible_walls(angar_aabb: AABB) -> void:
	# Paredes invisibles en el perímetro del hangar para que el jugador no
	# pueda salir hacia el bosque.
	var walls_root := StaticBody3D.new()
	walls_root.name = "InvisibleWalls"
	add_child(walls_root)

	var center := Vector3(
		angar_aabb.position.x + angar_aabb.size.x * 0.5,
		FLOOR_TOP_Y,
		angar_aabb.position.z + angar_aabb.size.z * 0.5
	)
	var half_x: float = angar_aabb.size.x * 0.5
	var half_z: float = angar_aabb.size.z * 0.5
	var wall_thickness: float = 0.5
	var wall_height: float = 8.0    # alto suficiente para bloquear saltos
	var inset: float = 15.0         # cuánto hacia adentro del hangar están las paredes (subí para acortar zona caminable)

	var len_x: float = angar_aabb.size.x - inset * 2.0
	var len_z: float = angar_aabb.size.z - inset * 2.0
	# Pared norte (+Z)
	_add_wall(walls_root,
		Vector3(center.x, center.y + wall_height * 0.5, center.z + half_z - inset),
		Vector3(len_x, wall_height, wall_thickness))
	# Pared sur (-Z)
	_add_wall(walls_root,
		Vector3(center.x, center.y + wall_height * 0.5, center.z - half_z + inset),
		Vector3(len_x, wall_height, wall_thickness))
	# Pared este (+X)
	_add_wall(walls_root,
		Vector3(center.x + half_x - inset, center.y + wall_height * 0.5, center.z),
		Vector3(wall_thickness, wall_height, len_z))
	# Pared oeste (-X)
	_add_wall(walls_root,
		Vector3(center.x - half_x + inset, center.y + wall_height * 0.5, center.z),
		Vector3(wall_thickness, wall_height, len_z))

	print("[Walls] 4 paredes invisibles colocadas en el perímetro del hangar")

func _add_wall(parent: StaticBody3D, pos: Vector3, size: Vector3) -> void:
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	col.shape = box
	col.position = pos
	parent.add_child(col)

func _spawn_forest(angar_aabb: AABB) -> void:
	# Sonda para medir el AABB real de una isla a la escala que vamos a usar.
	var probe: Node3D = FOREST_SCENE.instantiate()
	add_child(probe)
	probe.scale = Vector3(FOREST_SCALE, FOREST_SCALE, FOREST_SCALE)
	await get_tree().process_frame
	var probe_aabb := _world_aabb(probe)
	var tile_size_x: float = probe_aabb.size.x * FOREST_TILE_OVERLAP
	var tile_size_z: float = probe_aabb.size.z * FOREST_TILE_OVERLAP
	var island_top_relative: float = (probe_aabb.position.y + probe_aabb.size.y) - probe.global_position.y
	probe.queue_free()

	if tile_size_x <= 0.01 or tile_size_z <= 0.01:
		push_warning("[Forest] tile_size inválido, abortando spawn")
		return

	var center := Vector3(
		angar_aabb.position.x + angar_aabb.size.x * 0.5,
		0.0,
		angar_aabb.position.z + angar_aabb.size.z * 0.5
	)
	var hangar_half_x: float = angar_aabb.size.x * 0.5
	var hangar_half_z: float = angar_aabb.size.z * 0.5

	var forest_root := Node3D.new()
	forest_root.name = "Forest"
	add_child(forest_root)

	# Colocar el origen del GLB al nivel del piso (la mayoría de modelos de
	# islas tienen el pivote en su superficie). Si no, ajustar FOREST_Y_OFFSET.
	var y: float = FLOOR_TOP_Y + FOREST_Y_OFFSET
	# Pequeño solape de la primera fila contra la pared del hangar (negativo = se mete
	# un poco hacia adentro para no dejar hueco, positivo = se aleja).
	var wall_overlap: float = -0.05

	# Posiciones a lo largo de X: columnas externas (a izquierda y derecha del hangar)
	# + columnas internas (cruzando el ancho del hangar). La primera externa siempre
	# arranca pegada a la pared, así los 4 lados son simétricos.
	var xs: Array[float] = []
	for k in range(FOREST_RING_DEPTH + 1):
		var off: float = hangar_half_x + tile_size_x * (0.5 + float(k)) + wall_overlap * tile_size_x
		xs.append(center.x + off)
		xs.append(center.x - off)
	var inner_count_x: int = int(ceil((2.0 * hangar_half_x) / tile_size_x))
	for j in range(inner_count_x):
		xs.append(center.x - hangar_half_x + tile_size_x * (0.5 + float(j)))

	var zs: Array[float] = []
	for k in range(FOREST_RING_DEPTH + 1):
		var off: float = hangar_half_z + tile_size_z * (0.5 + float(k)) + wall_overlap * tile_size_z
		zs.append(center.z + off)
		zs.append(center.z - off)
	var inner_count_z: int = int(ceil((2.0 * hangar_half_z) / tile_size_z))
	for j in range(inner_count_z):
		zs.append(center.z - hangar_half_z + tile_size_z * (0.5 + float(j)))

	var spawned: int = 0
	for px in xs:
		for pz in zs:
			# Saltar islas cuyo centro caiga totalmente dentro del hangar
			# (esa zona es el propio hangar, no se rellena de bosque).
			var inside_hangar: bool = (
				abs(px - center.x) < hangar_half_x
				and abs(pz - center.z) < hangar_half_z
			)
			if inside_hangar:
				continue
			var inst: Node3D = FOREST_SCENE.instantiate()
			forest_root.add_child(inst)
			inst.scale = Vector3(FOREST_SCALE, FOREST_SCALE, FOREST_SCALE)
			inst.position = Vector3(px, y, pz)
			spawned += 1

	print("[Forest] tile=(", tile_size_x, ",", tile_size_z, ") top_rel=", island_top_relative, " xs=", xs.size(), " zs=", zs.size(), " islas=", spawned, " y=", y)

func _world_aabb(node: Node) -> AABB:
	var combined := AABB()
	var first := true
	for child in _all_descendants(node):
		if child is VisualInstance3D:
			var vi := child as VisualInstance3D
			var a := vi.get_aabb()
			a = vi.global_transform * a
			if first:
				combined = a
				first = false
			else:
				combined = combined.merge(a)
	return combined

func _all_descendants(node: Node) -> Array:
	var out: Array = []
	for c in node.get_children():
		out.append(c)
		out.append_array(_all_descendants(c))
	return out
