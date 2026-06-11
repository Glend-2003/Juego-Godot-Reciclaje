extends Node3D
class_name PickupSystem
# Sistema de recogida de basura. Vive como hijo del Player.
#
# Reglas:
#   - El jugador puede cargar UNA sola basura a la vez.
#   - La recogida es AUTOMÁTICA al tocar la basura: esa basura desaparece del
#     mundo y pasa a manos del jugador. Las demás quedan intactas.
#   - Al recoger se reproduce la animación "Pickup" del personaje.
#   - La basura cargada se muestra de dos formas:
#       a) flotando sobre el personaje (sigue su orientación, con giro y rebote).
#       b) como un preview pequeño en una sección de la pantalla (HUD).
#   - Con la tecla "interact" (E) el jugador suelta la basura cargada.
#     TODO: cuando vuelvan los basureros, aquí va el depósito + el puntaje.
#
# Construye en código su Area3D de detección, el punto de sujeción y el HUD,
# así el player.tscn solo necesita este nodo.

@export var radio_interaccion: float = 1.6   # alcance para recoger (tocar)
@export var altura_indicador: float = 2.2    # altura del indicador sobre los pies
@export var escala_indicador: float = 0.5    # dimensión mayor del indicador (m)
@export var vel_rotacion: float = 1.5        # giro del indicador (rad/s)

var _area: Area3D              # detecta basura cercana
var _punto_sujecion: Node3D    # sobre la cabeza (sigue al modelo del personaje)
var _indicador: Node3D         # copia 3D de lo que carga
var _indicador_base_y: float = 0.0
var _t: float = 0.0            # acumulador de tiempo para el rebote

# HUD (preview en pantalla)
var _hud_contenedor: SubViewportContainer
var _hud_viewport: SubViewport
var _hud_soporte: Node3D
var _hud_etiqueta: Label

# Estado de lo que carga el jugador (-1 = nada).
var _cat_cargada: int = -1
var _ruta_cargada: String = ""

func _ready() -> void:
	_crear_punto_sujecion()
	_crear_area_interaccion()
	_construir_hud()

func _crear_punto_sujecion() -> void:
	_punto_sujecion = Node3D.new()
	_punto_sujecion.name = "PuntoSujecion"
	_punto_sujecion.position = Vector3(0, altura_indicador, 0)
	# Se cuelga del modelo del personaje para que la basura acompañe su giro.
	var modelo: Node3D = get_parent().get_node_or_null("Model")
	if modelo:
		modelo.add_child(_punto_sujecion)
	else:
		add_child(_punto_sujecion)

func _crear_area_interaccion() -> void:
	_area = Area3D.new()
	_area.name = "AreaInteraccion"
	_area.collision_layer = 0
	_area.collision_mask = 2     # detecta basura (capa 2)
	_area.monitoring = true
	_area.monitorable = false
	var col := CollisionShape3D.new()
	var forma := SphereShape3D.new()
	forma.radius = radio_interaccion
	col.shape = forma
	col.position = Vector3(0, 1.0, 0)  # centrado a la altura del torso
	_area.add_child(col)
	add_child(_area)
	_area.area_entered.connect(_on_area_entered)

# --- HUD: preview 3D pequeño en una esquina de la pantalla ------------------

func _construir_hud() -> void:
	var capa := CanvasLayer.new()
	add_child(capa)

	_hud_etiqueta = Label.new()
	_hud_etiqueta.text = "Llevas:"
	_hud_etiqueta.position = Vector2(28, 392)
	_hud_etiqueta.visible = false
	capa.add_child(_hud_etiqueta)

	_hud_contenedor = SubViewportContainer.new()
	_hud_contenedor.stretch = true
	_hud_contenedor.position = Vector2(28, 420)
	_hud_contenedor.custom_minimum_size = Vector2(180, 180)
	_hud_contenedor.size = Vector2(180, 180)
	_hud_contenedor.visible = false
	capa.add_child(_hud_contenedor)

	_hud_viewport = SubViewport.new()
	_hud_viewport.transparent_bg = true
	_hud_viewport.own_world_3d = true            # mundo aislado para el preview
	_hud_viewport.size = Vector2i(180, 180)
	_hud_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_hud_contenedor.add_child(_hud_viewport)

	var cam := Camera3D.new()
	cam.position = Vector3(0, 0, 2.4)
	cam.current = true
	_hud_viewport.add_child(cam)

	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-35, -35, 0)
	_hud_viewport.add_child(luz)

	_hud_soporte = Node3D.new()
	_hud_viewport.add_child(_hud_soporte)

