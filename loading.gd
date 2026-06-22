extends Control
# Pantalla de carga: arma el mundo detrás de la imagen y lo revela cuando está listo.

const ESCENA_MUNDO := "res://main.tscn"
const IMAGEN_CARGA := "res://Game 3D/Pantalla de carga Amigos.jpeg"

# Tiempo mínimo en pantalla para que no parpadee.
const TIEMPO_MINIMO := 1.2

var _capa: CanvasLayer
var _overlay: Control          # imagen + letrero; esto se desvanece
var _label_carga: Label
var _t: float = 0.0
var _t_total: float = 0.0
var _instanciado: bool = false
var _revelando: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_construir_ui()
	# Etapa 1: carga de recursos en segundo plano.
	ResourceLoader.load_threaded_request(ESCENA_MUNDO, "", true)

func _construir_ui() -> void:
	# Capa por encima de todo (incluido el HUD del juego que se irá armando atrás).
	_capa = CanvasLayer.new()
	_capa.layer = 200
	add_child(_capa)

	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_capa.add_child(_overlay)

	# Ilustración de carga estirada a toda la pantalla.
	var fondo := TextureRect.new()
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fondo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fondo.stretch_mode = TextureRect.STRETCH_SCALE
	fondo.texture = load(IMAGEN_CARGA)
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(fondo)

	# Letrero "Cargando..." abajo-centro, estilo madera.
	var tarjeta := PanelContainer.new()
	tarjeta.anchor_left = 0.5
	tarjeta.anchor_right = 0.5
	tarjeta.anchor_top = 1.0
	tarjeta.anchor_bottom = 1.0
	tarjeta.grow_horizontal = Control.GROW_DIRECTION_BOTH
	tarjeta.grow_vertical = Control.GROW_DIRECTION_BEGIN
	tarjeta.offset_bottom = -80
	tarjeta.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.16, 0.11, 0.07, 0.85)
	estilo.set_corner_radius_all(14)
	estilo.set_content_margin_all(10)
	estilo.content_margin_left = 22
	estilo.content_margin_right = 22
	estilo.set_border_width_all(2)
	estilo.border_color = Color("7CB342")
	estilo.shadow_color = Color(0, 0, 0, 0.4)
	estilo.shadow_size = 5
	estilo.shadow_offset = Vector2(0, 3)
	tarjeta.add_theme_stylebox_override("panel", estilo)
	_overlay.add_child(tarjeta)

	_label_carga = Label.new()
	_label_carga.add_theme_color_override("font_color", Color(1, 1, 1))
	_label_carga.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_label_carga.add_theme_constant_override("outline_size", 5)
	_label_carga.add_theme_font_size_override("font_size", 22)
	_label_carga.text = "Cargando."
	_label_carga.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tarjeta.add_child(_label_carga)

func _process(delta: float) -> void:
	_t_total += delta

	# Puntos animados mientras la pantalla siga visible.
	if not _revelando and _label_carga:
		_t += delta
		var n := 1 + (int(_t / 0.35) % 3)
		_label_carga.text = "Cargando" + ".".repeat(n)

	if _instanciado:
		return

	# Estado de la carga de recursos.
	var progreso: Array = []
	var estado := ResourceLoader.load_threaded_get_status(ESCENA_MUNDO, progreso)
	match estado:
		ResourceLoader.THREAD_LOAD_LOADED:
			if _t_total >= TIEMPO_MINIMO:
				_instanciar_mundo()
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			push_error("[Loading] No se pudo cargar el mundo: " + ESCENA_MUNDO)
			_instanciado = true
			get_tree().change_scene_to_file(ESCENA_MUNDO)

# Etapa 2: instancia el mundo bajo la imagen y espera a que avise que está listo.
func _instanciar_mundo() -> void:
	_instanciado = true
	var packed: PackedScene = ResourceLoader.load_threaded_get(ESCENA_MUNDO)
	var mundo: Node = packed.instantiate()
	if mundo.has_signal("mundo_listo"):
		mundo.connect("mundo_listo", _on_mundo_listo, CONNECT_ONE_SHOT)
	else:
		# Si el mundo no emite la señal, revelamos tras un frame.
		_on_mundo_listo.call_deferred()
	add_child(mundo)

func _on_mundo_listo() -> void:
	if _revelando:
		return
	_revelando = true
	# Desvanecer la imagen para revelar el juego ya armado.
	var tw := create_tween()
	tw.tween_property(_overlay, "modulate:a", 0.0, 0.4)
	tw.tween_callback(_capa.queue_free)
