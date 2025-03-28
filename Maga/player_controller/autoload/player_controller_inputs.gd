# .----------------------------------------------------------------------------.
# |:::    :::     :::     :::        ::::::::  :::   :::  ::::::::  ::::    :::|
# |:+:    :+:   :+: :+:   :+:       :+:    :+: :+:   :+: :+:    :+: :+:+:   :+:|
# |+:+    +:+  +:+   +:+  +:+       +:+         +:+ +:+  +:+    +:+ :+:+:+  +:+|
# |+#++:++#++ +#++:++#++: +#+       +#+          +#++:   +#+    +:+ +#+ +:+ +#+|
# |+#+    +#+ +#+     +#+ +#+       +#+           +#+    +#+    +#+ +#+  +#+#+#|
# |#+#    #+# #+#     #+# #+#       #+#    #+#    #+#    #+#    #+# #+#   #+#+#|
# |###    ### ###     ### ########## ########     ###     ########  ###    ####|
# '----------------------------------------------------------------------------'
# Player Controller Inputs
#
# Developed by:
# - Liam Maga
# - 
# - 
# .----------------------------------------------------------------------------.


extends Node

# This script handles both input mapping and control functionality
# Set this as an AutoLoad in the Project Settings with name "PlayerController"

var target_icon_instance: MeshInstance3D = null
var target_icon_scene: Node3D = null

func _ready():
	setup_input_actions()
	create_target_icon()

# Creates a target icon programmatically instead of using a scene
func create_target_icon():
	# Create the icon root node that will be added to the scene when needed
	target_icon_scene = Node3D.new()
	target_icon_scene.name = "TargetIcon"
	
	# Create the mesh
	var quad_mesh = QuadMesh.new()
	quad_mesh.size = Vector2(0.5, 0.5)
	
	# Create the material
	var material = StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1, 0.8, 0.2, 0.8)
	material.emission_enabled = true
	material.emission = Color(1, 0.8, 0.2, 1)
	material.emission_energy_multiplier = 2.0
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	
	# Apply material to mesh
	quad_mesh.material = material
	
	# Create the mesh instance
	target_icon_instance = MeshInstance3D.new()
	target_icon_instance.mesh = quad_mesh
	
	# Add to the target icon scene
	target_icon_scene.add_child(target_icon_instance)
	target_icon_scene.visible = false

# Function to show/hide and position the target icon
func set_target_icon_position(is_visible: bool, position: Vector3 = Vector3.ZERO):
	# Check if the target icon is already in the scene
	if is_visible:
		if !target_icon_scene.is_inside_tree():
			# Add the target icon to the scene
			get_tree().root.add_child(target_icon_scene)
		
		target_icon_scene.visible = true
		target_icon_scene.global_position = position
	else:
		if target_icon_scene.is_inside_tree():
			target_icon_scene.visible = false

# Animate the target icon (called in _process)
func animate_target_icon(delta: float):
	if target_icon_scene and target_icon_scene.visible:
		# Add pulse effect
		var time = Time.get_ticks_msec() / 1000.0
		var pulse = 0.9 + 0.2 * (0.5 + 0.5 * sin(time * 2.0 * PI))
		target_icon_instance.scale = Vector3(pulse, pulse, pulse)
		
		# Add rotation
		target_icon_instance.rotate_z(1.0 * delta)

func _process(delta: float):
	animate_target_icon(delta)

func setup_input_actions():
	# Movement actions
	if not InputMap.has_action("move_forward"):
		InputMap.add_action("move_forward")
		add_key_mapping("move_forward", KEY_W)
		add_joypad_mapping("move_forward", JOY_AXIS_LEFT_Y, -1.0)
	
	if not InputMap.has_action("move_backward"):
		InputMap.add_action("move_backward")
		add_key_mapping("move_backward", KEY_S)
		add_joypad_mapping("move_backward", JOY_AXIS_LEFT_Y, 1.0)
	
	if not InputMap.has_action("move_left"):
		InputMap.add_action("move_left")
		add_key_mapping("move_left", KEY_A)
		add_joypad_mapping("move_left", JOY_AXIS_LEFT_X, -1.0)
	
	if not InputMap.has_action("move_right"):
		InputMap.add_action("move_right")
		add_key_mapping("move_right", KEY_D)
		add_joypad_mapping("move_right", JOY_AXIS_LEFT_X, 1.0)
	
	# Camera actions
	if not InputMap.has_action("camera_up"):
		InputMap.add_action("camera_up")
		add_key_mapping("camera_up", KEY_UP)
		add_joypad_mapping("camera_up", JOY_AXIS_RIGHT_Y, -1.0)
	
	if not InputMap.has_action("camera_down"):
		InputMap.add_action("camera_down")
		add_key_mapping("camera_down", KEY_DOWN)
		add_joypad_mapping("camera_down", JOY_AXIS_RIGHT_Y, 1.0)
	
	if not InputMap.has_action("camera_left"):
		InputMap.add_action("camera_left")
		add_key_mapping("camera_left", KEY_LEFT)
		add_joypad_mapping("camera_left", JOY_AXIS_RIGHT_X, -1.0)
	
	if not InputMap.has_action("camera_right"):
		InputMap.add_action("camera_right")
		add_key_mapping("camera_right", KEY_RIGHT)
		add_joypad_mapping("camera_right", JOY_AXIS_RIGHT_X, 1.0)
	
	# Jump action
	if not InputMap.has_action("move_jump"):
		InputMap.add_action("move_jump")
		add_key_mapping("move_jump", KEY_SPACE)
		add_button_mapping("move_jump", JOY_BUTTON_A)
	
	# Sprint action
	if not InputMap.has_action("move_sprint"):
		InputMap.add_action("move_sprint")
		add_key_mapping("move_sprint", KEY_SHIFT)
		add_button_mapping("move_sprint", JOY_BUTTON_B)
	
	# Action/Interact
	if not InputMap.has_action("action"):
		InputMap.add_action("action")
		add_key_mapping("action", KEY_E)
		add_button_mapping("action", JOY_BUTTON_X)
	
	# Target/Lock-on (Zelda Z-targeting style)
	if not InputMap.has_action("target"):
		InputMap.add_action("target")
		add_key_mapping("target", KEY_TAB)
		add_button_mapping("target", JOY_BUTTON_LEFT_SHOULDER)

func add_key_mapping(action_name: String, key_scancode: int) -> void:
	var event = InputEventKey.new()
	event.keycode = key_scancode
	InputMap.action_add_event(action_name, event)

func add_button_mapping(action_name: String, button_index: int) -> void:
	var event = InputEventJoypadButton.new()
	event.button_index = button_index
	InputMap.action_add_event(action_name, event)

func add_joypad_mapping(action_name: String, axis: int, axis_value: float) -> void:
	var event = InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = axis_value
	InputMap.action_add_event(action_name, event)
