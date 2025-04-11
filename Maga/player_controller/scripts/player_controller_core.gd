# .----------------------------------------------------------------------------.
# |:::    :::     :::     :::        ::::::::  :::   :::  ::::::::  ::::    :::|
# |:+:    :+:   :+: :+:   :+:       :+:    :+: :+:   :+: :+:    :+: :+:+:   :+:|
# |+:+    +:+  +:+   +:+  +:+       +:+         +:+ +:+  +:+    +:+ :+:+:+  +:+|
# |+#++:++#++ +#++:++#++: +#+       +#+          +#++:   +#+    +:+ +#+ +:+ +#+|
# |+#+    +#+ +#+     +#+ +#+       +#+           +#+    +#+    +#+ +#+  +#+#+#|
# |#+#    #+# #+#     #+# #+#       #+#    #+#    #+#    #+#    #+# #+#   #+#+#|
# |###    ### ###     ### ########## ########     ###     ########  ###    ####|
# '----------------------------------------------------------------------------'
# Player Controller Core
#
# Developed by:
# - Liam Maga
# - 
# - 
# .----------------------------------------------------------------------------.

extends CharacterBody3D

@export_category("Targeting Settings")
@export var target_detection_range := 10.0
@export var target_group := "targetable" # Group name for objects that can be targeted

@export_category("Physics Settings")
@export var gravity := 19.6
@export var jump_strength := 16.0 # Decreased from 18.0 for a smaller jump
@export var rotation_speed := 7.0 # Base speed for player rotation towards look direction (Lowered from 10.0)
@export var moving_rotation_multiplier := 1.2 # Multiplier applied to rotation speed when moving
@export var air_control_factor := 0.4 # How much control the player has while airborne (Lowered from 0.7)
@export var sideways_jump_hindrance := 0.2 # Reduces air control when moving sideways/backwards during jump (0=no hindrance, 1=full stop)
@export var max_step_height := 0.3 # Max height player can step up
@export var step_climb_speed := 8.0 # Vertical speed when stepping up

@export_category("Jump Tuning")
@export var variable_jump_cutoff_multiplier := 0.5 # Multiplies upward velocity when jump button released early
@export var coyote_time_duration := 0.1 # Seconds player can still jump after leaving a platform
@export var jump_buffer_duration := 0.1 # Seconds a jump input is remembered before landing
@export var max_jumps := 2 # Maximum number of jumps allowed (1 = ground, 2 = double, etc.)

@export_category("Node References")
@export var animation_player_path: NodePath # Path to the AnimationPlayer node
@onready var step_detect_ray: RayCast3D = $StepDetectRay
@onready var step_height_ray: RayCast3D = $StepHeightRay
@onready var animation_player: AnimationPlayer = get_node_or_null(animation_player_path) if animation_player_path else null 

# Node References
var character_body: CharacterBody3D # Reference to this node itself
var camera_root: Node3D # Reference to the CameraRoot node
var camera_3d: Camera3D # Reference to the Camera3D node (renamed from camera_node for consistency)
var movement_system: Node # Reference to the MovementSystem script/node
var animation_system: Node # Reference to the new AnimationSystem node
var controller: Node # Reference to the PlayerControllerInputs Autoload
var input_handler: Node # Reference to the InputManager inner class instance

# Targeting State
var current_target: Node3D = null # The currently locked-on target
var is_targeting := false # Flag indicating if targeting mode is active
var potential_targets := [] # List of targets currently within range

# Jump State
var jump_direction := Vector3.FORWARD # Stores the player's look direction at the moment of jumping
var coyote_timer := 0.0 # Timer for coyote time window
var jump_buffer_timer := 0.0 # Timer for jump input buffer
var is_performing_jump := false # Flag to track if currently in the upward phase of a jump (for variable height)
var current_jumps := 0 # Counter for jumps performed since last grounded
var was_on_floor := false # Track floor state for fall detection
var is_attacking := false # ADDED: State flag for attacking
var was_walking_on_floor := false # ADDED: Track previous walking state
var _is_currently_sprinting := false # ADDED: Track sprint state for audio

## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Get references to child nodes and autoloads
	character_body = self # Assign self to character_body
	camera_root = get_node_or_null("CameraRoot") as Node3D # Assign CameraRoot
	camera_3d = get_node_or_null("CameraRoot/Camera3D") as Camera3D # Assign Camera3D (was camera_node)
	movement_system = get_node_or_null("MovementSystem")
	animation_system = get_node_or_null("AnimationSystem") # Get the new node
	controller = get_node_or_null("/root/PlayerControllerInputs")

	# Find the AnimationTree node (ensure it exists in your scene and the path is correct)
	# Note: We are fetching the AnimationTree now, not the AnimationPlayer directly for the system setup.
	var anim_tree = get_node_or_null("AnimationTree") as AnimationTree 
	# Find the AnimationPlayer for validation if needed, but it's not passed to setup anymore
	var anim_player = get_node_or_null(animation_player_path) as AnimationPlayer

	# Validate node references
	if !camera_3d: # Changed from camera_node
		printerr("Player Core: Camera3D node not found at 'CameraRoot/Camera3D'.")
	if !movement_system:
		printerr("Player Core: MovementSystem node not found at 'MovementSystem'.")
	elif movement_system.has_method("setup"):
		movement_system.setup(camera_3d)
	else:
		printerr("Player Core: MovementSystem node does not have a setup() method.")
	
	if !anim_player:
		printerr("Player Core: AnimationPlayer node not found at path: ", animation_player_path)
	
	if !anim_tree: # Validate the AnimationTree node
		printerr("Player Core: AnimationTree node not found (expected name 'AnimationTree'). AnimationSystem setup skipped.")

	if !animation_system:
		printerr("Player Core: AnimationSystem node not found at 'AnimationSystem'.")
	# Pass AnimationTree reference and speeds to the AnimationSystem
	# elif animation_system.has_method("setup"):
	# 	if anim_tree and movement_system: # Ensure both tree and movement system exist
	# 		# Get base speeds - **ADJUST THESE LINES if your speed variables have different names**
	# 		var base_move_speed = movement_system.get("move_speed") if movement_system.has_method("get") else 5.0 # Example: Get speed or use default
	# 		var base_sprint_speed = movement_system.get("sprint_speed") if movement_system.has_method("get") else 8.0 # Example: Get speed or use default
	# 		
	# 		# Check if speeds were successfully retrieved (or handle potential errors)
	# 		if base_move_speed == null:
	# 			printerr("Player Core: Could not get 'move_speed' from MovementSystem. Using default for AnimationSystem.")
	# 			base_move_speed = 5.0 
	# 		if base_sprint_speed == null:
	# 			printerr("Player Core: Could not get 'sprint_speed' from MovementSystem. Using default for AnimationSystem.")
	# 			base_sprint_speed = 8.0

	# 		# Call setup with the correct 3 arguments
	# 		animation_system.setup(anim_tree, base_move_speed, base_sprint_speed) 
	# 	else:
	# 		printerr("Player Core: Cannot setup AnimationSystem because AnimationTree or MovementSystem was not found.")
	# else:
	# 	printerr("Player Core: AnimationSystem node does not have a setup() method.")

	if !controller:
		push_warning("Player Core: PlayerControllerInputs Autoload not found.")

	# Instantiate and add the input handler
	input_handler = InputManager.new(self)
	add_child(input_handler)

	# Validate step raycasts
	if !step_detect_ray:
		printerr("Player Core: StepDetectRay node not found (expected name 'StepDetectRay'). Stepping disabled.")
	if !step_height_ray:
		printerr("Player Core: StepHeightRay node not found (expected name 'StepHeightRay'). Stepping disabled.")

	# Initialize floor state
	was_on_floor = is_on_floor()

	# Check for PlayerControllerInputs autoload
	var controller = get_node_or_null("/root/PlayerControllerInputs")
	if controller:
		input_handler = controller
	else:
		printerr("Player Core: Controller not found at '/root/PlayerControllerInputs'. Setting up dynamic input mappings.")
		setup_dynamic_inputs()
		input_handler = self
	
	# Enhanced Controller Detection
	check_controller_connection()
	
	# Set up custom controller mappings if needed
	setup_custom_controller_mappings()
	
	# Connect to input events for real-time controller detection
	Input.joy_connection_changed.connect(_on_joy_connection_changed)

	if not character_body:
		printerr("Player Core: CharacterBody3D node not found at '" + str(get_path()) + "'.")
	if not camera_root:
		printerr("Player Core: CameraRoot node not found at 'CameraRoot'.")
	if not camera_3d:
		printerr("Player Core: Camera3D node not found at 'CameraRoot/Camera3D'.")

	# Connect animation finished signal IF animation player exists
	if animation_player:
		animation_player.animation_finished.connect(_on_AnimationPlayer_animation_finished)
	else:
		if animation_player_path: # Only warn if path was set but node not found
			printerr("Player Core: Cannot connect animation_finished signal, AnimationPlayer not found at path: ", animation_player_path)

