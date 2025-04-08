extends Area3D

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		var cb = body as CharacterBody3D
		
		if cb.has_meta("last_safe_position"):
			var safe_pos = cb.get_meta("last_safe_position") as Vector3

			
			var transform = cb.global_transform
			transform.origin = safe_pos
			cb.global_transform = transform

			cb.velocity = Vector3.ZERO
		else:
			get_tree().reload_current_scene()
