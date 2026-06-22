extends Control


func _on_texture_button_pressed() -> void:
	# Va a la pantalla de carga, que luego entra a main.tscn.
	get_tree().change_scene_to_file("res://loading.tscn")
