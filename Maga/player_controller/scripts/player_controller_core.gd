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
@export var jump_strength := 15.0 # Lowered from 20.0
@export var rotation_speed := 7.0 # Base speed for player rotation towards look direction (Lowered from 10.0)
@export var moving_rotation_multiplier := 1.2 # Multiplier applied to rotation speed when moving
@export var air_control_factor := 0.4 # How much control the player has while airborne (Lowered from 0.7)
@export var sideways_jump_hindrance := 0.2 # Reduces air control when moving sideways/backwards during jump (0=no hindrance, 1=full stop)

@export_category("Jump Tuning")
@export var variable_jump_cutoff_multiplier := 0.5 # Multiplies upward velocity when jump button released early
@export var coyote_time_duration := 0.1 # Seconds player can still jump after leaving a platform
@export var jump_buffer_duration := 0.1 # Seconds a jump input is remembered before landing

# Node References
var camera_node: Camera3D
var movement_system: Node # Reference to the MovementSystem script/node
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

## Called when the node enters the scene tree for the first time.
func _ready():
	# Get references to child nodes and autoloads
	camera_node = get_node_or_null("CameraRoot/Camera3D") as Camera3D
	movement_system = get_node_or_null("MovementSystem")
	controller = get_node_or_null("/root/PlayerControllerInputs")

	# Validate node references
	if !camera_node:
		printerr("Player Core: Camera3D node not found at 'CameraRoot/Camera3D'.")
	if !movement_system:
		printerr("Player Core: MovementSystem node not found at 'MovementSystem'.")
	# Pass camera reference to movement system if both exist and method is available
	elif movement_system.has_method("setup"):
		movement_system.setup(camera_node)
	else:
		printerr("Player Core: MovementSystem node does not have a setup() method.")
	
	if !controller:
		push_warning("Player Core: PlayerControllerInputs Autoload not found.")

	# Instantiate and add the input handler
	input_handler = InputManager.new(self)
	add_child(input_handler)

## Called every physics frame. Handles movement, jumping, gravity, and rotation.
func _physics_process(delta: float):
	# Ensure movement system is valid before proceeding
	if !movement_system or !movement_system.has_method("get_movement_input"):
		printerr("Player Core: Movement system invalid or missing 'get_movement_input' method.")
		return

	# --- Update Timers ---
	if coyote_timer > 0.0:
		coyote_timer -= delta
	if jump_buffer_timer > 0.0:
		jump_buffer_timer -= delta

	# --- Get Movement Input ---
	# This is needed early for jump direction calculation
	var movement_input = movement_system.get_movement_input(delta, is_targeting)
	var target_horizontal_velocity = movement_input["velocity"] # Desired velocity based on input
	var look_direction = movement_input["look_direction"] # Desired facing direction

	# --- Ground Check & Coyote Time ---
	var on_floor = is_on_floor()
	if on_floor:
		coyote_timer = coyote_time_duration # Reset coyote timer when grounded
		is_performing_jump = false # Reset jump state flags when grounded
	# Coyote timer naturally decreases when not on floor

	# --- Handle Jump Input Buffering ---
	if Input.is_action_just_pressed("move_jump"):
		jump_buffer_timer = jump_buffer_duration
		
	# --- Check Jump Condition (Requires buffered input and coyote time window) ---
	var can_jump = jump_buffer_timer > 0.0 and coyote_timer > 0.0
	
	if can_jump:
		velocity.y = jump_strength
		# Store the horizontal direction faced when jumping for air control calculation
		if look_direction.length_squared() > 0.0001: # Avoid normalizing zero vector
			jump_direction = look_direction.normalized()
		else:
			# Fallback if look_direction is zero (e.g., standing still)
			jump_direction = -transform.basis.z if transform.basis.z != Vector3.ZERO else Vector3.FORWARD
		
		# Consume timers and set jump state
		jump_buffer_timer = 0.0 
		coyote_timer = 0.0 
		is_performing_jump = true

	# --- Variable Jump Height Cutoff ---
	# If jump button is released early while still moving upwards, reduce upward velocity
	if is_performing_jump and not on_floor and Input.is_action_just_released("move_jump") and velocity.y > 0:
		velocity.y *= variable_jump_cutoff_multiplier
		is_performing_jump = false # Cutoff applied, stop checking for this jump
	
	# --- Apply Gravity ---
	if not on_floor:
		velocity.y -= gravity * delta

	# --- Apply Air Control & Directional Hindrance ---
	var current_accel = movement_system.acceleration
	var current_decel = movement_system.deceleration
	var effective_air_control = air_control_factor # Start with base air control

	if not on_floor:
		# Reduce air control if moving sideways or backwards relative to the jump direction
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
		# Toggle targeting mode
		if event.is_action_pressed("target"):
			parent.toggle_targeting()
			
		# Trigger interaction via the movement system
		if event.is_action_pressed("action"):
			if parent.movement_system and parent.movement_system.has_method("interact"):
				parent.movement_system.interact()

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
			
			if camera_node and camera_node.has_method("set_targeting_mode"):
				camera_node.set_targeting_mode(true, current_target)
				
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
	if camera_node and camera_node.has_method("set_targeting_mode"):
		camera_node.set_targeting_mode(false, null)
		
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
