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
@export var follow_speed := 5.0 # Speed at which camera distance interpolates
@export var mouse_sensitivity_x := 0.003 # Sensitivity for horizontal mouse look
@export var mouse_sensitivity_y := 0.003 # Sensitivity for vertical mouse look
@export var min_distance := 1.0 # Minimum distance camera can be from target
@export var max_distance := 6.0 # Maximum distance camera can be from target
@export var desired_distance := 2.8 # Default distance camera tries to maintain
@export var desired_height := 1.8 # Vertical offset from target pivot
@export var targeting_height := 1.5 # Vertical offset during targeting mode
@export var targeting_distance := 4.0 # Distance from midpoint during targeting
@export var targeting_lerp_speed := 8.0 # Speed of interpolation when entering/exiting targeting mode
@export var collision_mask := 1 # Physics layer the camera collides with
@export var target_path: NodePath # Path to the node the camera follows (usually the player)
@export var min_pitch_degrees := -60.0 # Minimum vertical look angle
@export var max_pitch_degrees := 75.0 # Maximum vertical look angle
@export var horizontal_offset := 0.0 # Horizontal offset for over-the-shoulder view
@export var base_fov := 75.0 # Default field of view
@export var sprint_fov_increase := 10.0 # Amount FOV increases when sprinting
@export var fov_lerp_speed := 6.0 # Speed of FOV transitions
@export var trail_offset_strength := 0.3 # How far the camera trails behind player movement
@export var trail_lerp_speed := 5.0 # Speed at which the trail offset adapts

@export_category("Gamepad Settings") # Added category for clarity
@export var gamepad_sensitivity_x := 2.0 # Sensitivity for horizontal gamepad stick look (Increased from 1.5)
@export var gamepad_sensitivity_y := 2.0 # Sensitivity for vertical gamepad stick look (Increased from 1.5)
@export var gamepad_invert_y := true # Invert vertical gamepad look direction?
@export var controller_smoothing := 10.0 # How quickly rotation accelerates (higher = faster)
@export var controller_resistance := 15.0 # How quickly rotation decelerates (higher = faster stop)

# Node References
var target: Node3D
var movement_system: Node # Reference to MovementSystem for sprint status
var player_controller: Node = null # Reference to PlayerControllerInputs Autoload
var cursor_manager = null # Reference to CursorManager Autoload

# Camera State
var camera_pitch := 0.0 # Current vertical rotation in radians
var camera_yaw := 0.0 # Current horizontal rotation in radians
var current_distance := desired_distance # Current actual distance from target
var current_trail_offset := Vector3.ZERO # Smoothly interpolated trail offset
var rotation_velocity := Vector2.ZERO # For smoothed gamepad rotation

# Targeting State
var targeting_mode := false
var current_target: Node3D = null

# Pre-calculated values
var min_pitch_rad: float
var max_pitch_rad: float

# Parent Node for smoothing
var camera_root: Node3D

## Called when the node enters the scene tree for the first time.
func _ready():
	# Get Parent Node (CameraRoot)
	camera_root = get_parent() as Node3D
	if !camera_root:
		printerr("Camera: Parent node is not a Node3D or not found. Smoothing may not work.")

	# Get Autoload references
	player_controller = get_node_or_null("/root/PlayerControllerInputs")
	cursor_manager = get_node_or_null("/root/Cursor")

	if !player_controller:
		printerr("Camera: PlayerControllerInputs Autoload not found!")
		# Default to KBM if autoload fails, and ensure mouse is captured
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	else:
		# Connect to input scheme changes
		player_controller.input_scheme_changed.connect(_on_input_scheme_changed)
		# Set initial cursor state based on the current input scheme
		_on_input_scheme_changed(player_controller.current_input_scheme)

	# Get the target node (player) based on the exported path
	if target_path:
		target = get_node(target_path)
		if !target:
			printerr("Camera: Target node not found at path: ", target_path)
		else:
			# Get reference to the movement system from the target (Player)
			movement_system = target.get_node_or_null("MovementSystem")
			if !movement_system or !movement_system.has_method("is_player_sprinting"):
				printerr("Camera: MovementSystem node or 'is_player_sprinting' method not found on target.")
				movement_system = null # Invalidate reference if not found or method missing

	# Convert degree limits to radians for internal calculations
	min_pitch_rad = deg_to_rad(min_pitch_degrees)
	max_pitch_rad = deg_to_rad(max_pitch_degrees)

	# Set initial camera properties
	fov = base_fov
	current_distance = desired_distance # Initialize distance

## Handles input events, primarily for mouse look.
func _input(event: InputEvent):
	# Ensure player_controller exists
	if not player_controller:
		return

	# Check the scheme from the autoload
	var current_scheme = player_controller.current_input_scheme

	# --- MOUSE INPUT --- 
	# Process only if scheme is KBM
	if current_scheme == player_controller.InputScheme.KEYBOARD_MOUSE:
		# If CursorManager wants the cursor visible (e.g., for UI), don't process camera input
		# Also check if targeting mode is active, as mouse look might be disabled then.
		if (cursor_manager and cursor_manager.is_cursor_visible) or targeting_mode:
			return

		# Process mouse motion for camera rotation if cursor is captured
		if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			# We apply sensitivity directly here
			camera_yaw -= event.relative.x * mouse_sensitivity_x
			camera_pitch += event.relative.y * mouse_sensitivity_y
			# Clamp vertical angle immediately
			camera_pitch = clamp(camera_pitch, min_pitch_rad, max_pitch_rad)

