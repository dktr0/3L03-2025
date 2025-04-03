# .----------------------------------------------------------------------------.
# |:::    :::     :::     :::        ::::::::  :::   :::  ::::::::  ::::    :::|
# |:+:    :+:   :+: :+:   :+:       :+:    :+: :+:   :+: :+:    :+: :+:+:   :+:|
# |+:+    +:+  +:+   +:+  +:+       +:+         +:+ +:+  +:+    +:+ :+:+:+  +:+|
# |+#++:++#++ +#++:++#++: +#+       +#+          +#++:   +#+    +:+ +#+ +:+ +#+|
# |+#+    +#+ +#+     +#+ +#+       +#+           +#+    +#+    +#+ +#+  +#+#+#|
# |#+#    #+# #+#     #+# #+#       #+#    #+#    #+#    #+#    #+# #+#   #+#+#|
# |###    ### ###     ### ########## ########     ###     ########  ###    ####|
# '----------------------------------------------------------------------------'
# Player Controller Camera
#
# Developed by:
# - Liam Maga
# - 
# - 
# .----------------------------------------------------------------------------.


extends Camera3D

@export_category("Camera Settings")
@export var follow_speed := 5.0
@export var mouse_sensitivity_x := 0.003 # Sensitivity for horizontal mouse movement
@export var mouse_sensitivity_y := 0.003 # Sensitivity for vertical mouse movement
@export var min_distance := 1.0 # Closer min distance
@export var max_distance := 6.0 # Reduce max distance slightly too
@export var desired_distance := 2.8 # Even closer default distance
@export var desired_height := 1.8 # Slightly lower height offset
@export var targeting_height := 1.5
@export var targeting_distance := 4.0
@export var targeting_lerp_speed := 8.0
@export var collision_mask := 1  # Layer for camera collision
@export var target_path: NodePath
@export var min_pitch_degrees := -60.0 # Minimum vertical angle
@export var max_pitch_degrees := 75.0  # Maximum vertical angle
@export var horizontal_offset := 0 # Horizontal offset for over-the-shoulder view
@export var base_fov := 75.0 # Default field of view
@export var sprint_fov_increase := 10.0 # How much FOV increases when sprinting
@export var fov_lerp_speed := 6.0 # How fast the FOV transitions
@export var trail_offset_strength := 0.3 # Strength of the movement trail effect
@export var trail_lerp_speed := 5.0 # How quickly the trail offset adapts

var target: Node3D
var movement_system: Node # Add reference to get sprint status
var camera_pitch := 0.0
var camera_yaw := 0.0
var current_distance := desired_distance
var current_trail_offset := Vector3.ZERO # Stores the smoothly interpolated offset
# var right_stick_deadzone := 0.1 # No longer needed for mouse
var targeting_mode := false
var current_target: Node3D = null

# Convert degrees to radians once
var min_pitch_rad: float
var max_pitch_rad: float

func _ready():
	if target_path:
		target = get_node(target_path)
		if !target:
			printerr("Camera: Target node not found at path: ", target_path)
		else:
			# Try to get movement system reference from the target (Player node)
			movement_system = target.get_node_or_null("MovementSystem")
			if !movement_system or !movement_system.has_method("is_player_sprinting"):
				printerr("Camera: MovementSystem node or 'is_player_sprinting' function not found on target.")
				movement_system = null # Invalidate if not found or incorrect

	# Capture mouse
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# Convert pitch limits to radians
	min_pitch_rad = deg_to_rad(min_pitch_degrees)
	max_pitch_rad = deg_to_rad(max_pitch_degrees)

	# Set initial FOV
	fov = base_fov

func _unhandled_input(event):
	# Only rotate camera if mouse is captured and not in targeting mode
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED and not targeting_mode:
		# Adjust yaw and pitch based on relative mouse movement
		camera_yaw -= event.relative.x * mouse_sensitivity_x
		camera_pitch += event.relative.y * mouse_sensitivity_y
		# Clamp pitch
		camera_pitch = clamp(camera_pitch, min_pitch_rad, max_pitch_rad)

func _physics_process(delta):
	if target == null:
		return

	# --- Dynamic FOV Handling ---
	var target_fov = base_fov
	if movement_system and movement_system.is_player_sprinting() and not targeting_mode:
		target_fov += sprint_fov_increase
		
	# Smoothly interpolate FOV
	fov = lerp(fov, target_fov, delta * fov_lerp_speed)
	# ---------------------------

	if targeting_mode and current_target:
		process_targeting_camera(delta)
	else:
		process_free_camera(delta)

