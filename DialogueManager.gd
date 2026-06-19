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
# Cada categoría tiene una lista de frases. Cada frase es un diccionario con:
#   "t" = texto que se muestra en el toast.
#   "a" = nombre del archivo de audio en res://audio/ ("" = sin audio).
var _frases := {
	# Basura BIEN colocada (acierto).
	"correcto": [
		{"t": "¡Eso mae! Va para donde tiene que ir.", "a": "eso-mae-va-para-donde-tiene-que-ir.mp3"},
		{"t": "¡Buen brete! Un punto más para el planeta.", "a": "buen-brete-un-punto-mas-para-el-planeta.mp3"},
		{"t": "¡Así se hace! Basura en su chante.", "a": "asi-se-hace-basura-en-su-chante.mp3"},
		{"t": "¡Mae, qué nivel! Esa sí la pegó.", "a": "mae-que-nivel-esa-si-la-pego.mp3"},
		{"t": "¡Pura vida! Reciclaje bien hecho.", "a": "pura-vida-reciclaje-bien-hecho.mp3"},
		{"t": "¡Excelente, mae! La naturaleza se lo agradece.", "a": "excelente-mae-la-naturaleza-se-lo-agradece.mp3"},
		{"t": "¡Siga así! Va salvando el ambiente.", "a": "siga-asi-va-salvando-el-ambiente.mp3"},
	],
	# Basura MAL colocada (error).
	"error": [
		{"t": "¡Mae, qué bruto! Esa no iba ahí.", "a": "mae-que-bruto-esa-no-iba-ahi.mp3"},
		{"t": "¡No sea bestia! Revise bien.", "a": "no-sea-bestia-revise-bien.mp3"},
		{"t": "¡Mae! ¿Qué vio? Porque el color no.", "a": "mae-que-vio-porque-el-color-no.mp3"},
		{"t": "¡Jaja! Qué bañazo acaba de pegar.", "a": "jaja-que-banazo-acaba-de-pegar.mp3"},
		{"t": "¡Hasta el basurero está confundido!", "a": "hasta-el-basurero-esta-confundido.mp3"},
		{"t": "De fijo estaba distraído.", "a": "de-fijo-estaba-distraido.mp3"},
		{"t": "¡Ponga atención! Va en otro recipiente.", "a": "nombres-ponga-atencion-va-en-otro-recipiente.mp3"},
		{"t": "Creo que te faltó ver la película de Wall-E.", "a": "creo-que-te-falto-ver-la-pelicula-de-wall-e.mp3"},
		{"t": "Creo que tendré que llamar a Willy Pineda.", "a": "creo-que-tendre-que-llamar-a-willy-pineda.mp3"},
		{"t": "Estamos igual que la Sele: no logramos clasificar.", "a": "estamos-igual-que-la-sele-no-logramos-clasificar.mp3"},
	],
	# 5 aciertos seguidos (racha buena).
	"combo5": [
		{"t": "¡Crack! Fiera, mastodonte número uno.", "a": "carck-fiera-mastodonte-numero-uno.mp3"},
		{"t": "¡Mae, está intratable!", "a": "mae-esta-intratable.mp3"},
		{"t": "¡Qué monstruo! No falla ninguna.", "a": "que-monstruo-no-falla-ninguna.mp3"},
	],
	# 10 aciertos seguidos (racha buenísima).
	"combo10": [
		{"t": "¡Bien, mae! Se merece beca 10.", "a": "bien-mae-se-merece-beca-10.mp3"},
		{"t": "¡Qué saico! Ya casi lo contrata la muni.", "a": "que-saico-ya-casi-lo-contrata-la-muni.mp3"},
		{"t": "Ya casi le dan una beca en reciclaje.", "a": "ya-casi-le-dan-una-beca-en-reciclaje.mp3"},
	],
	# 3 errores seguidos (racha mala).
	"fallos3": [
		{"t": "¿Está clasificando basura o tirando dados?", "a": "esta-clasificando-basura-o-tirando-dados.mp3"},
		{"t": "Mae, ¿andás trasnochado?", "a": "mae-andas-trasnochado.mp3"},
		{"t": "Mae, legalmente está haciendo un experimento social.", "a": "mae-legalmente-esta-haciendo-un-experimento-social.mp3"},
		{"t": "Mae, ni al propio le sale tan mal.", "a": "mae-ni-al-propio-sale-tan-mal.mp3"},
	],
	# Al empezar el juego (suena el jingle de inicio).
	"inicio": [
		{"t": "¡Mae, aliste esas manos! El planeta ocupa ayuda.", "a": "inicioJuego.mp3"},
		{"t": "¡Bienvenido! Demuestre que sabe reciclar como un campeón.", "a": "inicioJuego.mp3"},
		{"t": "¡Vamos con todo! El ambiente está en sus manos.", "a": "inicioJuego.mp3"},
		{"t": "¡Arrancamos! Clasifique rápido y con cuidado.", "a": "inicioJuego.mp3"},
		{"t": "¡Póngase vivo! El tiempo corre.", "a": "inicioJuego.mp3"},
	],
	# Al terminar el juego (sin audio propio por ahora).
	"final": [
		{"t": "¡Se acabó, mae! Hora de revisar esos puntos.", "a": ""},
		{"t": "¡Fin del juego! Gracias por ayudar al planeta.", "a": ""},
		{"t": "¡Se acabó el tiempo! ¿Logró salvar suficiente basura?", "a": ""},
		{"t": "¡Misión cumplida! Ahora vea su resultado.", "a": ""},
	],
}