## Called every physics frame. Handles camera positioning, rotation, collision, and FOV.
func _physics_process(delta):
	if target == null or player_controller == null: # Don't process if target or controller autoload is invalid
		return
	
	# --- DIAGNOSTIC PRINT --- 
	if targeting_mode:
		print("DEBUG: Targeting Mode ACTIVE")
	# ----------------------

	# --- Get Current Input Scheme --- 
	var current_input_scheme = player_controller.current_input_scheme
	
	# --- Reset rotation velocity if not using gamepad --- 
	# Prevents leftover velocity if switching schemes
	if current_input_scheme != player_controller.InputScheme.GAMEPAD:
		rotation_velocity = Vector2.ZERO
	
	# --- GAMEPAD CAMERA ROTATION (Smoothed - Refined) --- 
	if current_input_scheme == player_controller.InputScheme.GAMEPAD and not targeting_mode:
		# Use InputMap actions directly
		var cam_axis_x = Input.get_axis("camera_left", "camera_right") 
		var cam_axis_y = Input.get_axis("camera_up", "camera_down") 
		var input_vector = Vector2(cam_axis_x, cam_axis_y)
		
		# Invert Y axis input if needed
		var processed_cam_axis_y = -cam_axis_y if gamepad_invert_y else cam_axis_y
		
		# Check if there's significant input AFTER deadzone is applied by get_axis
		if input_vector.length_squared() > 0.01: # Threshold slightly above zero 
			# Calculate target velocity based on input and sensitivity
			var target_velocity = Vector2(cam_axis_x * gamepad_sensitivity_x, processed_cam_axis_y * gamepad_sensitivity_y)
			# Lerp current velocity towards target velocity (acceleration)
			rotation_velocity = rotation_velocity.lerp(target_velocity, delta * controller_smoothing)
		else:
			# No significant input, apply resistance (decelerate towards zero)
			rotation_velocity = rotation_velocity.lerp(Vector2.ZERO, delta * controller_resistance)
		
		# Apply the smoothed velocity to the yaw and pitch
		# Check magnitude again to avoid tiny movements when velocity is near zero
		if rotation_velocity.length_squared() > 0.0001:
			camera_yaw -= rotation_velocity.x * delta 
			camera_pitch += rotation_velocity.y * delta # Use += because Y axis is already processed for inversion
			
			# Clamp vertical angle immediately after applying pitch change
			camera_pitch = clamp(camera_pitch, min_pitch_rad, max_pitch_rad)
		
	# --- Note: Mouse rotation is handled in _input based on events --- 

	# --- Dynamic FOV Handling ---
	var target_fov = base_fov
	# Increase FOV if player is sprinting (and movement system is valid)
	if movement_system and movement_system.is_player_sprinting() and not targeting_mode:
		target_fov += sprint_fov_increase
		
	# Smoothly interpolate FOV towards the target value
	fov = lerp(fov, target_fov, delta * fov_lerp_speed)

	# --- Process Camera Logic based on Mode ---
	if targeting_mode and current_target:
		process_targeting_camera(delta)
	else:
		process_free_camera(delta)

