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

func _ready() -> void:
	if generar_al_iniciar:
		generar(global_position)

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
		# forma uniforme por área (evita amontonar todo cerca del centro).
		var ang := randf() * TAU
		var dist: float = lerp(radio_minimo, radio_disp, sqrt(randf()))
		item.global_position = Vector3(
			centro.x + cos(ang) * dist,
			altura,
			centro.z + sin(ang) * dist
		)
		# Giro aleatorio en Y para dar variedad visual.
		item.rotation.y = randf() * TAU

	print("[TrashSpawner] Basuras generadas: ", get_child_count(), " (centro=", centro, " radio=", radio_disp, ")")
