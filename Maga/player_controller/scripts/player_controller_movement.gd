# .----------------------------------------------------------------------------.
# |:::    :::     :::     :::        ::::::::  :::   :::  ::::::::  ::::    :::|
# |:+:    :+:   :+: :+:   :+:       :+:    :+: :+:   :+: :+:    :+: :+:+:   :+:|
# |+:+    +:+  +:+   +:+  +:+       +:+         +:+ +:+  +:+    +:+ :+:+:+  +:+|
# |+#++:++#++ +#++:++#++: +#+       +#+          +#++:   +#+    +:+ +#+ +:+ +#+|
# |+#+    +#+ +#+     +#+ +#+       +#+           +#+    +#+    +#+ +#+  +#+#+#|
# |#+#    #+# #+#     #+# #+#       #+#    #+#    #+#    #+#    #+# #+#   #+#+#|
# |###    ### ###     ### ########## ########     ###     ########  ###    ####|
# '----------------------------------------------------------------------------'
# Player Controller Movement
#
# Developed by:
# - Liam Maga
# - 
# - 
# .----------------------------------------------------------------------------.


extends Node

@export var move_speed := 5.0
@export var sprint_speed := 8.0
@export var targeting_move_speed := 3.5
@export var acceleration := 10.0
@export var deceleration := 12.0
@export var jump_strength := 5.0
@export var gravity := 9.8
@export var rotation_speed := 10.0

var player: CharacterBody3D
var camera_node: Camera3D
var velocity := Vector3.ZERO
var is_jumping := false
var is_sprinting := false
var snap_vector := Vector3.DOWN
var is_targeting := false
var targeting_direction := Vector3.ZERO

func _ready():
	# Get the parent player reference
	player = get_parent() as CharacterBody3D
	
func setup(camera: Camera3D):
	camera_node = camera

func _physics_process(delta: float) -> void:
	if !player or !camera_node:
		return
		
	# Apply gravity
	if not player.is_on_floor():
		player.velocity.y -= gravity * delta
	else:
		snap_vector = Vector3.DOWN
		
	# Check for sprint input
	is_sprinting = Input.is_action_pressed("move_sprint") and not is_targeting
		
	# Handle jumping
	if Input.is_action_just_pressed("move_jump") and player.is_on_floor():
		player.velocity.y = jump_strength
		is_jumping = true
		snap_vector = Vector3.ZERO
	
	if is_jumping and player.is_on_floor():
		is_jumping = false

	# Get input direction
	var input_dir = Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_backward") - Input.get_action_strength("move_forward")
	).normalized()

	# Get camera basis
	var cam_basis = camera_node.global_transform.basis
	var cam_forward = -cam_basis.z
	var cam_right = cam_basis.x

	# Flatten vectors
	cam_forward.y = 0
	cam_right.y = 0
	cam_forward = cam_forward.normalized()
	cam_right = cam_right.normalized()

	# Direction relative to camera
	var direction = Vector3.ZERO
	if input_dir != Vector2.ZERO:
		# In targeting mode, move relative to targeting direction
		if is_targeting:
			var forward = targeting_direction
			var right = forward.cross(Vector3.UP)
			
			direction = (forward * -input_dir.y + right * input_dir.x).normalized()
			
			# Use targeting movement speed
			var target_velocity = direction * targeting_move_speed
			var current_velocity = Vector3(player.velocity.x, 0, player.velocity.z)
			
			# Apply acceleration or deceleration
			current_velocity = current_velocity.lerp(target_velocity, acceleration * delta)
			
			# Apply to velocity
			player.velocity.x = current_velocity.x
			player.velocity.z = current_velocity.z
		else:
			# Normal movement relative to camera
			direction = (cam_forward * input_dir.y + cam_right * input_dir.x).normalized()
			
			# Determine movement speed based on sprint state
			var current_speed = sprint_speed if is_sprinting else move_speed
			
			# Horizontal movement
			var target_velocity = direction * current_speed
			var current_velocity = Vector3(player.velocity.x, 0, player.velocity.z)
			
			# Apply acceleration or deceleration
			current_velocity = current_velocity.lerp(target_velocity, acceleration * delta)
			
			# Apply to velocity
			player.velocity.x = current_velocity.x
			player.velocity.z = current_velocity.z
	else:
		# Decelerate when no input
		player.velocity.x = move_toward(player.velocity.x, 0, deceleration * delta)
		player.velocity.z = move_toward(player.velocity.z, 0, deceleration * delta)

	# Apply movement
	player.move_and_slide()

	# Handle rotation
	if direction != Vector3.ZERO and !is_targeting:
		var look_direction = direction
		var target_transform = player.transform.looking_at(player.global_position + look_direction, Vector3.UP)
		player.transform = player.transform.interpolate_with(target_transform, delta * rotation_speed)
	elif is_targeting:
		# When targeting, always face the target
		if targeting_direction != Vector3.ZERO:
			var target_transform = player.transform.looking_at(player.global_position + targeting_direction, Vector3.UP)
			player.transform = player.transform.interpolate_with(target_transform, delta * 15.0)

# Called by the core when a target is acquired or released
func set_targeting_direction(direction: Vector3, is_target_active: bool):
	targeting_direction = direction
	is_targeting = is_target_active
	
	# Disable sprinting when targeting
	if is_targeting:
		is_sprinting = false

# Handle interactions
func interact():
	# Create a raycast forward to detect interactable objects
	var space_state = player.get_world_3d().direct_space_state
	var ray_params = PhysicsRayQueryParameters3D.new()
	ray_params.from = player.global_position + Vector3.UP * 0.5
	ray_params.to = player.global_position + Vector3.UP * 0.5 + -player.global_transform.basis.z * 2.0
	ray_params.collision_mask = 1  # Adjust mask as needed
	
	var result = space_state.intersect_ray(ray_params)
	if result:
		var collider = result.collider
		if collider.has_method("interact"):
			collider.interact(player)