## Calculates and applies camera position/rotation for free-look mode.
func process_free_camera(delta):
	# Calculate camera rotation basis from yaw and pitch
	var cam_rot = Basis()
	cam_rot = cam_rot.rotated(Vector3.UP, camera_yaw)
	cam_rot = cam_rot.rotated(cam_rot.x, camera_pitch)

	# --- Calculate Target Trail Offset --- 
	var target_trail_offset = Vector3.ZERO # The desired offset based on player velocity
	# Check target validity and if it has velocity data
	if target and (target.has_meta("velocity") or "velocity" in target): # Safer check for velocity property
		var player_velocity = target.velocity
		player_velocity.y = 0 # Only consider horizontal velocity for trailing effect
		# Apply offset only if player is moving significantly
		var trail_velocity_threshold_sq = 0.1 
		if player_velocity.length_squared() > trail_velocity_threshold_sq: 
			# Offset trails behind the direction of movement
			target_trail_offset = player_velocity.normalized() * -trail_offset_strength 
	
	# --- Smoothly Interpolate Trail Offset --- 
	current_trail_offset = current_trail_offset.lerp(target_trail_offset, delta * trail_lerp_speed)

	# --- Calculate Camera Target Position --- 
	# Apply horizontal (shoulder) offset relative to camera's right direction
	var shoulder_offset = cam_rot.x * horizontal_offset
	# Base target position includes the smooth trail offset
	var base_target_origin = target.global_transform.origin + current_trail_offset 
	# Final target position includes height and shoulder offset
	var camera_lookat_pos = base_target_origin + Vector3.UP * desired_height + shoulder_offset 

	# --- Calculate Ideal Camera Position --- 
	var cam_dir = -cam_rot.z.normalized() # Camera's backward direction
	var ideal_cam_pos = camera_lookat_pos + cam_dir * desired_distance # Position without collision
	var final_cam_pos = ideal_cam_pos # Assume no collision initially

	# --- Collision Check --- 
	var space_state = get_world_3d().direct_space_state
	var ray_params = PhysicsRayQueryParameters3D.new()
	ray_params.from = camera_lookat_pos # Start ray from where the camera looks
	ray_params.to = ideal_cam_pos # Cast towards the ideal position
	ray_params.collision_mask = collision_mask
	ray_params.exclude = [target] # Exclude the player itself

	var collision = space_state.intersect_ray(ray_params)
	# --- Restore Original Collision Logic ---
	if collision:
		# If collision, move camera slightly away from the collision point
		final_cam_pos = collision.position + collision.normal * 0.1 
		# Update current distance based on collision for clamping
		current_distance = camera_lookat_pos.distance_to(final_cam_pos)
	else:
		# If no collision, smoothly interpolate distance towards the desired value
		current_distance = lerp(current_distance, desired_distance, delta * follow_speed)
	# --- End of Restoration ---
	
	# Clamp the distance within min/max bounds (keep this)
	current_distance = clamp(current_distance, min_distance, max_distance)

	# Recalculate final position using clamped distance if no collision occurred
	# (This check might be redundant now but harmless to keep)
	if not collision:
		final_cam_pos = camera_lookat_pos + cam_dir * current_distance

	# --- Apply Camera Transform --- 
	# Set the parent (CameraRoot) transform, the Camera3D will smooth towards it
	if camera_root:
		var target_transform = Transform3D(Basis(), final_cam_pos).looking_at(camera_lookat_pos, Vector3.UP)
		camera_root.global_transform = target_transform
	else:
		# Fallback if root not found (direct positioning, no smoothing)
		global_transform.origin = final_cam_pos 
		look_at(camera_lookat_pos, Vector3.UP)

## Calculates and applies camera position/rotation for targeting mode.
func process_targeting_camera(delta):
	# Validate the current target
	if !is_instance_valid(current_target) or !current_target.is_inside_tree():
		# If target is invalid, exit targeting mode
		set_targeting_mode(false, null) 
		return

	# --- Calculate Camera Position --- 
	var player_pos = target.global_position
	var target_pos = current_target.global_position
	var midpoint = (player_pos + target_pos) * 0.5 # Point between player and target
	midpoint.y += targeting_height # Adjust height
	
	# Direction from target towards player (horizontal only)
	var direction = (player_pos - target_pos)
	direction.y = 0
	direction = direction.normalized()
	
	# Ideal position behind the player, looking towards the midpoint
	var ideal_cam_pos = midpoint + direction * targeting_distance
	var final_cam_pos = ideal_cam_pos # Assume no collision initially
	
	# --- Collision Check --- 
	var space_state = get_world_3d().direct_space_state
	var ray_params = PhysicsRayQueryParameters3D.new()
	ray_params.from = midpoint # Start ray from the look-at point
	ray_params.to = ideal_cam_pos # Cast towards ideal position
	ray_params.collision_mask = collision_mask
	ray_params.exclude = [target, current_target] # Exclude player and target

	var collision = space_state.intersect_ray(ray_params)
	if collision:
		# If collision, move camera slightly away from the collision point
		final_cam_pos = collision.position + collision.normal * 0.1 
		# Update current distance based on collision for clamping
		current_distance = midpoint.distance_to(final_cam_pos)
	else:
		# If no collision, smoothly interpolate distance towards the desired value
		current_distance = lerp(current_distance, desired_distance, delta * targeting_lerp_speed)

	# Clamp the distance within min/max bounds
	current_distance = clamp(current_distance, min_distance, max_distance)

	# Recalculate final position using clamped distance if no collision occurred
	if !collision:
		final_cam_pos = midpoint + direction * current_distance

	# --- Apply Camera Transform --- 
	# Set the parent (CameraRoot) transform, the Camera3D will smooth towards it
	if camera_root:
		var target_transform = Transform3D(Basis(), final_cam_pos).looking_at(midpoint, Vector3.UP)
		camera_root.global_transform = target_transform
	else:
		# Fallback if root not found (direct positioning, no smoothing)
		global_transform.origin = final_cam_pos
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

# --- Signal Receiver --- 
func _on_input_scheme_changed(scheme):
	if cursor_manager:
		if scheme == player_controller.InputScheme.GAMEPAD:
			cursor_manager.hide_cursor()
			Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN) # Hide OS cursor too
		else:
			cursor_manager.show_cursor() # Show game cursor
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED) # Capture for KBM look
	else:
		# Fallback if CursorManager is not found
		if scheme == (player_controller.InputScheme.GAMEPAD if player_controller else 1):
			Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
