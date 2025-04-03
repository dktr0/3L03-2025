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

## Movement parameters exposed in the editor
@export var move_speed := 5.0
@export var sprint_speed := 8.0
@export var targeting_move_speed := 3.5
@export var acceleration := 15.0
@export var deceleration := 18.0

# References to core nodes
var player: CharacterBody3D
var camera_node: Camera3D

# Movement state variables
var current_horizontal_velocity := Vector3.ZERO
var is_sprinting := false
var is_targeting := false
var targeting_direction := Vector3.ZERO

## Returns whether the player is currently sprinting.
func is_player_sprinting() -> bool:
	return is_sprinting

## Called when the node enters the scene tree.
func _ready():
	# Get the parent CharacterBody3D node
	player = get_parent() as CharacterBody3D
	if !player:
		printerr("MovementSystem: Parent is not a CharacterBody3D or not found.")

## Sets up the movement system with necessary node references.
func setup(camera: Camera3D):
	camera_node = camera
	if !camera_node:
		printerr("MovementSystem: Invalid Camera3D passed to setup().")

## Calculates the desired movement velocity and look direction based on input.
## Returns a dictionary containing target 'velocity' and 'look_direction'.
func get_movement_input(_delta: float, targeting_active: bool) -> Dictionary:
	is_targeting = targeting_active
	# Default look direction to player's current forward if no input or other overrides
	var look_direction = -player.global_transform.basis.z if player else Vector3.ZERO
	var target_velocity = Vector3.ZERO

	if !player or !camera_node:
		printerr("MovementSystem: Player or Camera node is invalid in get_movement_input.")
		# Return zero vectors to prevent errors downstream
		return {"velocity": Vector3.ZERO, "look_direction": Vector3.ZERO} 

	# Sprinting is only allowed when not targeting
	is_sprinting = Input.is_action_pressed("move_sprint") and not is_targeting

	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")

	# Get camera basis vectors for camera-relative movement, ignoring vertical component
	var cam_basis = camera_node.global_transform.basis
	var cam_forward = -cam_basis.z
	var cam_right = cam_basis.x
	cam_forward.y = 0
	cam_right.y = 0
	cam_forward = cam_forward.normalized()
	cam_right = cam_right.normalized()

	var move_direction = Vector3.ZERO
	if input_dir != Vector2.ZERO:
		# --- Movement Input Detected ---
		if is_targeting:
			# Targeting movement: Strafe relative to targeting direction
			var forward = targeting_direction
			var right = forward.cross(Vector3.UP).normalized() # Calculate strafe direction
			move_direction = (forward * -input_dir.y + right * input_dir.x).normalized()
			look_direction = targeting_direction # Always look towards the target
			target_velocity = move_direction * targeting_move_speed
		else:
			# Normal movement: Relative to camera direction
			move_direction = (cam_forward * -input_dir.y + cam_right * input_dir.x).normalized()
			look_direction = move_direction # Look in the direction of movement
			var current_speed = sprint_speed if is_sprinting else move_speed
			target_velocity = move_direction * current_speed
	else:
		# --- No Movement Input ---
		target_velocity = Vector3.ZERO
		# Keep the previously set look_direction (player's current forward)

	return {"velocity": target_velocity, "look_direction": look_direction}

## Updates the targeting state and direction.
func set_targeting_state(is_target_active: bool, direction_to_target: Vector3):
	is_targeting = is_target_active
	targeting_direction = direction_to_target.normalized()

	# Cannot sprint while targeting
	if is_targeting:
		is_sprinting = false

## Performs a raycast forward from the player to interact with objects.
func interact():
	if !player:
		printerr("MovementSystem: Cannot interact, player reference is invalid.")
		return
		
	var space_state = player.get_world_3d().direct_space_state
	var ray_params = PhysicsRayQueryParameters3D.new()
	# Ray starts slightly above player origin
	ray_params.from = player.global_position + Vector3.UP * 0.5 
	# Ray extends forward from player
	ray_params.to = player.global_position + Vector3.UP * 0.5 + -player.global_transform.basis.z * 2.0 
	ray_params.collision_mask = 1 # Interact with layer 1 objects
	ray_params.exclude = [player] # Don't interact with self

	var result = space_state.intersect_ray(ray_params)
	if result:
		var collider = result.collider
		# Check if the collided object has an interact method
		if collider.has_method("interact"):
			collider.interact(player) # Call the object's interact method
