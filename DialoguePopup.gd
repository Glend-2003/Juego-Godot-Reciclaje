extends PanelContainer
class_name DialoguePopup
## Popup reutilizable tipo "toast" para GreenUNA.
##
## Estética: letrero de madera (panel café oscuro semitransparente, esquinas
## redondeadas, sombra para dar profundidad) con texto blanco bold y contorno
## oscuro grueso. El borde cambia de color según el tipo de mensaje.
##
## Animación:
##   - Aparición: fade-in + escala con rebote suave (efecto "pop").
##   - Permanece visible ~2 s.
##   - Salida: fade-out + leve encogida, y se autoelimina (queue_free).
##
## No se usa directamente: lo instancia y controla el autoload DialogueManager.

@onready var _label: Label = $Margin/Label

const VIDA := 2.0          # segundos visible antes de desvanecer
const T_APARICION := 0.22  # duración del "pop" de entrada
const T_SALIDA := 0.30     # duración del fade de salida

## Configura el texto y el color del borde, y dispara la animación completa.
## Debe llamarse DESPUÉS de add_child(popup) para que _label ya exista.
func mostrar(texto: String, color_borde: Color) -> void:
	_label.text = texto

	# Duplicamos el StyleBox del panel para que cada popup tenga su propio color
	# de borde sin alterar a los demás (los StyleBox se comparten por defecto).
	var sb: StyleBoxFlat = get_theme_stylebox("panel").duplicate()
	sb.border_color = color_borde
	add_theme_stylebox_override("panel", sb)

	# Estado inicial: invisible y encogido, listo para el "pop".
	modulate.a = 0.0
	scale = Vector2(0.6, 0.6)

	# Esperamos un frame para que el contenedor calcule el tamaño real; así el
	# pivote queda en el centro y la escala no "salta" desde la esquina.
	await get_tree().process_frame
	pivot_offset = size * 0.5

	var tw := create_tween()
	# Aparición: fade-in en paralelo con la escala (rebote hacia afuera).
	tw.tween_property(self, "modulate:a", 1.0, T_APARICION)
	tw.parallel().tween_property(self, "scale", Vector2.ONE, T_APARICION) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Permanece visible.
	tw.tween_interval(VIDA)
	# Salida: fade-out + leve encogida.
	tw.tween_property(self, "modulate:a", 0.0, T_SALIDA)
	tw.parallel().tween_property(self, "scale", Vector2(0.85, 0.85), T_SALIDA) \
		.set_ease(Tween.EASE_IN)
	# Una vez terminado, el toast se elimina solo.
	tw.tween_callback(queue_free)
