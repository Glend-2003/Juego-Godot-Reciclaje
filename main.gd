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
@onready var puntos_label: Label = $CanvasLayer/TextureRect2/Label
@onready var timer: Timer = $Timer
@onready var trash_spawner: TrashSpawner = $TrashSpawner

# Se emite cuando el mundo terminó de construirse por completo (hangar, bosque,
# colisiones, basureros y basura). La pantalla de carga espera esta señal para
# recién entonces revelar el juego, evitando que se vea "armándose".
signal mundo_listo

# Contador de basura restante (panelito en la parte inferior-central).
var _label_basura: Label
var _basura_restante: int = -1

# --- Condiciones de victoria / derrota --------------------------------------
# Victoria: clasificar correctamente TODA la basura antes de que se acabe el
# tiempo. Derrota: que el reloj llegue a 00:00 con basura sin clasificar.
var _total_basura: int = 0        # cuántas basuras hay que clasificar en total
var _clasificadas_ok: int = 0     # cuántas se han depositado correctamente
var _juego_terminado: bool = false

# Vidas del personaje: cada depósito en el basurero equivocado cuesta una vida.
# Al llegar a 0 se pierde la partida.
const VIDAS_MAX := 3
var _vidas: int = VIDAS_MAX
var _label_vidas: Label

# Menú de pausa (ESC): null = cerrado, CanvasLayer = abierto.
var _pausa_capa: CanvasLayer = null

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
	_conectar_contador_monedas()
	_crear_contador_basura()
	_crear_contador_vidas()

	# Las basuras instancian su modelo de forma asíncrona; esperamos unos frames
	# para que ya estén visibles antes de avisar que el mundo está listo.
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	# El mundo está completamente armado: avisamos para que se quite la pantalla
	# de carga y se revele el juego ya listo.
	mundo_listo.emit()

	# Música ambiental en bucle durante toda la partida.
	DialogueManager.iniciar_musica_ambiente()

	# Diálogo de bienvenida (frase aleatoria de la categoría "inicio").
	DialogueManager.show_dialogue("inicio", "neutral")

func _process(_delta: float) -> void:
	_actualizar_contador_basura()

# Panelito tipo letrero de madera (en armonía con los toasts y los banners) que
# muestra cuánta basura queda en el piso. Anclado abajo-centro.
func _crear_contador_basura() -> void:
	var capa: CanvasLayer = $CanvasLayer
	var tarjeta := PanelContainer.new()
	tarjeta.name = "ContadorBasura"
	tarjeta.anchor_left = 0.5
	tarjeta.anchor_right = 0.5
	tarjeta.anchor_top = 1.0
	tarjeta.anchor_bottom = 1.0
	tarjeta.grow_horizontal = Control.GROW_DIRECTION_BOTH
	tarjeta.grow_vertical = Control.GROW_DIRECTION_BEGIN
	tarjeta.offset_bottom = -18
	tarjeta.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.16, 0.11, 0.07, 0.88)   # café oscuro semitransparente
	estilo.set_corner_radius_all(12)
	estilo.set_content_margin_all(8)
	estilo.content_margin_left = 16
	estilo.content_margin_right = 16
	estilo.set_border_width_all(2)
	estilo.border_color = Color("7CB342")             # verde GreenUNA
	estilo.shadow_color = Color(0, 0, 0, 0.4)
	estilo.shadow_size = 4
	estilo.shadow_offset = Vector2(0, 3)
	tarjeta.add_theme_stylebox_override("panel", estilo)
	capa.add_child(tarjeta)

	_label_basura = Label.new()
	_label_basura.add_theme_color_override("font_color", Color(1, 1, 1))
	_label_basura.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_label_basura.add_theme_constant_override("outline_size", 5)
	_label_basura.add_theme_font_size_override("font_size", 18)
	_label_basura.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tarjeta.add_child(_label_basura)
	_actualizar_contador_basura()