# Recuerda el índice de la última frase mostrada por categoría, para no
# repetir la misma dos veces seguidas.
var _ultimo_indice := {}

# Capa visual propia y contenedor donde se apilan los toasts.
var _capa: CanvasLayer
var _contenedor: VBoxContainer

# --- Sonidos --------------------------------------------------------------
# Carpeta donde viven los audios. Cada frase indica su archivo en "a".
const AUDIO_DIR := "res://audio/"

# Música ambiental (suena en bucle durante toda la partida) y jingles de
# desenlace por acierto/derrota. Van en reproductores propios para no cortar
# las frases de voz ni cortarse entre sí.
const MUSICA_AMBIENTE := "res://audio/Ambiente.mp3"
const SFX_WIN := "res://audio/Win.mp3"
const SFX_LOST := "res://audio/Lost.mp3"

# Volumen de la música de fondo: ni muy alta ni muy baja, para que se escuche
# por debajo de las voces y los efectos.
const MUSICA_VOLUMEN_DB := -14.0

# Sonidos de desenlace (no son frases): los dispara main.gd con
# reproducir_sfx_evento(). Si el archivo no existe, simplemente no suena.
const SFX := {
	"ganar":    "res://audio/ganar.mp3",
	"perder":   "res://audio/perder.mp3",
	"final":    "res://audio/final.mp3",
	"unminuto": "res://audio/unminuto.mp3",
	# Derrota con pocos puntos (se elige una al azar).
	"bad":      "res://audio/bad.mp3",
	"bad2":     "res://audio/bad2.mp3",
	"bad3":     "res://audio/bad3.mp3",
}

# Reproductor de efectos (uno solo: cada nuevo sonido reemplaza al anterior).
var _sfx: AudioStreamPlayer
# Reproductor de jingles de acierto/derrota: aparte del de voces para que el
# "Win" pueda sonar junto con la frase de "¡Eso mae!".
var _jingle: AudioStreamPlayer
# Reproductor exclusivo de la música ambiental en bucle.
var _musica: AudioStreamPlayer

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

	# Reproductor de efectos de sonido (voces de las frases).
	_sfx = AudioStreamPlayer.new()
	add_child(_sfx)

	# Reproductor de jingles de acierto/derrota (Win/Lost).
	_jingle = AudioStreamPlayer.new()
	add_child(_jingle)

	# Reproductor de la música ambiental en bucle.
	_musica = AudioStreamPlayer.new()
	_musica.volume_db = MUSICA_VOLUMEN_DB
	add_child(_musica)

