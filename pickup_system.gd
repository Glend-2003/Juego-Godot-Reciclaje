extends Node3D
class_name PickupSystem
# Recogida manual de basura. Hijo del Player.
# El jugador carga una basura a la vez: F recoge, G cambia/deposita.

@export var radio_interaccion: float = 1.2
@export var altura_indicador: float = 2.2
@export var escala_indicador: float = 0.5
@export var vel_rotacion: float = 1.5

var _area: Area3D
var _punto_sujecion: Node3D
var _indicador: Node3D
var _indicador_base_y: float = 0.0
var _t: float = 0.0

# HUD
var _hud_tarjeta: PanelContainer
var _hud_contenedor: SubViewportContainer
var _hud_viewport: SubViewport
var _hud_soporte: Node3D
var _hud_etiqueta: Label
var _hud_hint: Label
var _monedas: int = 0

# Rachas para los diálogos de combo/fallos.
var _aciertos_seguidos: int = 0
var _fallos_seguidos: int = 0

signal monedas_cambiaron(total: int, delta: int)
# Se emite al depositar una basura. 'correcta' = al basurero adecuado.
signal basura_clasificada(correcta: bool)

# Nodo donde reaparece la basura si el jugador la suelta. Lo asigna main.gd.
var _respawn_parent: Node = null

var _btn_pickup: Button
var _btn_switch: Button
var _btn_deposit: Button

# Basuras cercanas y selección actual.
var _cercanos: Array[TrashItem] = []
var _seleccion: int = 0

# Basureros cercanos.
var _bins_cercanos: Array[Area3D] = []

# Lo que carga el jugador (-1 = nada).
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
	var modelo: Node3D = get_parent().get_node_or_null("Model")
	if modelo:
		modelo.add_child(_punto_sujecion)
	else:
		add_child(_punto_sujecion)

func _crear_area_interaccion() -> void:
	_area = Area3D.new()
	_area.name = "AreaInteraccion"
	_area.collision_layer = 0
	# 2 = capa de basura, 4 = capa de basureros.
	_area.collision_mask = 2 | 4
	_area.monitoring = true
	_area.monitorable = false
	var col := CollisionShape3D.new()
	var forma := SphereShape3D.new()
	forma.radius = radio_interaccion
	col.shape = forma
	col.position = Vector3(0, 1.0, 0)
	_area.add_child(col)
	add_child(_area)
	_area.area_entered.connect(_on_area_entered)
	_area.area_exited.connect(_on_area_exited)

# --- HUD --------------------------------------------------------------------

func _construir_hud() -> void:
	var capa := CanvasLayer.new()
	add_child(capa)

	# Tarjeta "Llevas:" en la esquina inferior izquierda.
	_hud_tarjeta = PanelContainer.new()
	_hud_tarjeta.anchor_left = 0.0
	_hud_tarjeta.anchor_top = 1.0
	_hud_tarjeta.anchor_bottom = 1.0
	_hud_tarjeta.offset_left = 28
	_hud_tarjeta.offset_top = -212
	_hud_tarjeta.offset_bottom = -20
	_hud_tarjeta.visible = false
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0, 0, 0, 0.45)
	estilo.set_corner_radius_all(12)
	estilo.set_content_margin_all(10)
	_hud_tarjeta.add_theme_stylebox_override("panel", estilo)
	capa.add_child(_hud_tarjeta)

	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 4)
	caja.alignment = BoxContainer.ALIGNMENT_CENTER
	_hud_tarjeta.add_child(caja)

	_hud_etiqueta = Label.new()
	_hud_etiqueta.text = "Llevas:"
	_hud_etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_etiqueta.add_theme_color_override("font_color", Color(1, 1, 1))
	_hud_etiqueta.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_hud_etiqueta.add_theme_constant_override("outline_size", 4)
	caja.add_child(_hud_etiqueta)

	_hud_contenedor = SubViewportContainer.new()
	_hud_contenedor.stretch = true
	_hud_contenedor.custom_minimum_size = Vector2(150, 150)
	_hud_contenedor.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	caja.add_child(_hud_contenedor)

	_hud_viewport = SubViewport.new()
	_hud_viewport.transparent_bg = true
	_hud_viewport.own_world_3d = true
	_hud_viewport.size = Vector2i(150, 150)
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

	# Hint contextual abajo-centro ("F: Recoger", etc.). Se oculta sin texto.
	_hud_hint = Label.new()
	_hud_hint.text = ""
	_hud_hint.anchor_left = 0.0
	_hud_hint.anchor_right = 1.0
	_hud_hint.anchor_top = 1.0
	_hud_hint.anchor_bottom = 1.0
	_hud_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hud_hint.offset_top = -100
	_hud_hint.offset_bottom = -74
	_hud_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hud_hint.add_theme_font_size_override("font_size", 14)
	_hud_hint.add_theme_color_override("font_color", Color(1, 1, 1))
	_hud_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_hud_hint.add_theme_constant_override("outline_size", 2)
	_hud_hint.visible = false
	_hud_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa.add_child(_hud_hint)

	# Botones táctiles solo en móvil.
	if OS.has_feature("mobile") or DisplayServer.is_touchscreen_available():
		_btn_pickup = _crear_boton_movil("Recoger", Vector2(0, -220))
		_btn_pickup.pressed.connect(_intentar_recoger)
		capa.add_child(_btn_pickup)

		_btn_switch = _crear_boton_movil("Cambiar", Vector2(0, -110))
		_btn_switch.pressed.connect(_ciclar_seleccion)
		capa.add_child(_btn_switch)

		_btn_deposit = _crear_boton_movil("Depositar", Vector2(0, -110))
		_btn_deposit.pressed.connect(_intentar_depositar)
		capa.add_child(_btn_deposit)

		for b in [_btn_pickup, _btn_switch, _btn_deposit]:
			b.anchor_left = 1.0
			b.anchor_right = 1.0
			b.anchor_top = 1.0
			b.anchor_bottom = 1.0
			b.offset_left = -200
			b.offset_top = b.position.y - 100
			b.offset_right = -40
			b.offset_bottom = b.position.y