# Panelito de vidas (corazones) estilo madera, anclado arriba-izquierda debajo
# del cronómetro.
func _crear_contador_vidas() -> void:
	var capa: CanvasLayer = $CanvasLayer
	var tarjeta := PanelContainer.new()
	tarjeta.name = "ContadorVidas"
	tarjeta.anchor_left = 0.0
	tarjeta.anchor_top = 0.0
	tarjeta.offset_left = 20
	tarjeta.offset_top = 176
	tarjeta.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.16, 0.11, 0.07, 0.88)
	estilo.set_corner_radius_all(12)
	estilo.set_content_margin_all(8)
	estilo.content_margin_left = 16
	estilo.content_margin_right = 16
	estilo.set_border_width_all(2)
	estilo.border_color = Color("C0392B")             # rojo (vidas)
	estilo.shadow_color = Color(0, 0, 0, 0.4)
	estilo.shadow_size = 4
	estilo.shadow_offset = Vector2(0, 3)
	tarjeta.add_theme_stylebox_override("panel", estilo)
	capa.add_child(tarjeta)

	_label_vidas = Label.new()
	_label_vidas.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	_label_vidas.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_label_vidas.add_theme_constant_override("outline_size", 5)
	_label_vidas.add_theme_font_size_override("font_size", 22)
	_label_vidas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tarjeta.add_child(_label_vidas)
	_actualizar_vidas()

# Dibuja las vidas como corazones llenos (♥) y vacíos (♡).
func _actualizar_vidas() -> void:
	if _label_vidas == null:
		return
	var s := ""
	for i in range(VIDAS_MAX):
		s += "♥" if i < _vidas else "♡"
	_label_vidas.text = s

# Refresca el texto solo cuando cambia el número (evita reescribir cada frame).
func _actualizar_contador_basura() -> void:
	if _label_basura == null:
		return
	var n := get_tree().get_nodes_in_group("basura").size()
	if n == _basura_restante:
		return
	_basura_restante = n
	_label_basura.text = "Basura restante: %d" % n

func _conectar_contador_monedas() -> void:
	# Conecta la señal del PickupSystem del jugador al label de puntos del banner.
	var jugador := get_node_or_null("Player")
	if jugador == null or not jugador.has_method("get_pickup_system"):
		return
	var pickup = jugador.get_pickup_system()
	if pickup == null:
		return
	pickup.monedas_cambiaron.connect(_on_monedas_cambiaron)
	if pickup.has_signal("basura_clasificada"):
		pickup.basura_clasificada.connect(_on_basura_clasificada)
	# Para que la basura soltada con E vuelva al piso y siga siendo recolectable.
	pickup.set("_respawn_parent", trash_spawner)
	puntos_label.text = "%d" % pickup.get_monedas()

# Cada vez que el jugador deposita una basura. Si fue correcta, suma a la meta;
# al clasificar TODA la basura, gana.
func _on_basura_clasificada(correcta: bool) -> void:
	if _juego_terminado:
		return
	if correcta:
		_clasificadas_ok += 1
		# Jingle de acierto en cada basura bien clasificada.
		DialogueManager.reproducir_win()
		if _total_basura > 0 and _clasificadas_ok >= _total_basura:
			_terminar_juego(true)
	else:
		# Error de clasificación: cuesta una vida. Sin vidas, se pierde.
		_vidas -= 1
		_actualizar_vidas()
		if _vidas <= 0:
			_terminar_juego(false)

func _on_monedas_cambiaron(total: int, delta: int) -> void:
	puntos_label.text = "%d" % total
	# Pop + tinte momentáneo (verde si suma, rojo si resta).
	var color: Color = Color(0.2, 1.0, 0.3) if delta > 0 else Color(1.0, 0.3, 0.3)
	puntos_label.add_theme_color_override("font_color", color)
	puntos_label.pivot_offset = puntos_label.size * 0.5
	var tw := create_tween()
	tw.tween_property(puntos_label, "scale", Vector2(1.4, 1.4), 0.08)
	tw.tween_property(puntos_label, "scale", Vector2.ONE, 0.18)
	tw.tween_callback(func(): puntos_label.remove_theme_color_override("font_color"))