## Called every physics frame. Handles movement, jumping, gravity, and rotation.
func _physics_process(delta: float):
	# --- REMOVED AnimationSystem Check ---
	# if !animation_system or !animation_system.has_method("update_animation"):
	# 	printerr("Player Core: Animation system invalid or missing 'update_animation' method.")
		# Can optionally return here if animations are critical

	# --- Validation for Movement System (Keep) ---
	if !movement_system or !movement_system.has_method("get_movement_input"):
		printerr("Player Core: Movement system invalid or missing 'get_movement_input' method.")
		return 

	# --- ADDED: Check for Attack Input --- (Moved from InputManager._input)
	if Input.is_action_just_pressed("attack"):
		# Only attack if not already attacking and animation player exists
		if not is_attacking and animation_player:
			is_attacking = true # Set attacking state
			# Play the attack animation (Make sure "Sword" is the correct name!)
			animation_player.play("Sword") 
			# Reset speed scale for attack animation
			animation_player.speed_scale = 1.0 
	# -------------------------------------

	# --- Update Timers ---
	if coyote_timer > 0.0:
		coyote_timer -= delta
	if jump_buffer_timer > 0.0:
		jump_buffer_timer -= delta

	# --- Get Movement Input & Floor State (MOVED EARLIER) ---
	var on_floor = is_on_floor()
	var movement_input = movement_system.get_movement_input(delta, is_targeting)
	var target_horizontal_velocity = movement_input["velocity"]
	var look_direction = movement_input["look_direction"]
	var is_sprinting = movement_input["is_sprinting"]
	var is_moving = velocity.length_squared() > 0.1 # Determine is_moving AFTER velocity updates
	_is_currently_sprinting = is_sprinting # Store current sprint state

	# --- Ground State Reset ---
	if on_floor:
		coyote_timer = coyote_time_duration
		is_performing_jump = false
		current_jumps = 0
	else:
		# Detect falling off ledge
		if was_on_floor and velocity.y <= 0:
			if current_jumps == 0:
				current_jumps = 1

	# --- Handle Jump Input Buffering ---
	if Input.is_action_just_pressed("move_jump"):
		jump_buffer_timer = jump_buffer_duration
		
	# --- Check Jump Condition & Execution ---
	if jump_buffer_timer > 0.0:
		var performed_jump_this_frame = false
		
		# Check for ground/coyote jump first
		if on_floor or coyote_timer > 0.0: # Use the 'on_floor' variable determined earlier
			velocity.y = jump_strength
			# Store the horizontal direction faced when jumping (using 'look_direction' determined earlier)
			if look_direction.length_squared() > 0.0001:
				jump_direction = look_direction.normalized()
			else:
				jump_direction = -transform.basis.z if transform.basis.z != Vector3.ZERO else Vector3.FORWARD
			
			current_jumps = 1 # This is the first jump
			is_performing_jump = true
			performed_jump_this_frame = true
			coyote_timer = 0.0 # Consume coyote time if used

		# Check for air jump (if ground/coyote jump didn't happen)
		elif current_jumps < max_jumps: 
			velocity.y = jump_strength
			# Optionally update jump_direction mid-air if desired, but keeping simple for now
			
			current_jumps += 1 # Consume an air jump
			is_performing_jump = true # Reset for variable jump height check
			performed_jump_this_frame = true

		# Consume buffer if any jump was performed
		if performed_jump_this_frame:
			jump_buffer_timer = 0.0

	# --- Variable Jump Height Cutoff ---
	if is_performing_jump and not on_floor and Input.is_action_just_released("move_jump") and velocity.y > 0:
		velocity.y *= variable_jump_cutoff_multiplier
		is_performing_jump = false
	
	# --- Apply Gravity ---
	if not on_floor:
		velocity.y -= gravity * delta

	# --- Apply Air Control & Directional Hindrance ---
	var current_accel = movement_system.acceleration
	var current_decel = movement_system.deceleration
	var effective_air_control = air_control_factor

	if not on_floor:
		# Reduce air control (uses 'target_horizontal_velocity' determined earlier)
		var current_dir = Vector3.ZERO
		if target_horizontal_velocity.length_squared() > 0.0001:
			current_dir = target_horizontal_velocity.normalized()
		
		if current_dir != Vector3.ZERO:
			# Dot product gives alignment: 1 (forward) to -1 (backward)
			var alignment = jump_direction.dot(current_dir)
			# Map alignment to hindrance factor: Lerp between full hindrance (0.0) and no hindrance (1.0)
			# max(0, alignment) treats backward like sideways for hindrance calculation
			var directional_factor = lerp(sideways_jump_hindrance, 1.0, (alignment + 1.0) / 2.0) 
			effective_air_control *= directional_factor
		# If no input (current_dir is ZERO), effective_air_control remains base air_control_factor for deceleration
			
		# Apply the calculated effective air control to acceleration and deceleration
		current_accel *= effective_air_control
		current_decel *= effective_air_control
	else:
		# Reset jump direction when grounded (optional, but ensures clean state)
		jump_direction = -transform.basis.z if transform.basis.z != Vector3.ZERO else Vector3.FORWARD

	# --- Apply Horizontal Velocity (Lerp for smooth acceleration/deceleration) ---
	if target_horizontal_velocity.length_squared() > 0.01: # Check if there is movement input
		velocity.x = lerp(velocity.x, target_horizontal_velocity.x, current_accel * delta)
		velocity.z = lerp(velocity.z, target_horizontal_velocity.z, current_accel * delta)
	else: # No movement input, decelerate
		velocity.x = lerp(velocity.x, 0.0, current_decel * delta)
		velocity.z = lerp(velocity.z, 0.0, current_decel * delta)

	# --- Animation Logic ---
	# Only process movement/idle/jump animations if NOT attacking
	if not is_attacking:
		if animation_player:
			var anim_name = ""
			var anim_speed = 1.0
			
			# Determine animation based on state
			if not on_floor:
				anim_name = "Jump"
				anim_speed = 2.2
			elif is_moving:
				anim_speed = 4.0
				if is_sprinting:
					anim_name = "Run"
				else:
					anim_name = "Walk"
			else: # Idle
				anim_name = "Idle_001"
				anim_speed = 2.2

			# Play the animation and set speed scale
			if anim_name != "" and (not animation_player.is_playing() or animation_player.current_animation != anim_name):
				animation_player.play(anim_name)
				animation_player.speed_scale = anim_speed
			else:
				# Update speed scale if animation is already playing but speed needs change
				if anim_name != "" and animation_player.is_playing() and animation_player.current_animation == anim_name:
					if animation_player.speed_scale != anim_speed:
						animation_player.speed_scale = anim_speed

	# --- Step Up Logic (Before move_and_slide) ---
	var did_step_up = false # Flag to prevent step logic interfering with normal jumping
	if on_floor and step_detect_ray and step_height_ray:
		var horizontal_vel = Vector3(velocity.x, 0, velocity.z)
		if horizontal_vel.length_squared() > 0.01: # Moving horizontally
			var forward_dir = -transform.basis.z.normalized()
			# Check if moving generally forward
			if horizontal_vel.normalized().dot(forward_dir) > 0.5: 
				step_detect_ray.force_raycast_update()
				step_height_ray.force_raycast_update()

				# Check if lower ray hits an obstacle but upper ray doesn't (clear path above step)
				if step_detect_ray.is_colliding() and not step_height_ray.is_colliding():
					var step_collider = step_detect_ray.get_collider()
					# Optional: Add check here if collider.is_in_group("ground") or similar
					if step_collider: 
						var step_hit_point = step_detect_ray.get_collision_point()
						var step_up_amount = step_hit_point.y - global_position.y

						# Ensure step is actually above feet and within max height
						if step_up_amount > 0.01 and step_up_amount <= max_step_height:
							velocity.y = step_climb_speed # Apply upward velocity boost
							did_step_up = true # Mark that we initiated a step

	# --- Apply Movement via move_and_slide ---
	move_and_slide()

	# --- Handle Rotation (Smoothly turn towards look_direction) ---
	if look_direction.length_squared() > 0.0001: # Check if there is a valid look direction
		var current_rotation_speed = rotation_speed
		# Rotate faster when actively moving
		if velocity.length_squared() > 0.1: # Use velocity magnitude to check if moving significantly
			current_rotation_speed *= moving_rotation_multiplier
		
		# Calculate the target transform based on the look direction
		var target_transform = transform.looking_at(global_position + look_direction, Vector3.UP)
		
		# Interpolate the current transform towards the target transform for smooth rotation
		transform = transform.interpolate_with(target_transform, delta * current_rotation_speed)

	# --- Update State for Next Frame ---
	was_on_floor = on_floor

