extends Area3D
class_name TrashItem
# Una pieza de basura en el mundo.
#
# Es un Area3D (no un cuerpo físico) para que el jugador la pueda DETECTAR al
# acercarse, pero sin bloquear su movimiento. Cada instancia recuerda a qué
# categoría/basurero pertenece. NO desaparece sola: permanece hasta que el
# jugador la recoge.

@export var categoria: int = Categorias.Tipo.AZUL
# Ruta del .glb. Se guarda para poder recrear el indicador flotante al recogerla.
var modelo_path: String = ""

var _modelo: Node3D

# Marcador flotante PERMANENTE sobre la basura, para verla siempre desde lejos.
# Su color es el de la categoría/basurero al que pertenece.
var _marcador: MeshInstance3D
var _marcador_y0: float = 0.0
var _t: float = 0.0

# Fábrica: crea una basura lista para añadir a la escena.
static func crear(cat: int, ruta: String) -> TrashItem:
	var item := TrashItem.new()
	item.categoria = cat
	item.modelo_path = ruta
	return item

func _ready() -> void:
	add_to_group("basura")
	# Capa 2 = "interactuable": el jugador la detecta, pero no colisiona con la
	# física del personaje ni con las paredes.
	collision_layer = 2
	collision_mask = 0
	monitorable = true
	monitoring = false
	await _instanciar_modelo()

func _instanciar_modelo() -> void:
	if modelo_path == "":
		return
	var escena: PackedScene = load(modelo_path)
	if escena == null:
		push_warning("[TrashItem] No se pudo cargar el modelo (¿importado en Godot?): " + modelo_path)
		return
	_modelo = escena.instantiate()
	add_child(_modelo)
	# Esperar un frame para que las mallas tengan su AABB calculado.
	await get_tree().process_frame
	_ajustar_colision_y_apoyo()

# Crea la forma de colisión del Area a partir del tamaño real del modelo y
# apoya la base de la basura sobre el piso (su punto más bajo en Y local = 0).
func _ajustar_colision_y_apoyo() -> void:
	var aabb := Util3D.aabb_mundo(self)
	if aabb.size == Vector3.ZERO:
		return
	# Centro del AABB en espacio local (el item no tiene escala).
	var centro_local := (aabb.position + aabb.size * 0.5) - global_position
	var min_y_local := aabb.position.y - global_position.y
	# Subir el modelo para que se apoye en el piso.
	var dy := -min_y_local
	_modelo.position.y += dy

	var col := CollisionShape3D.new()
	var forma := BoxShape3D.new()
	forma.size = aabb.size
	col.shape = forma
	col.position = Vector3(centro_local.x, centro_local.y + dy, centro_local.z)
	add_child(col)

	# Crear el marcador flotante justo encima del modelo.
	_crear_marcador(aabb.size.y)

# Pequeño diamante emisivo del color de la categoría, flotando sobre la basura.
func _crear_marcador(altura_modelo: float) -> void:
	_marcador = MeshInstance3D.new()
	_marcador.name = "MarcadorUbicacion"
	# Cono invertido (triángulo) que apunta hacia la basura, igual que el antiguo
	# marcador de selección.
	var cono := CylinderMesh.new()
	cono.top_radius = 0.0
	cono.bottom_radius = 0.18
	cono.height = 0.35
	_marcador.mesh = cono

	var mat := StandardMaterial3D.new()
	# Amarillo para TODAS: solo marca dónde está la basura, no de qué tipo es.
	mat.albedo_color = Color(1.0, 0.9, 0.1)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.85, 0.0)
	mat.emission_energy_multiplier = 1.6
	_marcador.material_override = mat

	_marcador.rotation.x = PI   # punta hacia abajo
	_marcador_y0 = altura_modelo + 0.5
	_marcador.position.y = _marcador_y0
	add_child(_marcador)

func _process(delta: float) -> void:
	if _marcador == null:
		return
	# Flota suavemente para llamar la atención.
	_t += delta
	_marcador.position.y = _marcador_y0 + sin(_t * 2.5) * 0.08