# --- API pública ------------------------------------------------------------

## Muestra UNA frase aleatoria de la categoría indicada.
## tipo: "good" (verde), "bad" (rojo) o "neutral" (café).
func show_dialogue(categoria: String, tipo: String = "neutral") -> void:
	var frase := _frase_aleatoria(categoria)
	if frase.is_empty():
		return
	_mostrar_toast(frase.get("t", ""), _color_por_tipo(tipo))
	# Reproduce el audio de ESA frase concreta (si tiene uno asignado).
	_reproducir_archivo(frase.get("a", ""))

## Muestra un texto literal (útil para mensajes puntuales que no son una
## categoría, p. ej. "Acércate a un basurero").
func show_text(texto: String, tipo: String = "neutral") -> void:
	if texto.strip_edges() == "":
		return
	_mostrar_toast(texto, _color_por_tipo(tipo))

## Reproduce el sonido de un evento por su clave (ver SFX), p. ej. "ganar",
## "perder" o "final". Lo usa main.gd para los desenlaces de la partida.
func reproducir_sfx_evento(clave: String) -> void:
	_reproducir_evento(clave)

## Arranca la música ambiental en bucle. La llama main.gd al iniciar la partida.
## Si ya está sonando, no hace nada (evita reiniciarla).
func iniciar_musica_ambiente() -> void:
	if _musica == null or _musica.playing or not ResourceLoader.exists(MUSICA_AMBIENTE):
		return
	var stream = load(MUSICA_AMBIENTE)
	if stream == null:
		return
	# Forzamos el bucle aunque el mp3 se haya importado con loop=false.
	if stream.get("loop") != null:
		stream.set("loop", true)
	_musica.stream = stream
	_musica.play()

## Detiene la música ambiental (al terminar la partida).
func detener_musica_ambiente() -> void:
	if _musica:
		_musica.stop()

## Jingle corto de acierto (cada vez que se clasifica bien una basura).
func reproducir_win() -> void:
	_reproducir_en(_jingle, SFX_WIN)

## Jingle de derrota (al perder la partida).
func reproducir_lost() -> void:
	_reproducir_en(_jingle, SFX_LOST)

# --- Interno ----------------------------------------------------------------

# Reproduce el archivo de SFX[clave] (sonidos de desenlace) si existe.
func _reproducir_evento(clave: String) -> void:
	if clave == "":
		return
	_reproducir_ruta(SFX.get(clave, ""))

# Reproduce un audio de frase por su nombre de archivo dentro de res://audio/.
func _reproducir_archivo(archivo: String) -> void:
	if archivo == "":
		return
	_reproducir_ruta(AUDIO_DIR + archivo)

# Carga y reproduce la pista en 'ruta' en el reproductor de voces.
func _reproducir_ruta(ruta: String) -> void:
	_reproducir_en(_sfx, ruta)

# Carga y reproduce la pista en 'ruta' en el reproductor indicado. Si el archivo
# no existe (o falta), no hace nada: así el juego funciona aunque todavía no
# tengas todos los audios.
func _reproducir_en(player: AudioStreamPlayer, ruta: String) -> void:
	if ruta == "" or player == null or not ResourceLoader.exists(ruta):
		return
	var stream = load(ruta)
	if stream == null:
		return
	# Evita que un efecto quede en bucle si se importó con loop activado.
	if stream.get("loop") != null:
		stream.set("loop", false)
	player.stream = stream
	player.play()

## Elige una frase al azar de la categoría, distinta a la última mostrada.
## Devuelve el diccionario {t, a} o {} si la categoría no existe.
func _frase_aleatoria(categoria: String) -> Dictionary:
	var lista: Array = _frases.get(categoria, [])
	if lista.is_empty():
		push_warning("DialogueManager: categoría desconocida '%s'" % categoria)
		return {}
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
