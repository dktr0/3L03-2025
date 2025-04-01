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

# Core script that manages and coordinates all player controller components

# --- REMOVED EXPORTED PATHS ---
# @export_category("Component Paths")
# @export var camera_path: NodePath
# @export var movement_system_path: NodePath

@export_category("Targeting Settings")
@export var target_detection_range := 10.0
@export var target_group := "targetable"

@export_category("Physics Settings")
@export var gravity := 9.8
@export var jump_strength := 5.0
@export var rotation_speed := 10.0 # Base rotation speed
@export var moving_rotation_multiplier := 1.2 # Faster turn when moving
@export var air_control_factor := 0.7 # Increased air control
@export var sideways_jump_hindrance := 0.2 # Multiplier for air control when jumping sideways/backwards (0=none, 1=full)

var camera_node: Camera3D
var movement_system: Node # Keep reference to the movement system node
var controller: Node
var input_handler: Node

# Targeting variables
var current_target: Node3D = null
var is_targeting := false
var potential_targets := []

# Jump state variable
var jump_direction := Vector3.FORWARD # Store the look direction at the moment of jump

func _ready():
	# Get component references using node paths/names from player.tscn
	camera_node = get_node_or_null("CameraRoot/Camera3D") as Camera3D
	movement_system = get_node_or_null("MovementSystem")

	# Check if nodes were found
	if !camera_node:
		printerr("Player Core: Camera3D node not found at 'CameraRoot/Camera3D'.")
	if !movement_system:
		printerr("Player Core: MovementSystem node not found at 'MovementSystem'.")
	# Pass camera reference to movement system if both exist
	elif movement_system.has_method("setup"):
		movement_system.setup(camera_node)
	else:
		printerr("Player Core: MovementSystem node does not have a setup() method.")

	# Get controller reference from AutoLoad
	controller = get_node_or_null("/root/PlayerController")
	if !controller:
		push_warning("Player Core: PlayerController Autoload not found.")

	# Connect to the input handler for interaction
	input_handler = InputManager.new(self)
	add_child(input_handler)

# Central physics loop
func _physics_process(delta: float):
	# Ensure movement system is valid and has the method we need
	if !movement_system or !movement_system.has_method("get_movement_input"):
		printerr("Player Core: Movement system invalid or missing 'get_movement_input' method.")
		return

	# --- Get Movement Input First (needed for jump direction) ---
	var movement_input = movement_system.get_movement_input(delta, is_targeting)
	var target_horizontal_velocity = movement_input["velocity"] # Raw target velocity based on input
	var look_direction = movement_input["look_direction"] # Direction player should face

	# --- Apply Gravity ---
	var on_floor = is_on_floor()
	if not on_floor:
		velocity.y -= gravity * delta

	# --- Handle Jump ---
	if Input.is_action_just_pressed("move_jump") and on_floor:
		velocity.y = jump_strength
		# Store the look direction when jump starts
		jump_direction = look_direction.normalized()
		# Ensure jump_direction is never zero if look_direction was zero
		if jump_direction == Vector3.ZERO:
			jump_direction = global_transform.basis.z # Fallback to player's current forward

	# --- Apply Air Control & Directional Hindrance ---
	var current_accel = movement_system.acceleration
	var current_decel = movement_system.deceleration
	var effective_air_control = air_control_factor # Base air control

	if not on_floor:
		# Calculate directional hindrance factor based on alignment with jump direction
		var current_dir = Vector3.ZERO
		if target_horizontal_velocity.length_squared() > 0.0001: # Use small threshold to avoid normalizing zero vector
			current_dir = target_horizontal_velocity.normalized()
		
		if current_dir != Vector3.ZERO:
			# Dot product: 1 if aligned with jump, 0 if perpendicular, -1 if opposite
			var alignment = jump_direction.dot(current_dir)
			# Map alignment (-1 to 1) to hindrance factor (sideways_jump_hindrance to 1.0)
			# Using max(0, alignment) makes backward jumps treated like sideways jumps
			var directional_factor = lerp(sideways_jump_hindrance, 1.0, max(0.0, alignment))
			effective_air_control *= directional_factor
		else:
			# If no input, apply full base air control for deceleration
			pass # effective_air_control remains air_control_factor
			
		# Apply the final effective air control to accel/decel
		current_accel *= effective_air_control
		current_decel *= effective_air_control
	else:
		# Reset jump direction when grounded (optional, but clean)
		jump_direction = Vector3.FORWARD

	# --- Apply Horizontal Velocity (using lerp for accel/decel) ---
	if target_horizontal_velocity.length_squared() > 0.01:
		velocity.x = lerp(velocity.x, target_horizontal_velocity.x, current_accel * delta)
		velocity.z = lerp(velocity.z, target_horizontal_velocity.z, current_accel * delta)
	else:
		velocity.x = lerp(velocity.x, 0.0, current_decel * delta)
		velocity.z = lerp(velocity.z, 0.0, current_decel * delta)

	# --- Apply Movement ---
	move_and_slide()

	# --- Handle Rotation ---
	if look_direction != Vector3.ZERO:
		var current_rotation_speed = rotation_speed
		if velocity.length_squared() > 0.1:
			current_rotation_speed *= moving_rotation_multiplier
		
		var target_transform = transform.looking_at(global_position + look_direction, Vector3.UP)
		transform = transform.interpolate_with(target_transform, delta * current_rotation_speed)

func _process(_delta):
	# Handle targeting system update
	if is_targeting and current_target:
		update_targeting()

# Input handler inner class to isolate input handling
class InputManager extends Node:
	var parent: Node
	
	func _init(p):
		parent = p
	
	func _input(event):
		if event.is_action_pressed("target"):
			parent.toggle_targeting()
			
		if event.is_action_pressed("action"):
			if parent.movement_system and parent.movement_system.has_method("interact"):
				parent.movement_system.interact()

# Targeting system functions (moved from targeting_system.gd)
func toggle_targeting():
	if is_targeting:
		release_target()
	else:
		acquire_target()

func acquire_target():
	find_potential_targets()
	
	if potential_targets.size() > 0:
		# Find closest target in front of player
		var closest_target = null
		var closest_dot = -1.0
		var player_forward = -transform.basis.z
		
		for target in potential_targets:
			var to_target = (target.global_position - global_position).normalized()
			var dot_product = player_forward.dot(to_target)
			
			# Only consider targets in front of player (within ~120 degree cone)
			if dot_product > 0.5 and dot_product > closest_dot:
				closest_target = target
				closest_dot = dot_product
		
		if closest_target:
			current_target = closest_target
			is_targeting = true
			
			# Use the controller to show and position the target icon
			if controller and controller.has_method("set_target_icon_position"):
				controller.set_target_icon_position(true, current_target.global_position + Vector3.UP * 1.5)
			
			# Notify the camera to adjust behavior for targeting mode
			if camera_node and camera_node.has_method("set_targeting_mode"):
				camera_node.set_targeting_mode(true, current_target)
				
			# Notify movement system about targeting
			if movement_system and movement_system.has_method("set_targeting_state"):
				var direction = (current_target.global_position - global_position)
				direction.y = 0
				direction = direction.normalized()
				movement_system.set_targeting_state(true, direction)

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