func process_free_camera(delta):
	# Calculate camera position based on yaw and pitch (updated by mouse input)
	var cam_rot = Basis()
	cam_rot = cam_rot.rotated(Vector3.UP, camera_yaw)
	cam_rot = cam_rot.rotated(cam_rot.x, camera_pitch)

	# --- Calculate Target Trail Offset --- 
	var target_trail_offset = Vector3.ZERO # The offset we want to reach
	# Ensure target and velocity exist before accessing
	if target and target.has_meta("velocity") or "velocity" in target: # Safer check
		var player_velocity = target.velocity
		player_velocity.y = 0 # Use only horizontal velocity
		var trail_velocity_threshold_sq = 0.1 # Avoid applying offset when nearly still
		if player_velocity.length_squared() > trail_velocity_threshold_sq: 
			target_trail_offset = player_velocity.normalized() * -trail_offset_strength # Negative to trail *behind* movement
	# ----------------------------------
	
	# --- Smoothly Interpolate Trail Offset ---
	current_trail_offset = current_trail_offset.lerp(target_trail_offset, delta * trail_lerp_speed)
	# -----------------------------------------

	# Apply horizontal offset relative to camera's right direction
	var shoulder_offset = cam_rot.x * horizontal_offset
	# --- Incorporate SMOOTHED Trail Offset into Target Position ---
	var base_target_origin = target.global_transform.origin + current_trail_offset # Apply SMOOTHED trail offset
	var target_pos = base_target_origin + Vector3.UP * desired_height + shoulder_offset # Add height and shoulder offset
	# ------------------------------------------------------------

	var cam_dir = -cam_rot.z.normalized()
	var ideal_cam_pos = target_pos + cam_dir * desired_distance # Where camera wants to be without collision
	var target_cam_pos = ideal_cam_pos # Final position after collision check

	# Check for collisions (Uses the modified target_pos)
	var space_state = get_world_3d().direct_space_state
	var ray_params = PhysicsRayQueryParameters3D.new()
	ray_params.from = target_pos # Raycast starts from the offsetted look-at point
	ray_params.to = ideal_cam_pos # Raycast to the ideal position
	ray_params.collision_mask = collision_mask
	ray_params.exclude = [target]

	var collision = space_state.intersect_ray(ray_params)
	if collision:
		# If collision, target position is slightly away from the collision point
		target_cam_pos = collision.position + collision.normal * 0.1 # Small offset from wall
		# Optionally, adjust current_distance based on collision for distance clamping
		current_distance = target_pos.distance_to(target_cam_pos)
	else:
		# If no collision, smoothly adjust current distance towards desired distance
		current_distance = lerp(current_distance, desired_distance, delta * follow_speed)

	# Clamp distance (even if collision adjusted it)
	current_distance = clamp(current_distance, min_distance, max_distance)

	# Ensure target_cam_pos respects the clamped distance if there was no collision (Uses the modified target_pos)
	if !collision:
		target_cam_pos = target_pos + cam_dir * current_distance

	# Make camera position update instantly
	global_transform.origin = target_cam_pos 

	# Always look at the target position (which now includes the trail offset)
	look_at(target_pos, Vector3.UP)

func process_targeting_camera(delta):
	# Reset yaw/pitch when entering targeting mode? Or just stop processing mouse?
	# Current implementation just stops processing mouse via _unhandled_input condition

	if !is_instance_valid(current_target) or !current_target.is_inside_tree():
		set_targeting_mode(false, null)
		return

	# Calculate midpoint between player and target
	var player_pos = target.global_position
	var target_pos = current_target.global_position
	var midpoint = (player_pos + target_pos) * 0.5
	
	# Adjust midpoint height
	midpoint.y += targeting_height
	
	# Calculate direction from target to player
	var direction = (player_pos - target_pos).normalized()
	direction.y = 0
	direction = direction.normalized()
	
	# Position camera behind the player
	var cam_pos = midpoint + direction * targeting_distance
	
	# Check for collision
	var space_state = get_world_3d().direct_space_state
	var ray_params = PhysicsRayQueryParameters3D.new()
	ray_params.from = midpoint
	ray_params.to = cam_pos
	ray_params.collision_mask = collision_mask
	ray_params.exclude = [target]
	
	var collision = space_state.intersect_ray(ray_params)
	if collision:
		cam_pos = collision.position + collision.normal * 0.2
	
	# Smoothly move to targeting camera position
	global_transform.origin = global_transform.origin.lerp(cam_pos, delta * targeting_lerp_speed)
	
	# Look at midpoint
	look_at(midpoint, Vector3.UP)

# Called by the core when targeting is engaged/disengaged
func set_targeting_mode(is_targeting: bool, target_node: Node3D):
	targeting_mode = is_targeting
	current_target = target_node

	# Handle mouse mode change if needed (e.g., show cursor if targeting UI appears)
	# Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if targeting_mode else Input.MOUSE_MODE_CAPTURED)

	if !targeting_mode:
		# When exiting targeting mode, preserve camera orientation
		# This ensures a smooth transition back to free look
		var current_basis = global_transform.basis
		var forward = -current_basis.z
		# Calculate yaw from forward vector (horizontal plane)
		camera_yaw = atan2(forward.x, forward.z)
		# Calculate pitch from forward vector
		camera_pitch = asin(forward.y)
		# Clamp pitch just in case
		camera_pitch = clamp(camera_pitch, min_pitch_rad, max_pitch_rad)
