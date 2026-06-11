extends RefCounted
class_name CatalogoBasura
# Catálogo de modelos .glb de basura agrupados por categoría/basurero.
# Se usan las versiones "New" de cada modelo (las más recientes).
# Las rutas apuntan a las carpetas dentro de "Game 3D/Game 3D/...".
#
# IMPORTANTE: estos .glb deben estar importados por Godot (basta con abrir el
# proyecto en el editor una vez) para que load() los pueda cargar en runtime.

const MODELOS := {
	Categorias.Tipo.AZUL: [
		"res://Game 3D/Game 3D/Basurero Azul/Clean_Bottle_New.glb",
		"res://Game 3D/Game 3D/Basurero Azul/Glass_Bottle_New.glb",
		"res://Game 3D/Game 3D/Basurero Azul/News_Paper_New.glb",
		"res://Game 3D/Game 3D/Basurero Azul/Opened_Can_New.glb",
		"res://Game 3D/Game 3D/Basurero Azul/Pizza_Box_New.glb",
		"res://Game 3D/Game 3D/Basurero Azul/Tetra_Milk_New.glb",
	],
	Categorias.Tipo.VERDE: [
		"res://Game 3D/Game 3D/Basurero Verde/Bitten_Apple_New.glb",
		"res://Game 3D/Game 3D/Basurero Verde/New_Cookie.glb",
		"res://Game 3D/Game 3D/Basurero Verde/New Egg.glb",
		"res://Game 3D/Game 3D/Basurero Verde/New Banana.glb",
		"res://Game 3D/Game 3D/Basurero Verde/Lettuce New.glb",
	],
	Categorias.Tipo.NEGRO: [
		"res://Game 3D/Game 3D/Basurero Negro/Bag_New.glb",
		"res://Game 3D/Game 3D/Basurero Negro/Dirt_Bottle_New.glb",
		"res://Game 3D/Game 3D/Basurero Negro/Used_Paper_Roll_New.glb",
	],
}

# Devuelve la ruta de un modelo aleatorio de la categoría dada ("" si no hay).
static func modelo_aleatorio(t: int) -> String:
	var lista: Array = MODELOS.get(t, [])
	if lista.is_empty():
		return ""
	return lista[randi() % lista.size()]

# Lista de categorías disponibles en el catálogo.
static func categorias() -> Array:
	return MODELOS.keys()