## Called every frame. Handles non-physics updates like targeting UI.
func _process(_delta):
	# Update targeting UI elements if targeting is active
	if is_targeting and current_target:
		update_targeting()

# ============================================================================ #
# region Input Handling (Inner Class)
# ============================================================================ #

## Inner class dedicated to handling player input actions.
class InputManager extends Node:
	var parent: Node # Reference to the PlayerControllerCore instance
	
	## Constructor: Stores the parent reference.
	func _init(p):
		parent = p
	
	## Handles unhandled input events.
	func _input(event):
		# --- REMOVED DEBUG for Mouse Events ---
		# if event is InputEventMouseButton:
		# 	print("InputManager received mouse event: ", event)
		
		# Toggle targeting mode
		if Input.is_action_pressed("target"): # Use Input singleton
			parent.toggle_targeting()
			
		# Trigger interaction via the movement system
		if Input.is_action_pressed("action"): # Use Input singleton
			if parent.movement_system and parent.movement_system.has_method("interact"):
				parent.movement_system.interact()
				
		# --- REMOVED ATTACK HANDLING FROM HERE ---
		# if Input.is_action_just_pressed("attack"):
		# 	print("[DEBUG] Attack action JUST PRESSED")
		# 	print("[DEBUG]   Current InputMap events for 'attack':", InputMap.action_get_events("attack")) 
		# 	print("[DEBUG]   is_attacking before check: ", parent.is_attacking)
		# 	print("[DEBUG]   animation_player valid: ", is_instance_valid(parent.animation_player))
		# 	if not parent.is_attacking and parent.animation_player:
		# 		print("[DEBUG]     Starting attack sequence!")
		# 		parent.is_attacking = true
		# 		parent.animation_player.play("Sword") 
		# 		parent.animation_player.speed_scale = 1.0 
		# 	else:
		# 		if parent.is_attacking:
		# 			print("[DEBUG]     Attack prevented: Already attacking.")
		# 		if not parent.animation_player:
		# 			print("[DEBUG]     Attack prevented: AnimationPlayer is null.")

