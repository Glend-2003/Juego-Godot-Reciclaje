extends Node
## Autoload (singleton) que gestiona los diálogos tipo "toast" de GreenUNA.
##
## Responsabilidades:
##   - Guardar TODAS las frases agrupadas por categoría.
##   - Mostrar UNA sola frase al azar por evento, evitando repetir la frase
##     que salió la vez inmediatamente anterior dentro de la misma categoría.
##   - Crear y mantener su propia capa visual (CanvasLayer) para que los toasts
##     aparezcan por encima de cualquier escena y sobrevivan a los cambios de
##     escena (al ser autoload).
##
## Uso desde cualquier parte del juego:
##     DialogueManager.show_dialogue("correcto", "good")
##     DialogueManager.show_dialogue("error", "bad")
##     DialogueManager.show_text("Acércate a un basurero", "neutral")
##
## El parámetro "tipo" cambia el color del acento (borde) del popup:
##     "good"    -> verde   (acierto)
##     "bad"     -> rojo    (error)
##     "neutral" -> café madera (informativo)

# Escena reutilizable del popup. Se instancia una vez por cada toast.
const PopupScene := preload("res://DialoguePopup.tscn")

# --- Paleta de acento (identidad visual GreenUNA) ---------------------------
const COLOR_GOOD := Color("7CB342")     # verde brillante
const COLOR_BAD := Color("C0392B")      # rojo de acento
const COLOR_NEUTRAL := Color("8B5A2B")  # café madera

# --- Frases por categoría ---------------------------------------------------
# Cada clave es una categoría; el valor es la lista de frases posibles.
var _frases := {
	# Basura BIEN colocada.
	"correcto": [
		"¡Eso mae! Va para donde tiene que ir.",
		"¡Buen brete! Un punto más para el planeta.",
		"¡Así se hace! Basura en su chante.",
		"¡Qué nivel! Esa sí la pegó.",
		"¡Pura vida! Reciclaje bien hecho.",
		"¡Excelente, mae! La naturaleza se lo agradece.",
		"¡De una! Esa quedó donde corresponde.",
		"¡Tuanis! Menos contaminación, más conciencia.",
		"¡Siga así! Va salvando el ambiente.",
		"¡Buen ojo! Clasificación perfecta.",
	],
	# Basura MAL colocada (genérico).
	"incorrecto": [
		"¡Mae, no sea caballo! Ese no era el basurero.",
		"¡Ay no! Así no se recicla.",
		"¡Qué torta! Revise bien antes de tirar.",
		"¡Mae, póngale atención! Va en otro recipiente.",
		"¡Uy! El planeta acaba de perder puntos.",
		"¡No joda! Esa basura no va ahí.",
		"¡Qué madre! Inténtelo otra vez.",
		"¡Mae, se embarcó! Ese no era.",
		"¡Así no promete! Busque el basurero correcto.",
		"¡Fijo estaba distraído! Pruebe de nuevo.",
	],
	# Al empezar el juego.
	"inicio": [
		"¡Mae, aliste esas manos! El planeta ocupa ayuda.",
		"¡Bienvenido! Demuestre que sabe reciclar como un campeón.",
		"¡Vamos con todo! El ambiente está en sus manos.",
		"¡Arrancamos! Clasifique rápido y con cuidado.",
		"¡Póngase vivo! El tiempo corre.",
		"¡Listo mae! A recoger ese reguero.",
		"¡Que no se le vaya ninguna! Empieza la misión ecológica.",
		"¡A darle! Cada basura cuenta.",
		"¡Llegó la hora! Veamos cuánto sabe de reciclaje.",
		"¡Ojo al tiempo! Entre más rápido, mejor puntaje.",
	],
	# Al terminar el juego.
	"final": [
		"¡Se acabó, mae! Hora de revisar esos puntos.",
		"¡Fin del juego! Gracias por ayudar al planeta.",
		"¡Buen brete! Cada basura bien puesta hace la diferencia.",
		"¡Listo! El ambiente le da las gracias.",
		"¡Se acabó el tiempo! ¿Logró salvar suficiente basura?",
		"¡Misión cumplida! Ahora vea su resultado.",
		"¡Qué nivel! Ojalá recicle así en la vida real.",
		"¡Juego terminado! El planeta espera verlo de nuevo.",
		"¡Hasta aquí llegamos! Recuerde: reciclar no es solo un juego.",
	],
	# 5 aciertos seguidos.
	"combo5": [
		"¡Mae, está on fire!",
		"¡Qué máquina para reciclar!",
		"¡Así sí promete!",
	],
	# 10 aciertos seguidos.
	"combo10": [
		"¡Ya casi lo contratan en la muni!",
		"¡Reciclador profesional desbloqueado!",
		"¡El planeta le está haciendo barra!",
	],
	# 3 errores seguidos.
	"fallos3": [
		"¡Mae, ¿anda dormido o qué?",
		"¡Revise los colores, compa!",
		"¡Así nos llenamos de basura, vea!",
	],
	# Botó en el basurero equivocado.
	"error": [
		"¡Mae, qué bruto! Esa no iba ahí.",
		"¡No sea tan bestia! Revise bien.",
		"¡Legalmente se la jugó y perdió!",
		"¡Mae, ¿qué vio? Porque el color no.",
		"¡Qué bañazo acaba de pegar!",
		"¡Ni copiando la respuesta la pega así!",
		"¡Mae, está mamando durísimo!",
		"¡Con razón hacen falta más cursos de reciclaje!",
		"¡Qué clase de invento fue ese!",
		"¡Hasta el basurero está confundido!",
	],
}