# Genera colisiones REALES del hangar siguiendo la geometría del mesh.
# Esto crea un StaticBody3D + ConcavePolygonShape3D por cada MeshInstance3D
# dentro del Angar (paredes, columnas, marcos, etc.), de modo que el jugador
# choca exactamente con lo que ve. Es lo más cercano a un "level art = level
# collision" y elimina la necesidad de paredes invisibles aproximadas.
func _generate_hangar_collisions() -> void:
	var count: int = _generar_colisiones_trimesh(angar)
	print("[Hangar] Colisiones trimesh generadas para ", count, " meshes del Angar")

# Recorre todos los MeshInstance3D descendientes de "raiz" y les crea una
# colisión trimesh (StaticBody3D + ConcavePolygonShape3D) que sigue exactamente
# la geometría visible. Devuelve la cantidad de meshes procesados.
func _generar_colisiones_trimesh(raiz: Node) -> int:
	var count: int = 0
	for n in _all_descendants(raiz):
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			var already_has: bool = false
			for c in mi.get_children():
				if c is StaticBody3D:
					already_has = true
					break
			if already_has:
				continue
			mi.create_trimesh_collision()
			count += 1
	return count

const BasureroScript := preload("res://basurero.gd")
const BIN_AZUL := preload("res://basurero-azul.glb")
const BIN_GRIS := preload("res://basurero-gris.glb")
const BIN_VERDE := preload("res://basurero verde.glb")
const BIN_NEGRO := preload("res://basurero-negro.glb")
const CAP_COLLECTION := preload("res://Meshy_AI_Bottle_Cap_Collection_0618014945_texture.glb")

# Desplazamiento de TODA la fila de basureros respecto al centro del hangar.
# Negativo en X = hacia la izquierda del jugador (que entra mirando hacia -Z).
# Ajustá estos dos valores si querés afinar la posición.
const BINS_OFFSET_X := -6.0
const BINS_OFFSET_Z := 0.0