func _crear_boton_movil(texto: String, pos: Vector2) -> Button:
	var b := Button.new()
	b.text = texto
	b.position = pos
	b.custom_minimum_size = Vector2(160, 90)
	b.add_theme_font_size_override("font_size", 28)
	b.visible = false
	return b

# --- Bucle ------------------------------------------------------------------

func _process(delta: float) -> void:
	_t += delta

	# Limpiar referencias muertas.
	for i in range(_cercanos.size() - 1, -1, -1):
		if not is_instance_valid(_cercanos[i]):
			_cercanos.remove_at(i)
	if _seleccion >= _cercanos.size():
		_seleccion = 0

	# Indicador flotante sobre el jugador.
	if _indicador:
		_indicador.rotate_y(vel_rotacion * delta)
		_indicador.position.y = _indicador_base_y + sin(_t * 2.0) * 0.07
	if _hud_soporte and _cargando():
		_hud_soporte.rotate_y(delta * 1.0)

	_actualizar_hint()


func _actualizar_hint() -> void:
	if _hud_hint == null:
		return
	if _cargando():
		if not _bins_cercanos.is_empty():
			_hud_hint.text = "G: Depositar en " + _nombre_categoria(_bin_mas_cercano().get("categoria"))
		else:
			_hud_hint.text = ""
	elif _cercanos.size() > 1:
		_hud_hint.text = "F: Recoger     G: Cambiar (%d)" % _cercanos.size()
	elif _cercanos.size() == 1:
		_hud_hint.text = "F: Recoger"
	else:
		_hud_hint.text = ""

	_hud_hint.visible = _hud_hint.text != ""

	if _btn_pickup:
		_btn_pickup.visible = (not _cargando()) and (not _cercanos.is_empty())
	if _btn_switch:
		_btn_switch.visible = (not _cargando()) and _cercanos.size() > 1
	if _btn_deposit:
		_btn_deposit.visible = _cargando() and not _bins_cercanos.is_empty()

func _nombre_categoria(t) -> String:
	if t == null:
		return ""
	return Categorias.nombre(int(t))

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pickup"):
		_intentar_recoger()
	elif event.is_action_pressed("switch_trash"):
		# G: si lleva algo deposita; si no, cicla la selección.
		if _cargando():
			_intentar_depositar()
		else:
			_ciclar_seleccion()
	elif event.is_action_pressed("interact") and _cargando():
		_soltar()

func _cargando() -> bool:
	return _cat_cargada != -1

# --- Detección y selección --------------------------------------------------

func _on_area_entered(area: Area3D) -> void:
	if area is TrashItem and not _cercanos.has(area):
		_cercanos.append(area)
	elif area.is_in_group("basurero") and not _bins_cercanos.has(area):
		_bins_cercanos.append(area)

func _on_area_exited(area: Area3D) -> void:
	if area is TrashItem and _cercanos.has(area):
		var idx := _cercanos.find(area)
		_cercanos.erase(area)
		if _seleccion >= _cercanos.size():
			_seleccion = max(0, _cercanos.size() - 1)
		elif idx < _seleccion and _seleccion > 0:
			_seleccion -= 1
	elif area.is_in_group("basurero") and _bins_cercanos.has(area):
		_bins_cercanos.erase(area)

