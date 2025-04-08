# .----------------------------------------------------------------------------.
# |:::    :::     :::     :::        ::::::::  :::   :::  ::::::::  ::::    :::|
# |:+:    :+:   :+: :+:   :+:       :+:    :+: :+:   :+: :+:    :+: :+:+:   :+:|
# |+:+    +:+  +:+   +:+  +:+       +:+         +:+ +:+  +:+    +:+ :+:+:+  +:+|
# |+#++:++#++ +#++:++#++: +#+       +#+          +#++:   +#+    +:+ +#+ +:+ +#+|
# |+#+    +#+ +#+     +#+ +#+       +#+           +#+    +#+    +#+ +#+  +#+#+#|
# |#+#    #+# #+#     #+# #+#       #+#    #+#    #+#    #+#    #+# #+#   #+#+#|
# |###    ### ###     ### ########## ########     ###     ########  ###    ####|
# '----------------------------------------------------------------------------'
# Player Controller Animations
#
# Developed by:
# - Liam Maga
# - 
# - 
# .----------------------------------------------------------------------------.

extends Node

# Assign the AnimationTree node from your player scene in the Godot Inspector.
@export var animation_tree: AnimationTree

# Parameters expected to exist within the AnimationTree resource.
# Adjust these paths based on your actual AnimationTree setup.
const SPEED_PARAM = "parameters/MovementBlend/blend_position" # Path to BlendSpace1D blend_position
const ON_FLOOR_PARAM = "parameters/Conditions/is_on_floor"   # Path to StateMachine condition/parameter
# const JUMP_TRIGGER_PARAM = "parameters/Conditions/jump_trigger" # Optional: If you have a jump trigger

# Base speeds are still needed to normalize the blend space value if desired.
# Alternatively, the BlendSpace1D can be configured with absolute speed values.
var base_move_speed := 5.0 # Example value, should match player's base walk speed
var base_sprint_speed := 8.0 # Example value, should match player's sprint speed

## Called by player_controller_core during its _ready phase.
## IMPORTANT: Ensure player_controller_core passes the AnimationTree node to this setup function.
func setup(at: AnimationTree, move_speed: float, sprint_speed: float) -> void:
	animation_tree = at
	base_move_speed = move_speed
	base_sprint_speed = sprint_speed # Store speeds if needed for normalization

	if !animation_tree:
		printerr("AnimationSystem: Invalid AnimationTree node received during setup.")
		return
	
	if !animation_tree.active:
		printerr("AnimationSystem: AnimationTree is not active. Activating.")
		animation_tree.active = true # Ensure the tree is processing

	# Basic validation (optional but recommended)
	if !animation_tree.has_parameter(SPEED_PARAM):
		printerr("AnimationSystem: AnimationTree is missing parameter: ", SPEED_PARAM)
	if !animation_tree.has_parameter(ON_FLOOR_PARAM):
		printerr("AnimationSystem: AnimationTree is missing parameter: ", ON_FLOOR_PARAM)

## Called every physics frame by player_controller_core.
## Assumes player_controller_core now passes the AnimationTree instead of AnimationPlayer.
func update_animation(on_floor: bool, is_sprinting: bool, current_velocity: Vector3) -> void: # Removed base speed args, get from stored vars if needed
	if !animation_tree or !animation_tree.is_active():
		# No tree or tree not active, nothing to do.
		# Consider adding a printerr here if it shouldn't happen during gameplay.
		return

	var horizontal_velocity = Vector3(current_velocity.x, 0, current_velocity.z)
	var current_horizontal_speed = horizontal_velocity.length()

	# --- Update AnimationTree Parameters ---

	# Set the boolean for ground/air state (likely for a StateMachine)
	# Ensure the parameter path ON_FLOOR_PARAM exists in your AnimationTree
	animation_tree.set(ON_FLOOR_PARAM, on_floor)

	# Set the speed parameter for the BlendSpace1D (Idle/Walk/Run)
	# Ensure the parameter path SPEED_PARAM exists in your AnimationTree
	# The BlendSpace1D should be configured to blend between Idle (0), Walk (e.g., base_move_speed),
	# and Run (e.g., base_sprint_speed) based on this value.
	animation_tree.set(SPEED_PARAM, current_horizontal_speed)
	
	# --- Optional: Handling Jump Triggers ---
	# If your StateMachine uses triggers for jumps (e.g., AnimationNodeOneShot),
	# you'd need the core script to pass a 'jump_requested' flag here.
	# if jump_requested:
	#    animation_tree.set(JUMP_TRIGGER_PARAM, true) # Or "parameters/JumpState/request" etc.

	# No need to manually call play() or set speed_scale - the AnimationTree handles it.
	# No need to track current_animation here.

# --- All previous logic for checking animations, setting speed scale, ---
# --- and playing animations directly is removed. ---