func _spawn_bins_and_caps(angar_aabb: AABB) -> void:
	# Coloca los 3 basureros + la colección de tapas en una línea centrada
	# dentro del hangar para que el jugador los vea al entrar.
	var center_x: float = angar_aabb.position.x + angar_aabb.size.x * 0.5
	var center_z: float = angar_aabb.position.z + angar_aabb.size.z * 0.5
	var y: float = FLOOR_TOP_Y

	var spacing: float = 6.0
	# Orden y categorías según las reglas de reciclaje del juego:
	#   Azul = Plásticos, Gris = Papel y Cartón, Verde = Orgánicos,
	#   Negro = No valorizables, CapCollection = Tapas plásticas exclusivas.
	# Tapas va junto al azul (índice 1) para que quede en la fila visible y a la
	# misma distancia que el resto.
	var items := [
		{"scene": BIN_AZUL,       "scale": 1.5, "name": "BasureroAzul",   "cat": Categorias.Tipo.AZUL,  "any": false},
		{"scene": CAP_COLLECTION, "scale": 1.0, "name": "CapCollection",  "cat": Categorias.Tipo.TAPAS, "any": false},
		{"scene": BIN_GRIS,       "scale": 1.5, "name": "BasureroGris",   "cat": Categorias.Tipo.GRIS,  "any": false},
		{"scene": BIN_VERDE,      "scale": 1.5, "name": "BasureroVerde",  "cat": Categorias.Tipo.VERDE, "any": false},
		{"scene": BIN_NEGRO,      "scale": 1.5, "name": "BasureroNegro",  "cat": Categorias.Tipo.NEGRO, "any": false},
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
		inst.position = Vector3(start_x + float(i) * spacing + BINS_OFFSET_X, y, center_z + BINS_OFFSET_Z)
		# Área de depósito (Basurero) que detecta al jugador.
		var bin: Area3D = BasureroScript.new()
		bin.set("categoria", it["cat"])
		bin.set("acepta_todo", it["any"])
		bin.set("radio", 1.0)
		inst.add_child(bin)
		# Colisión física sobre la geometría del basurero (no se atraviesa).
		_generar_colisiones_trimesh(inst)

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

	# Total de basura a clasificar: es la meta de victoria. Las basuras se añaden
	# de forma síncrona (su _ready las mete al grupo "basura"), así que ya están
	# todas contadas en este punto.
	_total_basura = get_tree().get_nodes_in_group("basura").size()
	print("[Win] Total de basura a clasificar: ", _total_basura)

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


const TIEMPO_INICIAL := 210
var tiempo := TIEMPO_INICIAL


func _on_timer_timeout() -> void:
	if _juego_terminado:
		return
	tiempo -= 1

	var minutos = tiempo / 60
	var segundos = tiempo % 60

	contador_label.text = "%02d:%02d" % [minutos, segundos]

	# Aviso de "queda un minuto" (una sola vez, al cruzar los 60 segundos).
	if tiempo == 60:
		DialogueManager.show_text("¡Queda un minuto!", "bad")
		DialogueManager.reproducir_sfx_evento("unminuto")

	if tiempo <= 0:
		contador_label.text = "00:00"
		# Se acabó el tiempo con basura sin clasificar: derrota.
		_terminar_juego(false)

# --- Fin de partida ---------------------------------------------------------

# Cierra la partida: detiene el reloj, muestra el panel de resultado y pausa el
# juego. 'gano' = true si el jugador clasificó toda la basura a tiempo.
func _terminar_juego(gano: bool) -> void:
	if _juego_terminado:
		return
	_juego_terminado = true
	timer.stop()
	# Termina la partida: se corta la música ambiental.
	DialogueManager.detener_musica_ambiente()
	# El jugador captura el mouse para la cámara; lo liberamos para que el cursor
	# vuelva a verse y se puedan tocar los botones del panel de resultado.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if gano:
		DialogueManager.show_text("¡Clasificaste toda la basura! ¡Ganaste!", "good")
		DialogueManager.reproducir_sfx_evento("ganar")
	else:
		# Jingle de derrota al perder (sin vidas o por tiempo).
		DialogueManager.reproducir_lost()
		# Frase de cierre (categoría "final").
		DialogueManager.show_dialogue("final", "neutral")
	_mostrar_panel_resultado(gano)
	get_tree().paused = true

# Puntos actuales del jugador (0 si no hay PickupSystem).
func _puntos_actuales() -> int:
	var jugador := get_node_or_null("Player")
	if jugador and jugador.has_method("get_pickup_system"):
		var ps = jugador.get_pickup_system()
		if ps:
			return ps.get_monedas()
	return 0

# Umbral de "pocos puntos" para el sonido de derrota floja: un cuarto del total
# de basura (con 20 basuras => 5 puntos o menos cuenta como pocos).
func _umbral_pocos_puntos() -> int:
	return int(_total_basura * 0.25)

# Rutas de las imágenes del resultado y de los botones.
const IMG_WIN := "res://Pantalla de win.png"
const IMG_LOSE := "res://Pantalla de perder.png"
const BTN_RETRY_NORMAL := "res://boton de voolver a intentar sin presionar.png"
const BTN_RETRY_PRESSED := "res://boton de voolver a intentar presionado.png"
const BTN_HOME_NORMAL := "res://BotonSinPresionarHome.png"
const BTN_HOME_PRESSED := "res://BotonPresionadoHome.png"

# Panel de resultado: imagen de ganar/perder a pantalla completa, un resumen
# compacto y los botones Reintentar / Menú. Vive en su propia CanvasLayer en
# modo ALWAYS para seguir respondiendo aunque el árbol esté pausado.
func _mostrar_panel_resultado(gano: bool) -> void:
	var capa := CanvasLayer.new()
	capa.name = "ResultadoLayer"
	capa.layer = 150
	capa.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(capa)

	# Fondo oscuro que tapa el juego de atrás (y rellena las bandas de la imagen).
	var fondo := ColorRect.new()
	fondo.color = Color(0, 0, 0, 0.85)
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	capa.add_child(fondo)

	# Imagen de ganar/perder redimensionada para LLENAR toda la pantalla (se ve
	# completa y ocupa todo el espacio, sin recortes ni bandas).
	var ruta_img := IMG_WIN if gano else IMG_LOSE
	if ResourceLoader.exists(ruta_img):
		var img := TextureRect.new()
		img.texture = load(ruta_img)
		img.set_anchors_preset(Control.PRESET_FULL_RECT)
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_SCALE
		img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		capa.add_child(img)
	else:
		# Respaldo si la imagen todavía no está importada: título de texto.
		var titulo := Label.new()
		if gano:
			titulo.text = "¡GANASTE!"
		elif _vidas <= 0:
			titulo.text = "¡TE QUEDASTE SIN VIDAS!"
		else:
			titulo.text = "¡SE ACABÓ EL TIEMPO!"
		titulo.set_anchors_preset(Control.PRESET_CENTER)
		titulo.add_theme_font_size_override("font_size", 48)
		titulo.add_theme_color_override("font_color", Color("7CB342") if gano else Color("E74C3C"))
		titulo.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		titulo.add_theme_constant_override("outline_size", 6)
		capa.add_child(titulo)

	# Tarjeta destacada con las estadísticas, anclada abajo pero corrida un poco
	# a la derecha (independiente de los botones).
	var tarjeta := _construir_tarjeta_stats(gano)
	tarjeta.anchor_left = 0.5
	tarjeta.anchor_right = 0.5
	tarjeta.anchor_top = 1.0
	tarjeta.anchor_bottom = 1.0
	tarjeta.grow_horizontal = Control.GROW_DIRECTION_BOTH
	tarjeta.grow_vertical = Control.GROW_DIRECTION_BEGIN
	tarjeta.offset_left = 120        # corrida a la derecha
	tarjeta.offset_right = 120
	tarjeta.offset_bottom = -170     # por encima de los botones
	capa.add_child(tarjeta)

	# Botones centrados abajo: Reintentar (acción principal) + Home (volver al menú).
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 28)
	fila.alignment = BoxContainer.ALIGNMENT_CENTER
	fila.anchor_left = 0.5
	fila.anchor_right = 0.5
	fila.anchor_top = 1.0
	fila.anchor_bottom = 1.0
	fila.grow_horizontal = Control.GROW_DIRECTION_BOTH
	fila.grow_vertical = Control.GROW_DIRECTION_BEGIN
	fila.offset_bottom = -45
	capa.add_child(fila)

	fila.add_child(_crear_boton_reintentar())
	fila.add_child(_crear_boton_home())

