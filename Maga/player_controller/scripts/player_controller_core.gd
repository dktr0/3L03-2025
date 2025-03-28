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

@export_category("Component Paths")
@export var camera_path: NodePath
@export var movement_system_path: NodePath

@export_category("Targeting Settings")
@export var target_detection_range := 10.0
@export var target_group := "targetable"

var camera_node: Camera3D
var movement_system: Node
var controller: Node
var input_handler: Node

# Targeting variables (moved from targeting system)
var current_target: Node3D = null
var is_targeting := false
var potential_targets := []

func _ready():
	# Get camera reference
	if camera_path:
		camera_node = get_node(camera_path)
	
	# Get movement system reference
	if movement_system_path:
		movement_system = get_node(movement_system_path)
		if movement_system and camera_node:
			movement_system.setup(camera_node)
	
	# Get controller reference from AutoLoad
	controller = get_node("/root/PlayerController")
	
	# Connect to the input handler for interaction
	input_handler = InputManager.new(self)
	add_child(input_handler)

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
			if movement_system and movement_system.has_method("set_targeting_direction"):
				var direction = (current_target.global_position - global_position)
				direction.y = 0
				direction = direction.normalized()
				movement_system.set_targeting_direction(direction, true)

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
	if movement_system and movement_system.has_method("set_targeting_direction"):
		movement_system.set_targeting_direction(Vector3.ZERO, false)

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
	
	# Update movement direction for targeting
	if movement_system and movement_system.has_method("set_targeting_direction"):
		var direction = (current_target.global_position - global_position)
		direction.y = 0
		direction = direction.normalized()
		movement_system.set_targeting_direction(direction, true)

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