# ============================================================================ #
# region Targeting System
# ============================================================================ #

## Toggles the targeting state between active and inactive.
func toggle_targeting():
	if is_targeting:
		release_target()
	else:
		acquire_target()

## Attempts to find and lock onto a suitable target.
func acquire_target():
	find_potential_targets() # Refresh the list of nearby targets
	
	if not potential_targets.is_empty():
		# Find the closest target generally in front of the player
		var closest_target: Node3D = null
		var closest_dot = -1.0 # Use dot product for angle check (-1 to 1)
		var player_forward = -transform.basis.z
		
		for target in potential_targets:
			var to_target = (target.global_position - global_position).normalized()
			var dot_product = player_forward.dot(to_target)
			
			# Consider targets within a forward cone (dot > 0.5 is roughly < 60 degrees off center)
			# and closer to the center than the current best candidate
			if dot_product > 0.5 and dot_product > closest_dot:
				closest_target = target
				closest_dot = dot_product
		
		if closest_target:
			# Lock onto the selected target
			current_target = closest_target
			is_targeting = true
			
			# Update UI and subsystems
			if controller and controller.has_method("set_target_icon_position"):
				# Position icon slightly above target's origin
				controller.set_target_icon_position(true, current_target.global_position + Vector3.UP * 1.5)
			
			if camera_3d and camera_3d.has_method("set_targeting_mode"): # Changed from camera_node
				camera_3d.set_targeting_mode(true, current_target) # Changed from camera_node
				
			if movement_system and movement_system.has_method("set_targeting_state"):
				var direction_to_target = (current_target.global_position - global_position)
				direction_to_target.y = 0 # Ignore vertical difference for movement direction
				movement_system.set_targeting_state(true, direction_to_target.normalized())

