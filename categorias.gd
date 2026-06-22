extends RefCounted
class_name Categorias
# Categorías de basura según el basurero al que pertenecen.

enum Tipo { AZUL, VERDE, NEGRO, GRIS, TAPAS }

# Nombre legible.
static func nombre(t: int) -> String:
	match t:
		Tipo.AZUL:
			return "Plásticos"
		Tipo.VERDE:
			return "Orgánicos"
		Tipo.NEGRO:
			return "No valorizables"
		Tipo.GRIS:
			return "Papel y Cartón"
		Tipo.TAPAS:
			return "Tapas plásticas"
	return "?"

# Color representativo del basurero.
static func color(t: int) -> Color:
	match t:
		Tipo.AZUL:
			return Color(0.15, 0.40, 0.90)
		Tipo.VERDE:
			return Color(0.20, 0.70, 0.25)
		Tipo.NEGRO:
			return Color(0.12, 0.12, 0.12)
		Tipo.GRIS:
			return Color(0.55, 0.55, 0.58)
		Tipo.TAPAS:
			return Color(1.00, 0.65, 0.15)
		_:
			return Color.WHITE