# Recuerda el índice de la última frase mostrada por categoría, para no
# repetir la misma dos veces seguidas.
var _ultimo_indice := {}

# Capa visual propia y contenedor donde se apilan los toasts.
var _capa: CanvasLayer
var _contenedor: VBoxContainer

func _ready() -> void:
	# Construimos la capa una sola vez. Al ser hija del autoload, persiste entre
	# escenas y siempre dibuja por encima del juego.
	_capa = CanvasLayer.new()
	_capa.layer = 128                       # bien arriba de todo el HUD
	add_child(_capa)

	# Contenedor anclado al centro-superior de la pantalla. Ancho cero + anclas
	# en 0.5 con crecimiento a ambos lados => se centra horizontalmente y se
	# ajusta al tamaño de los toasts.
	_contenedor = VBoxContainer.new()
	_contenedor.name = "Toasts"
	_contenedor.alignment = BoxContainer.ALIGNMENT_CENTER
	_contenedor.add_theme_constant_override("separation", 10)
	_contenedor.anchor_left = 0.5
	_contenedor.anchor_right = 0.5
	_contenedor.anchor_top = 0.0
	_contenedor.anchor_bottom = 0.0
	_contenedor.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_contenedor.grow_vertical = Control.GROW_DIRECTION_END
	_contenedor.offset_top = 80              # margen desde el borde superior
	_contenedor.mouse_filter = Control.MOUSE_FILTER_IGNORE  # no bloquea el juego
	_capa.add_child(_contenedor)

# --- API pública ------------------------------------------------------------

## Muestra UNA frase aleatoria de la categoría indicada.
## tipo: "good" (verde), "bad" (rojo) o "neutral" (café).
func show_dialogue(categoria: String, tipo: String = "neutral") -> void:
	var texto := _frase_aleatoria(categoria)
	if texto == "":
		return
	_mostrar_toast(texto, _color_por_tipo(tipo))

## Muestra un texto literal (útil para mensajes puntuales que no son una
## categoría, p. ej. "Acércate a un basurero").
func show_text(texto: String, tipo: String = "neutral") -> void:
	if texto.strip_edges() == "":
		return
	_mostrar_toast(texto, _color_por_tipo(tipo))

# --- Interno ----------------------------------------------------------------

## Elige una frase al azar de la categoría, distinta a la última mostrada.
func _frase_aleatoria(categoria: String) -> String:
	var lista: Array = _frases.get(categoria, [])
	if lista.is_empty():
		push_warning("DialogueManager: categoría desconocida '%s'" % categoria)
		return ""
	if lista.size() == 1:
		return lista[0]

	var ultimo: int = _ultimo_indice.get(categoria, -1)
	var idx := randi() % lista.size()
	# Si cae en la misma de la vez anterior, volvemos a tirar el dado.
	while idx == ultimo:
		idx = randi() % lista.size()
	_ultimo_indice[categoria] = idx
	return lista[idx]

## Traduce el "tipo" al color de acento del borde.
func _color_por_tipo(tipo: String) -> Color:
	match tipo:
		"good":
			return COLOR_GOOD
		"bad":
			return COLOR_BAD
		_:
			return COLOR_NEUTRAL

## Instancia un popup, lo agrega al contenedor y lo anima.
func _mostrar_toast(texto: String, color_borde: Color) -> void:
	var popup := PopupScene.instantiate()
	# add_child dispara _ready() del popup de forma síncrona, así que sus
	# @onready ya están listos cuando llamamos a mostrar().
	_contenedor.add_child(popup)
	popup.mostrar(texto, color_borde)
