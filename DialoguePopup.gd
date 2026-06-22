extends PanelContainer
class_name DialoguePopup
# Popup tipo "toast". Lo controla el autoload DialogueManager.

@onready var _label: Label = $Margin/Label

const VIDA := 2.0
const T_APARICION := 0.22
const T_SALIDA := 0.30

# Llamar DESPUÉS de add_child(popup).
func mostrar(texto: String, color_borde: Color) -> void:
	_label.text = texto

	# StyleBox propio para que cada popup tenga su color de borde.
	var sb: StyleBoxFlat = get_theme_stylebox("panel").duplicate()
	sb.border_color = color_borde
	add_theme_stylebox_override("panel", sb)

	modulate.a = 0.0
	scale = Vector2(0.6, 0.6)

	# Esperar un frame para centrar el pivote sobre el tamaño real.
	await get_tree().process_frame
	pivot_offset = size * 0.5

	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, T_APARICION)
	tw.parallel().tween_property(self, "scale", Vector2.ONE, T_APARICION) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(VIDA)
	tw.tween_property(self, "modulate:a", 0.0, T_SALIDA)
	tw.parallel().tween_property(self, "scale", Vector2(0.85, 0.85), T_SALIDA) \
		.set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)
