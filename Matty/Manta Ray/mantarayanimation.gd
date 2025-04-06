extends Node3D 

var speed = 7.0
var rotation_speed = 0.5
var direction = Vector3()
var target_direction = Vector3()  # Target direction the manta ray is turning towards
var change_direction_timer = 0

@onready var animation_player = $mantarayanimation

@export var bounds_min: Vector3 = Vector3(-750, -110, -500)  # Define the min XYZ limits
@export var bounds_max: Vector3 = Vector3(-300, -15, -100)  # Define the max XYZ limits

var turn_speed = 2.0  # How fast the manta ray turns towards the new direction
var rotation_tolerance = 0.1  # When to start steering toward the new direction

# The center of the bounded area, calculated from min and max bounds
var center = (bounds_max + bounds_min) / 2

func _ready():
	animation_player.play("swim")
	_generate_new_direction()

func _process(delta):
	# Smoothly rotate the manta ray towards the target direction
	direction = direction.lerp(target_direction, turn_speed * delta)

	# Move the manta ray in the current direction
	global_transform.origin += direction * speed * delta  # Apply movement

	# Keep the manta ray facing the direction it is moving
	if direction.length() > 0:
		look_at(global_transform.origin - direction, Vector3.UP)

	# Add some gentle wobble rotation
	rotation.y += rotation_speed * delta * (randf() - 0.5)

	# Predictive boundary avoidance with center attraction
	var buffer_distance = 20.0
	var pos = global_transform.origin
	var need_new_dir = false
	var new_dir = direction

	# If near the boundary, attract toward the center
	if pos.x < bounds_min.x + buffer_distance:
		new_dir.x += 0.4  # Push towards the center horizontally
		need_new_dir = true
	elif pos.x > bounds_max.x - buffer_distance:
		new_dir.x -= 0.4  # Push towards the center horizontally
		need_new_dir = true

	if pos.y < bounds_min.y + buffer_distance:
		new_dir.y += 0.2  # Push towards the center vertically
		need_new_dir = true
	elif pos.y > bounds_max.y - buffer_distance:
		new_dir.y -= 0.2  # Push towards the center vertically
		need_new_dir = true

	if pos.z < bounds_min.z + buffer_distance:
		new_dir.z += 0.4  # Push towards the center horizontally (Z-axis)
		need_new_dir = true
	elif pos.z > bounds_max.z - buffer_distance:
		new_dir.z -= 0.4  # Push towards the center horizontally (Z-axis)
		need_new_dir = true

	# If we're near the edges, nudge the manta ray toward the center
	if need_new_dir:
		target_direction = new_dir.normalized()

	# Change direction after a random interval
	change_direction_timer -= delta
	if change_direction_timer <= 0:
		_generate_new_direction()

func _generate_new_direction():
	# Generate a random direction within the bounds, with the center as a focal point
	var rand_dir = Vector3(
		randf_range(-0.3, 0.3),  # Subtle range on X axis
		randf_range(-0.1, 0.1),  # Subtle range on Y axis
		randf_range(-0.3, 0.3)   # Subtle range on Z axis
	)
	target_direction = rand_dir.normalized()
	change_direction_timer = randf_range(4.0, 10.0)  # Random time between direction changes