func release_target():
	is_targeting = false
	current_target = null
	
	# Hide the target icon using the controller
	if controller and controller.has_method("set_target_icon_position"):
		controller.set_target_icon_position(false)
	
	# Notify the camera to return to normal mode
	if camera_3d and camera_3d.has_method("set_targeting_mode"): # Changed from camera_node
		camera_3d.set_targeting_mode(false, null) # Changed from camera_node
		
	# Notify movement system about targeting off
	if movement_system and movement_system.has_method("set_targeting_state"):
		movement_system.set_targeting_state(false, Vector3.ZERO)

func update_targeting():
	# Check if target is still valid
	if !is_instance_valid(current_target) or !current_target.is_inside_tree():
		release_target()
		return
	
	# Check if target is still in range
	var distance = global_position.distance_to(current_target.global_position)
	if distance > target_detection_range * 1.5:
		release_target()
		return
	
	# Update target icon position using the controller
	if controller and controller.has_method("set_target_icon_position"):
		var target_position = current_target.global_position + Vector3.UP * 1.5
		controller.set_target_icon_position(true, target_position)

func find_potential_targets():
	potential_targets.clear()
	
	# Find all nodes in the targetable group
	var targets = get_tree().get_nodes_in_group(target_group)
	
	for target in targets:
		# Make sure target has a position
		if target is Node3D:
			var distance = global_position.distance_to(target.global_position)
			if distance <= target_detection_range:
				potential_targets.append(target)

