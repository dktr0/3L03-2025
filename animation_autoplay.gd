extends Area3D

@onready var manta_ray = $MantaRay  # Path to the manta ray node
@onready var anim_player = manta_ray.get_node("AnimationPlayer")  # Path to the AnimationPlayer

@export var speed : float = 1.5  # Movement speed
@export var turn_speed : float = 0.5  # How fast it changes direction
@export var wave_amplitude : float = 0.5  # Vertical movement amplitude
@export var wave_frequency : float = 1.0  # Frequency of the up-and-down motion
@export var direction_change_interval : float = 3.0  # How often to change direction

var target_direction : Vector3 = Vector3.ZERO
var time_passed : float = 0.0

func _ready():
	anim_player.play("swim")  # Ensure animation plays
	set_random_direction()  # Initial random direction

func _process(delta):
	# Update swimming direction and position
	time_passed += delta

	# Move forward based on current direction
	var forward = transform.basis.z * -speed * delta  # Negative to move forward
	translate(forward)

	# Apply up-down wave motion
	var wave_offset = sin(time_passed * wave_frequency) * wave_amplitude
	translate(Vector3(0, wave_offset * delta, 0))  # Smooth vertical movement

	# Gradually rotate to the new direction
	rotate_y(target_direction.y * turn_speed * delta)

	# Change swimming direction randomly at intervals
	if time_passed > direction_change_interval:
		set_random_direction()
		time_passed = 0.0  # Reset the timer

func set_random_direction():
	# Generate a random direction to swim towards
	target_direction = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
