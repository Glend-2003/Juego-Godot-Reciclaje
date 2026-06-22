extends RefCounted
class_name CatalogoBasura
# Modelos .glb de basura agrupados por categoría.

const MODELOS := {
	Categorias.Tipo.AZUL: [
		"res://Game 3D/Game 3D/Basurero Azul/Clean_Bottle_New.glb",
		"res://Game 3D/Game 3D/Basurero Azul/Glass_Bottle_New.glb",
		"res://Game 3D/Game 3D/Basurero Azul/Opened_Can_New.glb",
	],
	Categorias.Tipo.GRIS: [
		"res://Game 3D/Game 3D/Basurero Azul/News_Paper_New.glb",
		"res://Game 3D/Game 3D/Basurero Azul/Pizza_Box_New.glb",
		"res://Game 3D/Game 3D/Basurero Azul/Tetra_Milk_New.glb",
		"res://Game 3D/Game 3D/Basurero Negro/Used_Paper_Roll_New.glb",
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
	],
	Categorias.Tipo.TAPAS: [],
}

# Ruta de un modelo aleatorio de la categoría ("" si no hay).
static func modelo_aleatorio(t: int) -> String:
	var lista: Array = MODELOS.get(t, [])
	if lista.is_empty():
		return ""
	return lista[randi() % lista.size()]

# Categorías disponibles (excluye las vacías).
static func categorias() -> Array:
	var out: Array = []
	for k in MODELOS.keys():
		if not (MODELOS[k] as Array).is_empty():
			out.append(k)
	return out