# Helper function to find a node of a specific script type
func find_child_of_type(node: Node, script_name: String) -> Node:
	for child in node.get_children():
		if child.get_script() and child.get_script().resource_path.find(script_name) != -1:
			return child
		
		var result = find_child_of_type(child, script_name)
		if result:
			return result
	
	return null

# Enhanced Controller Detection
func check_controller_connection() -> void:
	var connected_joypads = Input.get_connected_joypads()
	if connected_joypads.size() > 0:
		print("Controller(s) detected: ", connected_joypads.size())
		for joypad_id in connected_joypads:
			print("Joypad ID: ", joypad_id, " Name: ", Input.get_joy_name(joypad_id))
	else:
		print("No controllers detected. Please connect a controller or use keyboard/mouse.")

func _on_joy_connection_changed(device_id: int, connected: bool) -> void:
	if connected:
		print("Controller connected: ID ", device_id, " Name: ", Input.get_joy_name(device_id))
	else:
		print("Controller disconnected: ID ", device_id)
		# Notify the input autoload system about the disconnection
		if controller and controller.has_method("handle_joy_disconnection"):
			controller.handle_joy_disconnection(device_id)
		else:
			printerr("Player Core: Could not notify PlayerControllerInputs autoload about joy disconnection.")
	# Update the connection status printout regardless
	check_controller_connection()

# Custom Controller Mappings
func setup_custom_controller_mappings() -> void:
	# Example of adding a custom mapping for a specific controller
	# This can be expanded based on specific controller GUIDs and mappings
	var joy_guid = Input.get_joy_guid(0) if Input.get_connected_joypads().size() > 0 else ""
	if joy_guid != "":
		print("Setting up custom mappings for controller: ", joy_guid)
		# Add custom mapping if needed - example placeholder
		# Input.add_joy_mapping("mapping_string_here", true)
		# For now, we'll log that we're checking for custom mappings
		print("Custom controller mapping setup complete for ", Input.get_joy_name(0))

