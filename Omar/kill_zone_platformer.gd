extends Area3D

func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		call_deferred ("reload_scene")

func reload_scene() -> void:
		get_tree().reload_current_scene()
