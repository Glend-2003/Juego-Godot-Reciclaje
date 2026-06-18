extends Node3D

const FOREST_SCENE := preload("res://Meshy_AI_Floating_Forest_Islan_0520035441_texture.glb")
const FLOOR_TOP_Y := 1.75
const FOREST_SCALE := 1.0
const FOREST_RING_DEPTH := 6         # anillos extra de islas por FUERA del hangar
const FOREST_TILE_OVERLAP := 0.92    # <1 = solape leve para evitar huecos
const FOREST_Y_OFFSET := -6.5        # afinación manual: positivo = sube las islas

const TRASH_RADIO := 24.0            # radio de dispersión de la basura (amplio: hay que caminar)

@onready var angar: Node3D = $Angar
@onready var floor_body: StaticBody3D = $Floor
@onready var floor_shape: CollisionShape3D = $Floor/CollisionShape3D
@onready var contador_label: Label = $CanvasLayer/TextureRect/Label
@onready var timer: Timer = $Timer
@onready var trash_spawner: TrashSpawner = $TrashSpawner

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
	_generate_hangar_collisions()
	_spawn_invisible_walls(aabb)
	_spawn_bins_and_caps(aabb)

# Genera colisiones REALES del hangar siguiendo la geometría del mesh.
# Esto crea un StaticBody3D + ConcavePolygonShape3D por cada MeshInstance3D
# dentro del Angar (paredes, columnas, marcos, etc.), de modo que el jugador
# choca exactamente con lo que ve. Es lo más cercano a un "level art = level
# collision" y elimina la necesidad de paredes invisibles aproximadas.
func _generate_hangar_collisions() -> void:
	var count: int = 0
	for n in _all_descendants(angar):
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			# Evitar duplicar colisión si ya se generó (re-ejecuciones, hot reload).
			var already_has: bool = false
			for c in mi.get_children():
				if c is StaticBody3D:
					already_has = true
					break
			if already_has:
				continue
			mi.create_trimesh_collision()
			count += 1
	print("[Hangar] Colisiones trimesh generadas para ", count, " meshes del Angar")

const BIN_AZUL := preload("res://basurero-azul.glb")
const BIN_GRIS := preload("res://basurero-gris.glb")
const BIN_NEGRO := preload("res://basurero-negro.glb")
const CAP_COLLECTION := preload("res://Meshy_AI_Bottle_Cap_Collection_0618014945_texture.glb")

func _spawn_bins_and_caps(angar_aabb: AABB) -> void:
	# Coloca los 3 basureros + la colección de tapas en una línea centrada
	# dentro del hangar para que el jugador los vea al entrar.
	var center_x: float = angar_aabb.position.x + angar_aabb.size.x * 0.5
	var center_z: float = angar_aabb.position.z + angar_aabb.size.z * 0.5
	var y: float = FLOOR_TOP_Y

	var spacing: float = 6.0
	var items := [
		{"scene": BIN_AZUL,       "scale": 1.5, "name": "BasureroAzul"},
		{"scene": BIN_GRIS,       "scale": 1.5, "name": "BasureroGris"},
		{"scene": BIN_NEGRO,      "scale": 1.5, "name": "BasureroNegro"},
		{"scene": CAP_COLLECTION, "scale": 1.0, "name": "CapCollection"},
	]
	var total: float = float(items.size() - 1) * spacing
	var start_x: float = center_x - total * 0.5

	var root := Node3D.new()
	root.name = "Bins"
	add_child(root)

	for i in range(items.size()):
		var it: Dictionary = items[i]
		var inst: Node3D = (it["scene"] as PackedScene).instantiate()
		inst.name = it["name"]
		root.add_child(inst)
		inst.scale = Vector3(it["scale"], it["scale"], it["scale"])
		inst.position = Vector3(start_x + float(i) * spacing, y, center_z)

	print("[Bins] colocados ", items.size(), " objetos centrados en el hangar (", center_x, ",", center_z, ")")

	# Centro del hangar a la altura del piso: punto de referencia para la basura
	# y los basureros.
	var centro := Vector3(
		angar_aabb.position.x + angar_aabb.size.x * 0.5,
		FLOOR_TOP_Y,
		angar_aabb.position.z + angar_aabb.size.z * 0.5
	)
	# Genera la basura aleatoria alrededor del centro (no desaparece sola).
	trash_spawner.generar(centro, TRASH_RADIO, FLOOR_TOP_Y)

# Paredes invisibles en el perímetro del hangar como red de seguridad: aunque las
# colisiones reales del Angar bloquean las paredes visibles, este muro extra
# garantiza que el jugador no escape al bosque por puertas/aberturas del modelo.
func _spawn_invisible_walls(angar_aabb: AABB) -> void:
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
	var wall_height: float = 8.0
	var inset: float = 15.0
	var len_x: float = angar_aabb.size.x - inset * 2.0
	var len_z: float = angar_aabb.size.z - inset * 2.0

	_add_wall(walls_root,
		Vector3(center.x, center.y + wall_height * 0.5, center.z + half_z - inset),
		Vector3(len_x, wall_height, wall_thickness))
	_add_wall(walls_root,
		Vector3(center.x, center.y + wall_height * 0.5, center.z - half_z + inset),
		Vector3(len_x, wall_height, wall_thickness))
	_add_wall(walls_root,
		Vector3(center.x + half_x - inset, center.y + wall_height * 0.5, center.z),
		Vector3(wall_thickness, wall_height, len_z))
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


var tiempo := 180


func _on_timer_timeout() -> void:
	tiempo -= 1
	
	var minutos = tiempo / 60
	var segundos = tiempo % 60

	contador_label.text = "%02d:%02d" % [minutos, segundos]

	if tiempo <= 0:
		timer.stop()
		contador_label.text = "00:00"