func _ciclar_seleccion() -> void:
	if _cercanos.is_empty() or _cargando():
		return
	_seleccion = (_seleccion + 1) % _cercanos.size()

# --- Recoger / soltar / depositar -------------------------------------------

func _intentar_recoger() -> void:
	if _cargando() or _cercanos.is_empty():
		return
	var item: TrashItem = _cercanos[_seleccion]
	if not is_instance_valid(item):
		_cercanos.remove_at(_seleccion)
		return
	_recoger(item)

func _recoger(item: TrashItem) -> void:
	_cat_cargada = item.categoria
	_ruta_cargada = item.modelo_path
	var jugador := get_parent()
	if jugador.has_method("reproducir_pickup"):
		jugador.reproducir_pickup()
	_crear_preview_hud(item.modelo_path)
	_cercanos.erase(item)
	if _seleccion >= _cercanos.size():
		_seleccion = 0
	item.queue_free()

func _bin_mas_cercano() -> Area3D:
	if _bins_cercanos.is_empty():
		return null
	var jugador := get_parent() as Node3D
	if jugador == null:
		return _bins_cercanos[0]
	var pos := jugador.global_position
	var mejor: Area3D = _bins_cercanos[0]
	var mejor_d: float = pos.distance_squared_to(mejor.global_position)
	for b in _bins_cercanos:
		var d: float = pos.distance_squared_to(b.global_position)
		if d < mejor_d:
			mejor = b
			mejor_d = d
	return mejor

func _intentar_depositar() -> void:
	if not _cargando():
		DialogueManager.show_text("Primero recogé una basura (F)", "neutral")
		return
	if _bins_cercanos.is_empty():
		DialogueManager.show_text("Acércate a un basurero", "neutral")
		return

	var bin: Area3D = _bin_mas_cercano()
	var cat_bin: int = int(bin.get("categoria"))
	var acepta_todo: bool = bool(bin.get("acepta_todo"))

	if acepta_todo or cat_bin == _cat_cargada:
		# Acierto.
		basura_clasificada.emit(true)
		_sumar_monedas(1)
		_aciertos_seguidos += 1
		_fallos_seguidos = 0
		if _aciertos_seguidos % 10 == 0:
			DialogueManager.show_dialogue("combo10", "good")
		elif _aciertos_seguidos % 5 == 0:
			DialogueManager.show_dialogue("combo5", "good")
		else:
			DialogueManager.show_dialogue("correcto", "good")
		_cat_cargada = -1
		_ruta_cargada = ""
		_limpiar_indicador()
		_limpiar_preview_hud()
	else:
		# Error: la basura NO se deposita, se sigue cargando. Cuesta una vida (main.gd).
		basura_clasificada.emit(false)
		_fallos_seguidos += 1
		_aciertos_seguidos = 0
		if _fallos_seguidos % 3 == 0:
			DialogueManager.show_dialogue("fallos3", "bad")
		else:
			DialogueManager.show_dialogue("error", "bad")

func _sumar_monedas(delta: int) -> void:
	_monedas = max(0, _monedas + delta)
	monedas_cambiaron.emit(_monedas, delta)

func get_monedas() -> int:
	return _monedas

func _soltar() -> void:
	# Devuelve la basura al mundo para que siga siendo recolectable.
	if _cat_cargada != -1 and _ruta_cargada != "" and is_instance_valid(_respawn_parent):
		var item := TrashItem.crear(_cat_cargada, _ruta_cargada)
		_respawn_parent.add_child(item)
		var jugador := get_parent() as Node3D
		if jugador:
			var p := jugador.global_position
			item.global_position = Vector3(p.x, 1.75, p.z)
	_cat_cargada = -1
	_ruta_cargada = ""
	_limpiar_indicador()
	_limpiar_preview_hud()

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
	var aabb := Util3D.aabb_mundo(_indicador)
	var mayor: float = max(aabb.size.x, max(aabb.size.y, aabb.size.z))
	var f: float = (escala_indicador / mayor) if mayor > 0.0 else 1.0
	var centro := aabb.position + aabb.size * 0.5
	var base := _punto_sujecion.global_position
	_indicador.scale = Vector3(f, f, f)
	_indicador.position = -(centro - base) * f
	_indicador_base_y = _indicador.position.y

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
	m.position = -centro * f
	if _hud_tarjeta:
		_hud_tarjeta.visible = true

func _limpiar_indicador() -> void:
	if _indicador:
		_indicador.queue_free()
		_indicador = null

func _limpiar_preview_hud() -> void:
	if _hud_soporte:
		for c in _hud_soporte.get_children():
			c.queue_free()
	if _hud_tarjeta:
		_hud_tarjeta.visible = false