# Construye la tarjeta de estadísticas finales: panel destacado con buen
# contraste, título, y filas con icono + etiqueta + valor resaltado.
func _construir_tarjeta_stats(gano: bool) -> Control:
	var tarjeta := PanelContainer.new()
	tarjeta.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tarjeta.custom_minimum_size = Vector2(480, 0)

	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.10, 0.14, 0.09, 0.55)      # verde-café oscuro traslúcido
	estilo.set_corner_radius_all(18)
	estilo.set_content_margin_all(22)
	estilo.content_margin_left = 30
	estilo.content_margin_right = 30
	estilo.set_border_width_all(3)
	estilo.border_color = Color("7CB342") if gano else Color("E0A030")
	estilo.shadow_color = Color(0, 0, 0, 0.55)
	estilo.shadow_size = 10
	estilo.shadow_offset = Vector2(0, 4)
	tarjeta.add_theme_stylebox_override("panel", estilo)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	tarjeta.add_child(col)

	# Título de la tarjeta.
	var titulo := Label.new()
	titulo.text = "RESULTADOS DE LA PARTIDA"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 26)
	titulo.add_theme_color_override("font_color", Color("7CB342") if gano else Color("E0A030"))
	titulo.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	titulo.add_theme_constant_override("outline_size", 5)
	col.add_child(titulo)

	# Separador fino bajo el título.
	var sep := HSeparator.new()
	col.add_child(sep)

	# Datos de la partida.
	var t_restante: int = max(tiempo, 0)
	var t_usado: int = max(TIEMPO_INICIAL - t_restante, 0)
	col.add_child(_fila_estadistica("★", "Puntuación final", "%d" % _puntos_actuales(), Color("FFD54F")))
	col.add_child(_fila_estadistica("♻", "Basura recolectada", "%d / %d" % [_clasificadas_ok, _total_basura], Color("7CB342")))
	col.add_child(_fila_estadistica("⌛", "Tiempo empleado", "%02d:%02d" % [t_usado / 60, t_usado % 60], Color("4FC3F7")))
	col.add_child(_fila_estadistica("☆", "Nivel alcanzado", _nivel_desempeno(gano), Color("FFB74D")))
	col.add_child(_fila_estadistica("♥", "Vidas restantes", "%d / %d" % [max(_vidas, 0), VIDAS_MAX], Color("E57373")))
	return tarjeta