# Enhanced Dynamic Input Setup with Dead Zone Adjustments
func setup_dynamic_inputs() -> void:
	print("WARNING: PlayerControllerCore.setup_dynamic_inputs() called, but this logic is likely superseded by PlayerControllerInputs autoload.")
	var actions = {
		"move_forward": [KEY_W, JOY_BUTTON_DPAD_UP, JOY_AXIS_LEFT_Y, -0.5, 0.2],
		"move_backward": [KEY_S, JOY_BUTTON_DPAD_DOWN, JOY_AXIS_LEFT_Y, 0.5, 0.2],
		"move_left": [KEY_A, JOY_BUTTON_DPAD_LEFT, JOY_AXIS_LEFT_X, -0.5, 0.2],
		"move_right": [KEY_D, JOY_BUTTON_DPAD_RIGHT, JOY_AXIS_LEFT_X, 0.5, 0.2],
		"move_jump": [KEY_SPACE, JOY_BUTTON_A],
		"move_sprint": [KEY_SHIFT, JOY_BUTTON_X],
		"action": [KEY_E, JOY_BUTTON_B],
		"target": [KEY_TAB, JOY_BUTTON_Y],
		# --- ADDED: Attack Action --- 
		"attack": [MOUSE_BUTTON_LEFT, JOY_BUTTON_RIGHT_SHOULDER], # LMB / R1/RB
		# ---------------------------
		"ui_up": [KEY_UP, JOY_BUTTON_DPAD_UP, JOY_AXIS_LEFT_Y, -0.5, 0.2],
		"ui_down": [KEY_DOWN, JOY_BUTTON_DPAD_DOWN, JOY_AXIS_LEFT_Y, 0.5, 0.2],
		"ui_left": [KEY_LEFT, JOY_BUTTON_DPAD_LEFT, JOY_AXIS_LEFT_X, -0.5, 0.2],
		"ui_right": [KEY_RIGHT, JOY_BUTTON_DPAD_RIGHT, JOY_AXIS_LEFT_X, 0.5, 0.2],
		"ui_accept": [KEY_ENTER, JOY_BUTTON_A],
		"ui_cancel": [KEY_ESCAPE, JOY_BUTTON_B],
		# Add camera controls
		"camera_left": [null, null, JOY_AXIS_RIGHT_X, -0.5, 0.2], # Map right stick X negative
		"camera_right": [null, null, JOY_AXIS_RIGHT_X, 0.5, 0.2], # Map right stick X positive
		"camera_up": [null, null, JOY_AXIS_RIGHT_Y, -0.5, 0.2],   # Map right stick Y negative
		"camera_down": [null, null, JOY_AXIS_RIGHT_Y, 0.5, 0.2]    # Map right stick Y positive
	}

	for action_name in actions.keys():
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
			# Set deadzone only if it's defined (actions[action_name].size() > 4)
			if actions[action_name].size() > 4 and actions[action_name][4] != null:
				InputMap.action_set_deadzone(action_name, actions[action_name][4])

		var events = InputMap.action_get_events(action_name)
		var has_keyboard = false
		var has_joypad_button = false
		var has_joypad_axis = false
		var has_mouse_button = false # ADDED: Check for mouse buttons
		for event in events:
			if event is InputEventKey:
				has_keyboard = true
			elif event is InputEventJoypadButton:
				has_joypad_button = true
			elif event is InputEventJoypadMotion:
				has_joypad_axis = true
			elif event is InputEventMouseButton: # ADDED
				has_mouse_button = true # ADDED

		# Determine potential mapping types from the definition array
		var key_defined = actions[action_name].size() > 0 and actions[action_name][0] != null
		var joy_button_defined = actions[action_name].size() > 1 and actions[action_name][1] != null
		var joy_axis_defined = actions[action_name].size() > 3 and actions[action_name][2] != null
		# ADDED: Check if the first element *could* be a mouse button (integer check)
		var mouse_button_defined = key_defined and actions[action_name][0] is int and actions[action_name][0] >= MOUSE_BUTTON_LEFT and actions[action_name][0] <= MOUSE_BUTTON_XBUTTON2

		# Add Keyboard event if missing and defined (and not intended as mouse button)
		if not has_keyboard and key_defined and not mouse_button_defined:
			var key_event = InputEventKey.new()
			key_event.keycode = actions[action_name][0]
			InputMap.action_add_event(action_name, key_event)

		# ADDED: Add Mouse Button event if missing and defined
		if not has_mouse_button and mouse_button_defined:
			# REMOVED DEBUG Print
			var mouse_event = InputEventMouseButton.new()
			mouse_event.button_index = actions[action_name][0]
			InputMap.action_add_event(action_name, mouse_event)

		# Add Joypad Button event if missing and defined
		if not has_joypad_button and joy_button_defined:
			var joy_event = InputEventJoypadButton.new()
			joy_event.button_index = actions[action_name][1]
			InputMap.action_add_event(action_name, joy_event)

		# Add Joypad Axis event if missing and defined
		if not has_joypad_axis and actions[action_name].size() > 3 and actions[action_name][2] != null:
			var axis_event = InputEventJoypadMotion.new()
			axis_event.axis = actions[action_name][2]
			axis_event.axis_value = actions[action_name][3]
			InputMap.action_add_event(action_name, axis_event)

	print("Dynamic input mappings including camera controls and custom dead zones have been set up.")

# ============================================================================ #
# region Signal Handlers & Helpers
# ============================================================================ #

# ADDED: Function to handle animation finishing
func _on_AnimationPlayer_animation_finished(anim_name: StringName) -> void:
	# If the attack animation finished, reset the state
	if anim_name == "Sword": # Make sure "Sword" matches the animation name
		is_attacking = false

func get_jump_strength() -> float:
	return jump_strength

# ADDED: Helper function for audio script to check sprint state
func is_currently_sprinting() -> bool:
	return _is_currently_sprinting
