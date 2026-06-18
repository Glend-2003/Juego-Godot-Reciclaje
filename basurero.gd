extends Area3D
class_name Basurero
# Área de depósito de un basurero. Se coloca como hijo de cada modelo de
# basurero (.glb) y detecta cuando el jugador entra cargando algo. Si la
# categoría coincide (o si el basurero acepta cualquier cosa) deposita la
# basura: la oculta y deja al jugador con las manos vacías.

@export var categoria: int = Categorias.Tipo.AZUL
@export var radio: float = 2.5
@export var acepta_todo: bool = false   # si true, acepta cualquier categoría

func _ready() -> void:
	add_to_group("basurero")
	# Layer 3 = "basureros". El PickupSystem detecta esta capa para que el jugador
	# sepa cuándo está cerca de un basurero, pero el depósito es MANUAL (tecla G).
	collision_layer = 4
	collision_mask = 0
	monitoring = false
	monitorable = true
	var col := CollisionShape3D.new()
	var forma := SphereShape3D.new()
	forma.radius = radio
	col.shape = forma
	col.position = Vector3(0, 1.0, 0)
	add_child(col)
