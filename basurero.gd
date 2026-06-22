extends Area3D
class_name Basurero
# Área de depósito de un basurero. Hijo de cada modelo de basurero (.glb).

@export var categoria: int = Categorias.Tipo.AZUL
@export var radio: float = 2.5
@export var acepta_todo: bool = false   # si true, acepta cualquier categoría

func _ready() -> void:
	add_to_group("basurero")
	# Layer 3 = "basureros". El depósito es manual (tecla G).
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