# --- Bucle -----------------------------------------------------------------

func _process(delta: float) -> void:
	_t += delta
	if _indicador:
		_indicador.rotate_y(vel_rotacion * delta)
		# rebote vertical suave
		_indicador.position.y = _indicador_base_y + sin(_t * 2.0) * 0.07
	if _hud_soporte and _cargando():
		_hud_soporte.rotate_y(delta * 1.0)

func _unhandled_input(event: InputEvent) -> void:
	# Soltar lo que se lleva (provisional hasta que existan los basureros).
	if event.is_action_pressed("interact") and _cargando():
		_soltar()

func _cargando() -> bool:
	return _cat_cargada != -1

# --- Recoger (automático al tocar) -----------------------------------------

func _on_area_entered(area: Area3D) -> void:
	if _cargando():
		return
	if area is TrashItem:
		_recoger(area)

func _recoger(item: TrashItem) -> void:
	_cat_cargada = item.categoria
	_ruta_cargada = item.modelo_path
	# Animación de agarrar del personaje.
	var jugador := get_parent()
	if jugador.has_method("reproducir_pickup"):
		jugador.reproducir_pickup()
	_crear_indicador(item.modelo_path)
	_crear_preview_hud(item.modelo_path)
	# La basura sale del mundo (ahora la lleva el jugador). Las demás siguen.
	item.queue_free()

# --- Indicador 3D sobre el personaje ---------------------------------------

func _crear_indicador(ruta: String) -> void:
	_limpiar_indicador()
	if ruta == "":
		return
	var escena: PackedScene = load(ruta)
	if escena == null:
		return
	_indicador = escena.instantiate()
	_punto_sujecion.add_child(_indicador)
	await get_tree().process_frame
	# Escalar a un tamaño consistente y centrar sobre el punto de sujeción.
	var aabb := Util3D.aabb_mundo(_indicador)
	var mayor: float = max(aabb.size.x, max(aabb.size.y, aabb.size.z))
	var f: float = (escala_indicador / mayor) if mayor > 0.0 else 1.0
	var centro := aabb.position + aabb.size * 0.5
	var base := _punto_sujecion.global_position
	_indicador.scale = Vector3(f, f, f)
	_indicador.position = -(centro - base) * f
	_indicador_base_y = _indicador.position.y

# --- Preview del HUD --------------------------------------------------------

func _crear_preview_hud(ruta: String) -> void:
	_limpiar_preview_hud()
	if ruta == "":
		return
	var escena: PackedScene = load(ruta)
	if escena == null:
		return
	var m: Node3D = escena.instantiate()
	_hud_soporte.add_child(m)
	await get_tree().process_frame
	var aabb := Util3D.aabb_mundo(m)
	var mayor: float = max(aabb.size.x, max(aabb.size.y, aabb.size.z))
	var f: float = (1.4 / mayor) if mayor > 0.0 else 1.0
	var centro := aabb.position + aabb.size * 0.5
	m.scale = Vector3(f, f, f)
	m.position = -centro * f       # centrar en el origen (frente a la cámara)
	_hud_contenedor.visible = true
	_hud_etiqueta.visible = true

# --- Soltar / limpiar -------------------------------------------------------

func _soltar() -> void:
	# TODO PUNTAJE/BASUREROS: aquí, cuando vuelvan los basureros, se hará el
	# depósito (comparar categoría) y se sumará/penalizará el puntaje en el HUD.
	_cat_cargada = -1
	_ruta_cargada = ""
	_limpiar_indicador()
	_limpiar_preview_hud()

func _limpiar_indicador() -> void:
	if _indicador:
		_indicador.queue_free()
		_indicador = null

func _limpiar_preview_hud() -> void:
	if _hud_soporte:
		for c in _hud_soporte.get_children():
			c.queue_free()
	if _hud_contenedor:
		_hud_contenedor.visible = false
	if _hud_etiqueta:
		_hud_etiqueta.visible = false
