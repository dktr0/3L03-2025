extends Node3D 


var speed = 2.0
var rotation_speed = 0.5
var direction = Vector3()
var target_direction = Vector3()  # Target direction the manta ray is turning towards
var change_direction_timer = 0

@onready var animation_player = $mantarayanimation

@export var bounds_min: Vector3 = Vector3(-50, -50, -50)  # Define the min XYZ limits
@export var bounds_max: Vector3 = Vector3(500, 500, 500)  # Define the max XYZ limits

var turn_speed = 2.0  # How fast the manta ray turns towards the new direction
var rotation_tolerance = 0.1  # When to start steering toward the new direction

func _ready():
	animation_player.play("swim")
	_generate_new_direction()

func _process(delta):
	# Smoothly rotate the manta ray towards the target direction
	direction = direction.lerp(target_direction, turn_speed * delta)

	# Move the manta ray in the current direction
	global_transform.origin += direction * speed * delta  # Apply movement

	# Keep the manta ray facing the direction it is moving
	if direction.length() > 0:  # Prevent division by zero if direction is zero
		look_at(global_transform.origin - direction, Vector3.UP)  # Align with movement direction

	rotation.y += rotation_speed * delta * (randf() - 0.5)

	# Check if the manta ray is outside bounds and correct its direction smoothly
	var pos = global_transform.origin
	if pos.x < bounds_min.x or pos.x > bounds_max.x or pos.y < bounds_min.y or pos.y > bounds_max.y or pos.z < bounds_min.z or pos.z > bounds_max.z:
		_generate_new_direction()  # Pick a new direction smoothly

	# Change direction after a random interval
	change_direction_timer -= delta
	if change_direction_timer <= 0:
		_generate_new_direction() 
func _generate_new_direction():
	# Generate a random new direction for the manta ray
	target_direction = Vector3(randf() * 2 - 1, randf() * 2 - 1, randf() * 2 - 1).normalized()
	change_direction_timer = randf_range(2.0, 5.0)
