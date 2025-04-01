extends CharacterBody3D

@export var move_speed: float = 6.0
@export var run_speed: float  = 10.0
@export var rotate_speed: float = 60.0  
@export var gravity: float    = 20.0
@export var jump_speed: float = 8.0

@export var aim_speed: float = 3.0   


func _physics_process(delta: float) -> void:

	var forward_input = Input.get_action_strength("move_forward") - Input.get_action_strength("move_back")
	var turn_input    = Input.get_action_strength("move_right")  - Input.get_action_strength("move_left")


	var dir = transform.basis.z
	dir.y = 0
	dir = dir.normalized()


	velocity.x = 0
	velocity.z = 0


	if forward_input > 0:

		velocity.x = dir.x * move_speed
		velocity.z = dir.z * move_speed
	elif forward_input < 0:

		velocity.x = -dir.x * move_speed
		velocity.z = -dir.z * move_speed


	if turn_input != 0:
		var angle_change = deg_to_rad(rotate_speed) * turn_input * delta
		rotation.y += angle_change


	if is_sprinting():

		var ratio = run_speed / move_speed
		velocity.x *= ratio
		velocity.z *= ratio
	elif is_aiming():

		var ratio2 = aim_speed / move_speed
		velocity.x *= ratio2
		velocity.z *= ratio2


	velocity.y -= gravity * delta
	if Input.is_action_just_pressed("move_jump") and is_on_floor():
		velocity.y = jump_speed


	self.velocity = velocity
	move_and_slide()


func is_sprinting() -> bool:
	return Input.is_action_pressed("move_sprint")

func is_aiming() -> bool:
	return Input.is_action_pressed("aim")