# Una fila de la tarjeta de estadísticas: [icono]  etiqueta .......  VALOR.
func _fila_estadistica(icono: String, etiqueta: String, valor: String, color_icono: Color) -> Control:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 14)

	var ic := Label.new()
	ic.text = icono
	ic.custom_minimum_size = Vector2(30, 0)
	ic.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ic.add_theme_font_size_override("font_size", 26)
	ic.add_theme_color_override("font_color", color_icono)
	ic.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	ic.add_theme_constant_override("outline_size", 3)
	fila.add_child(ic)

	var et := Label.new()
	et.text = etiqueta
	et.add_theme_font_size_override("font_size", 20)
	et.add_theme_color_override("font_color", Color(0.88, 0.92, 0.85))
	et.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(et)

	var va := Label.new()
	va.text = valor
	va.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	va.add_theme_font_size_override("font_size", 28)
	va.add_theme_color_override("font_color", Color("FFE082"))   # amarillo destacado
	va.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	va.add_theme_constant_override("outline_size", 3)
	fila.add_child(va)
	return fila

# Calcula un "nivel/desempeño" según el resultado y el porcentaje clasificado.
func _nivel_desempeno(gano: bool) -> String:
	if gano:
		return "Maestro Reciclador"
	var ratio: float = 0.0
	if _total_basura > 0:
		ratio = float(_clasificadas_ok) / float(_total_basura)
	if ratio >= 0.75:
		return "Experto"
	elif ratio >= 0.5:
		return "Bueno"
	elif ratio >= 0.25:
		return "Aprendiz"
	return "Novato"

# Botón "Reintentar" con sus texturas (normal/presionado). Si las imágenes aún
# no están, cae a un botón de texto para no quedarse sin opción de reintentar.
func _crear_boton_reintentar() -> Control:
	if ResourceLoader.exists(BTN_RETRY_NORMAL):
		var b := TextureButton.new()
		b.texture_normal = load(BTN_RETRY_NORMAL)
		if ResourceLoader.exists(BTN_RETRY_PRESSED):
			b.texture_pressed = load(BTN_RETRY_PRESSED)
			b.texture_hover = load(BTN_RETRY_PRESSED)
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		# Acción principal: más grande y destacado.
		b.custom_minimum_size = Vector2(360, 116)
		b.pressed.connect(_on_reintentar)
		return b
	var tb := _crear_boton_resultado("Reintentar")
	tb.pressed.connect(_on_reintentar)
	return tb

# Botón "Home" (volver al menú) con sus texturas normal/presionada. La textura
# presionada se muestra automáticamente al pulsar, simulando la interacción, y al
# soltar el clic se ejecuta el regreso al menú. Si las imágenes no están, cae a
# un botón de texto para no quedarse sin la opción.
func _crear_boton_home() -> Control:
	if ResourceLoader.exists(BTN_HOME_NORMAL):
		var b := TextureButton.new()
		b.texture_normal = load(BTN_HOME_NORMAL)
		if ResourceLoader.exists(BTN_HOME_PRESSED):
			b.texture_pressed = load(BTN_HOME_PRESSED)
			b.texture_hover = load(BTN_HOME_PRESSED)
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		b.custom_minimum_size = Vector2(101, 101)
		b.pressed.connect(_on_volver_menu)
		return b
	var tb := _crear_boton_resultado("Menú")
	tb.pressed.connect(_on_volver_menu)
	return tb

