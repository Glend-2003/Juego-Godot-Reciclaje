extends Node3D

@onready var angar: Node3D = $Angar
@onready var floor_body: StaticBody3D = $Floor
@onready var floor_shape: CollisionShape3D = $Floor/CollisionShape3D

func _ready() -> void:
	await get_tree().process_frame
	var aabb := _world_aabb(angar)
	var floor_y := aabb.position.y
	var ceiling_y := aabb.position.y + aabb.size.y
	print("Angar AABB (world):")
	print("  min Y (piso real)  = ", floor_y)
	print("  max Y (techo)      = ", ceiling_y)
	print("  size               = ", aabb.size)

	print("Floor (manual) global Y = ", floor_body.global_position.y)

func _world_aabb(node: Node) -> AABB:
	var combined := AABB()
	var first := true
	for child in _all_descendants(node):
		if child is VisualInstance3D:
			var vi := child as VisualInstance3D
			var a := vi.get_aabb()
			a = vi.global_transform * a
			if first:
				combined = a
				first = false
			else:
				combined = combined.merge(a)
	return combined

func _all_descendants(node: Node) -> Array:
	var out: Array = []
	for c in node.get_children():
		out.append(c)
		out.append_array(_all_descendants(c))
	return out
