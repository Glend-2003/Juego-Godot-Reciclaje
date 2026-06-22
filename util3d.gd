extends RefCounted
class_name Util3D
# Utilidades geométricas compartidas (AABB).

# Todos los descendientes de 'nodo' de forma recursiva.
static func todos_los_descendientes(nodo: Node) -> Array:
	var salida: Array = []
	for hijo in nodo.get_children():
		salida.append(hijo)
		salida.append_array(todos_los_descendientes(hijo))
	return salida

# AABB que envuelve todas las mallas de 'nodo' en coordenadas de mundo.
static func aabb_mundo(nodo: Node3D) -> AABB:
	var combinado := AABB()
	var primero := true
	for hijo in todos_los_descendientes(nodo):
		if hijo is VisualInstance3D:
			var vi := hijo as VisualInstance3D
			var a := vi.global_transform * vi.get_aabb()
			if primero:
				combinado = a
				primero = false
			else:
				combinado = combinado.merge(a)
	return combinado
