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
@export var acceleration := 15.0
@export var deceleration := 18.0

var player: CharacterBody3D
var camera_node: Camera3D
var current_horizontal_velocity := Vector3.ZERO
var is_sprinting := false
var is_targeting := false
var targeting_direction := Vector3.ZERO

# --- ADD Getter for Sprint Status ---
func is_player_sprinting() -> bool:
	return is_sprinting
# -----------------------------------

func _ready():
	# Get the parent player reference
	player = get_parent() as CharacterBody3D
	if !player:
		printerr("MovementSystem: Parent is not a CharacterBody3D or not found.")

func setup(camera: Camera3D):
	camera_node = camera
	if !camera_node:
		printerr("MovementSystem: Invalid Camera3D passed to setup().")

func get_movement_input(delta: float, targeting_active: bool) -> Dictionary:
	is_targeting = targeting_active
	# Initialize look_direction to player's current forward direction as default/fallback
	var look_direction = -player.global_transform.basis.z if player else Vector3.ZERO
	var target_velocity = Vector3.ZERO

	if !player or !camera_node:
		printerr("MovementSystem: Player or Camera node is invalid in get_movement_input.")
		# Return zero look direction if invalid to avoid errors downstream
		return {"velocity": Vector3.ZERO, "look_direction": Vector3.ZERO} 

	is_sprinting = Input.is_action_pressed("move_sprint") and not is_targeting

	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")

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
			var forward = targeting_direction
			var right = forward.cross(Vector3.UP).normalized()
			move_direction = (forward * -input_dir.y + right * input_dir.x).normalized()
			# Player faces the direction of movement
			look_direction = move_direction 
			target_velocity = move_direction * targeting_move_speed
		else:
			move_direction = (cam_forward * -input_dir.y + cam_right * input_dir.x).normalized()
			# Player faces the direction of movement
			look_direction = move_direction 
			var current_speed = sprint_speed if is_sprinting else move_speed
			target_velocity = move_direction * current_speed
	else:
		# --- No Movement Input ---
		# Velocity is zero
		target_velocity = Vector3.ZERO
		# look_direction remains the player's current facing direction (initialized above)
		# REMOVED: logic that set look_direction = cam_forward or targeting_direction
		# Example of removed lines:
		# if !is_targeting:
		# 	look_direction = cam_forward
		# else:
		# 	look_direction = targeting_direction

	return {"velocity": target_velocity, "look_direction": look_direction}

func set_targeting_state(is_target_active: bool, direction_to_target: Vector3):
	is_targeting = is_target_active
	targeting_direction = direction_to_target.normalized()

	if is_targeting:
		is_sprinting = false

func interact():
	if !player:
		printerr("MovementSystem: Cannot interact, player reference is invalid.")
		return
		
	var space_state = player.get_world_3d().direct_space_state
	var ray_params = PhysicsRayQueryParameters3D.new()
	ray_params.from = player.global_position + Vector3.UP * 0.5
	ray_params.to = player.global_position + Vector3.UP * 0.5 + -player.global_transform.basis.z * 2.0
	ray_params.collision_mask = 1
	ray_params.exclude = [player]

	var result = space_state.intersect_ray(ray_params)
	if result:
		var collider = result.collider
		if collider.has_method("interact"):
			collider.interact(player)