func _crear_boton_resultado(texto: String) -> Button:
	var b := Button.new()
	b.text = texto
	b.custom_minimum_size = Vector2(170, 60)
	b.add_theme_font_size_override("font_size", 24)
	return b

func _on_reintentar() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://loading.tscn")

func _on_volver_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://mainMenu.tscn")

# --- Menú de pausa (ESC) ----------------------------------------------------

# ESC abre/cierra el menú de pausa mientras la partida está en curso. No usamos
# get_tree().paused para no perder el control del propio menú: en su lugar
# congelamos el reloj y deshabilitamos al jugador.
func _unhandled_input(event: InputEvent) -> void:
	if _juego_terminado:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if _pausa_capa == null:
			_abrir_pausa()
		else:
			_cerrar_pausa()
		get_viewport().set_input_as_handled()

func _abrir_pausa() -> void:
	if _pausa_capa != null:
		return
	# Congela el reloj y al jugador, y libera el mouse para tocar los botones.
	timer.paused = true
	var jugador := get_node_or_null("Player")
	if jugador:
		jugador.process_mode = Node.PROCESS_MODE_DISABLED
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_pausa_capa = _construir_menu_pausa()
	add_child(_pausa_capa)

func _cerrar_pausa() -> void:
	if _pausa_capa == null:
		return
	_pausa_capa.queue_free()
	_pausa_capa = null
	timer.paused = false
	var jugador := get_node_or_null("Player")
	if jugador:
		jugador.process_mode = Node.PROCESS_MODE_INHERIT
	# Vuelve a capturar el mouse para la cámara del jugador.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _construir_menu_pausa() -> CanvasLayer:
	var capa := CanvasLayer.new()
	capa.name = "PausaLayer"
	capa.layer = 140
	capa.process_mode = Node.PROCESS_MODE_ALWAYS

	# Fondo oscuro que atenúa el juego de atrás.
	var fondo := ColorRect.new()
	fondo.color = Color(0, 0, 0, 0.5)
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	capa.add_child(fondo)

	# Tarjeta central estilo madera (misma identidad visual del resto del HUD).
	var tarjeta := PanelContainer.new()
	tarjeta.anchor_left = 0.5
	tarjeta.anchor_right = 0.5
	tarjeta.anchor_top = 0.5
	tarjeta.anchor_bottom = 0.5
	tarjeta.grow_horizontal = Control.GROW_DIRECTION_BOTH
	tarjeta.grow_vertical = Control.GROW_DIRECTION_BOTH
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.16, 0.11, 0.07, 0.96)
	estilo.set_corner_radius_all(16)
	estilo.set_content_margin_all(28)
	estilo.set_border_width_all(3)
	estilo.border_color = Color("7CB342")
	estilo.shadow_color = Color(0, 0, 0, 0.5)
	estilo.shadow_size = 8
	tarjeta.add_theme_stylebox_override("panel", estilo)
	capa.add_child(tarjeta)

	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 14)
	caja.alignment = BoxContainer.ALIGNMENT_CENTER
	tarjeta.add_child(caja)

	var titulo := Label.new()
	titulo.text = "PAUSA"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 36)
	titulo.add_theme_color_override("font_color", Color("7CB342"))
	titulo.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	titulo.add_theme_constant_override("outline_size", 6)
	caja.add_child(titulo)

	var btn_reanudar := _crear_boton_resultado("Reanudar")
	btn_reanudar.pressed.connect(_cerrar_pausa)
	caja.add_child(btn_reanudar)

	var btn_retry := _crear_boton_resultado("Reiniciar")
	btn_retry.pressed.connect(_on_reintentar)
	caja.add_child(btn_retry)

	var btn_menu := _crear_boton_resultado("Salir al menú")
	btn_menu.pressed.connect(_on_volver_menu)
	caja.add_child(btn_menu)

	return capa
