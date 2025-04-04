extends Node3D

@export var point_a: Vector3
@export var point_b: Vector3
@export var speed: float = 7.0

var player_on_board = false
var moving_to_b = true

func _process(delta):
	if player_on_board:
		var target = point_b if moving_to_b else point_a
		global_position = global_position.move_toward(target, speed * delta)
		

		if global_position.distance_to(target) < 0.5:
			moving_to_b = !moving_to_b

func _on_area_3d_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_on_board = true



func _on_area_3d_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_on_board = false
