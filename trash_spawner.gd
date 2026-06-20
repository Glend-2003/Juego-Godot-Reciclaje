extends Node3D
class_name TrashSpawner
# Genera basura aleatoria alrededor de un punto central.
# Las basuras generadas NO desaparecen solas: quedan en la escena hasta que el
# jugador las recoja.

@export var cantidad: int = 20          # cuántas basuras generar
@export var radio: float = 24.0         # radio máximo de dispersión
@export var radio_minimo: float = 6.0   # zona despejada en el centro (hay que caminar para llegar)
@export var altura_piso: float = 1.75   # Y del piso donde se apoyan las basuras
@export var generar_al_iniciar: bool = false  # si true, usa la posición de este nodo como centro

# Cuántas veces se reintenta buscar una posición libre antes de rendirse y
# colocar la basura igual (evita un bucle infinito si todo está muy lleno).
const MAX_INTENTOS := 40

# Zonas donde NO debe aparecer basura (paredes, basureros, motos…). Cada zona es
# un círculo en el plano XZ: { "c": Vector2(x, z), "r": float }. Se llenan desde
# fuera con agregar_zona_prohibida() antes de llamar a generar().
var _zonas_prohibidas: Array[Dictionary] = []

# Límite rectangular opcional del área jugable (cara interna de las paredes), en
# coordenadas de mundo XZ. La basura nunca se coloca fuera de él. Si no se define,
# solo manda el radio de dispersión.
var _tiene_limites: bool = false
var _lim_min: Vector2 = Vector2.ZERO
var _lim_max: Vector2 = Vector2.ZERO

func _ready() -> void:
	if generar_al_iniciar:
		generar(global_position)

# Registra un círculo prohibido (en XZ de mundo) donde no debe caer basura.
func agregar_zona_prohibida(centro_xz: Vector2, radio_zona: float) -> void:
	_zonas_prohibidas.append({"c": centro_xz, "r": radio_zona})

# Borra todas las zonas prohibidas y los límites (útil al regenerar el mundo).
func limpiar_zonas() -> void:
	_zonas_prohibidas.clear()
	_tiene_limites = false

# Define el rectángulo jugable (en XZ de mundo) fuera del cual no se coloca basura.
func definir_limites(min_xz: Vector2, max_xz: Vector2) -> void:
	_lim_min = Vector2(min(min_xz.x, max_xz.x), min(min_xz.y, max_xz.y))
	_lim_max = Vector2(max(min_xz.x, max_xz.x), max(min_xz.y, max_xz.y))
	_tiene_limites = true

# true si el punto XZ está dentro de los límites y fuera de toda zona prohibida.
func _posicion_valida(x: float, z: float) -> bool:
	if _tiene_limites:
		if x < _lim_min.x or x > _lim_max.x or z < _lim_min.y or z > _lim_max.y:
			return false
	for zona in _zonas_prohibidas:
		var c: Vector2 = zona["c"]
		var r: float = zona["r"]
		if Vector2(x, z).distance_squared_to(c) < r * r:
			return false
	return true

# Genera 'cantidad' basuras en un anillo [radio_minimo, radio] alrededor de
# 'centro'. Los parámetros opcionales permiten sobreescribir radio/altura.
func generar(centro: Vector3, radio_disp: float = -1.0, altura: float = -1.0) -> void:
	if radio_disp < 0.0:
		radio_disp = radio
	if altura < 0.0:
		altura = altura_piso

	var cats: Array = CatalogoBasura.categorias()
	if cats.is_empty():
		push_warning("[TrashSpawner] El catálogo de basura está vacío.")
		return

	for i in cantidad:
		# Categoría y modelo aleatorios.
		var cat: int = cats[randi() % cats.size()]
		var ruta := CatalogoBasura.modelo_aleatorio(cat)
		if ruta == "":
			continue

		var item := TrashItem.crear(cat, ruta)
		add_child(item)

		# Posición en un anillo alrededor del centro. sqrt(randf()) reparte de
		# forma uniforme por área (evita amontonar todo cerca del centro). Se
		# reintenta hasta dar con un punto que no caiga sobre una estructura
		# (paredes, basureros, motos) ni fuera del área jugable.
		var px: float = centro.x
		var pz: float = centro.z
		for intento in MAX_INTENTOS:
			var ang := randf() * TAU
			var dist: float = lerp(radio_minimo, radio_disp, sqrt(randf()))
			px = centro.x + cos(ang) * dist
			pz = centro.z + sin(ang) * dist
			if _posicion_valida(px, pz):
				break
		item.global_position = Vector3(px, altura, pz)
		# Giro aleatorio en Y para dar variedad visual.
		item.rotation.y = randf() * TAU

	print("[TrashSpawner] Basuras generadas: ", get_child_count(), " (centro=", centro, " radio=", radio_disp, ")")
