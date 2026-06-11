extends RefCounted
class_name Categorias
# Categorías de basura según el basurero al que pertenecen.
#   AZUL  = reciclable
#   VERDE = orgánico
#   NEGRO = no valorizable

enum Tipo { AZUL, VERDE, NEGRO }

# Nombre legible (para etiquetas del mundo y depuración).
static func nombre(t: int) -> String:
	match t:
		Tipo.AZUL:
			return "Reciclable"
		Tipo.VERDE:
			return "Orgánico"
		Tipo.NEGRO:
			return "No valorizable"
	return "?"

# Color representativo del basurero (se usa para el placeholder visual).
static func color(t: int) -> Color:
	match t:
		Tipo.AZUL:
			return Color(0.15, 0.40, 0.90)
		Tipo.VERDE:
			return Color(0.20, 0.70, 0.25)
		Tipo.NEGRO:
			return Color(0.12, 0.12, 0.12)
	return Color.WHITE
