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

# --- Configuration ---
const SAVE_FILE_PATH = "user://input_mappings.cfg"
# List of actions managed by this system (add any other remappable actions here)
const MANAGED_ACTIONS = [
	"move_forward", "move_backward", "move_left", "move_right",
	"camera_up", "camera_down", "camera_left", "camera_right",
	"move_jump", "move_sprint", "action", "target"
]

# Enum to represent the active input scheme
enum InputScheme { KEYBOARD_MOUSE, GAMEPAD }

# Signal emitted when the input scheme changes
signal input_scheme_changed(new_scheme: InputScheme)

# Current active input scheme
var current_input_scheme: InputScheme = InputScheme.KEYBOARD_MOUSE

# --- Target Icon Variables (keep existing) ---
var target_icon_instance: MeshInstance3D = null
var target_icon_scene: Node3D = null

# --- Scheme Switching Debounce ---
var gamepad_grace_period_active := false
var gamepad_grace_timer: Timer
const GAMEPAD_GRACE_DURATION = 0.3 # Seconds to ignore KBM after gamepad input

# --- Input Processing for Scheme Detection ---
func _input(event: InputEvent):
	var detected_kbm = false
	var detected_gamepad = false
	
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventMouseMotion:
		detected_kbm = true
	elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
		detected_gamepad = true
		
	# --- Logic with Debounce ---
	var previous_scheme = current_input_scheme
	
	if detected_gamepad:
		# Always switch to gamepad immediately on controller input
		current_input_scheme = InputScheme.GAMEPAD
		# Start or reset the grace period timer
		gamepad_grace_period_active = true
		if gamepad_grace_timer:
			gamepad_grace_timer.start(GAMEPAD_GRACE_DURATION)
	elif detected_kbm and not gamepad_grace_period_active:
		# Switch to KBM only if KBM input detected AND grace period is NOT active
		current_input_scheme = InputScheme.KEYBOARD_MOUSE
	# Else (neither detected, or KBM detected during grace period): Scheme remains unchanged
	
	# --- Emit signal only if the scheme actually changed ---
	if current_input_scheme != previous_scheme:
		print(">>> INPUT SCHEME CHANGED TO: ", InputScheme.keys()[current_input_scheme])
		@warning_ignore("int_as_enum_without_cast")
		emit_signal("input_scheme_changed", current_input_scheme)

# NEW Function: Called when a joystick disconnects
func handle_joy_disconnection(device_id: int):
	print("Input Autoload: Received disconnection notice for device ", device_id)
	# Check if any other joypads are still connected
	var connected_joypads = Input.get_connected_joypads()
	# If no controllers are left, and the current scheme IS gamepad, switch back to KBM
	if connected_joypads.is_empty() and current_input_scheme == InputScheme.GAMEPAD:
		print("  Last controller disconnected. Switching input scheme to Keyboard/Mouse.")
		current_input_scheme = InputScheme.KEYBOARD_MOUSE
		# Use call_deferred to avoid potential issues emitting signal during input processing
		call_deferred("emit_signal", "input_scheme_changed", current_input_scheme)
	elif not connected_joypads.is_empty():
		print("  Other controllers still connected: ", connected_joypads)
		# Optional: Could check if the disconnected 'device_id' was the 'active' one,
		# but simply checking if *any* are left is usually sufficient.


# --- Initialization ---
func _ready():
	# --- ADD TIMER NODE ---
	gamepad_grace_timer = Timer.new()
	gamepad_grace_timer.one_shot = true
	gamepad_grace_timer.connect("timeout", _on_gamepad_grace_period_timeout)
	add_child(gamepad_grace_timer)
	# ---------------------

	# 1. Ensure all managed actions exist in the InputMap (and set deadzones)
	ensure_actions_exist()
	
	# 2. ALWAYS setup default events and save them, overwriting any existing .cfg file
	print("Forcing setup of default input events...")
	setup_default_events()
	print("Saving default mappings (overwriting any existing file at: ", SAVE_FILE_PATH, ")...")
	save_input_mappings()
	
	# 3. Always create the target icon
	create_target_icon()

# --- Timer Timeout Callback ---
func _on_gamepad_grace_period_timeout():
	gamepad_grace_period_active = false
	#print("Gamepad grace period ended.") # Optional: for debugging

# --- Input Mapping Logic ---

# Ensures all actions listed in MANAGED_ACTIONS exist in the InputMap
func ensure_actions_exist():
	print("Ensuring input actions exist...")
	var low_deadzone = 0.15 # Lowered deadzone for analog stick sensitivity (was 0.2)
	for action_name in MANAGED_ACTIONS:
		if not InputMap.has_action(action_name):
			print("  Action '", action_name, "' not found, adding.")
			InputMap.add_action(action_name)
			# Set lower deadzone specifically for axis-based actions
			if action_name.begins_with("move_") or action_name.begins_with("camera_"):
				if not action_name == "move_jump" and not action_name == "move_sprint": # Exclude button actions
					InputMap.action_set_deadzone(action_name, low_deadzone)
					print("    Set deadzone for '", action_name, "' to: ", low_deadzone)

# Sets up the default *event* mappings for all managed actions
# Assumes the actions themselves already exist (called by ensure_actions_exist)
func setup_default_events():
	print("Setting up default input events...")
	# Clear existing events first for MANAGED actions
	for action_name in MANAGED_ACTIONS:
		InputMap.action_erase_events(action_name)
		
	# --- Add default KEYBOARD/MOUSE events for MANAGED actions ---
	add_key_mapping("move_forward", KEY_W)
	add_key_mapping("move_backward", KEY_S)
	add_key_mapping("move_left", KEY_A)
	add_key_mapping("move_right", KEY_D)
	add_key_mapping("move_jump", KEY_SPACE)
	add_key_mapping("move_sprint", KEY_SHIFT)
	add_key_mapping("action", KEY_E) # 'action' is managed
	add_mouse_button_mapping("action", MOUSE_BUTTON_LEFT) # Also map left click to action
	add_key_mapping("target", KEY_TAB) # 'target' is managed

	# --- Handle OTHER specific actions (ensure they exist, clear, map) ---
	var other_actions = ["ui_accept", "ui_cancel", "activate", "activate_button", "attack"]
	for action_name in other_actions:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
		InputMap.action_erase_events(action_name) # Clear existing events

	# Map specific KBM events for these other actions
	add_key_mapping("ui_accept", KEY_ENTER)
	add_key_mapping("ui_cancel", KEY_ESCAPE)
	add_key_mapping("activate", KEY_E) # E key for activate
	add_mouse_button_mapping("activate_button", MOUSE_BUTTON_LEFT)
	add_key_mapping("activate_button", KEY_E) # E for activate_button
	# --------------------------------------------------
	# Keeping mouse binding from project.godot (or add here if needed)
	# add_mouse_button_mapping("attack", MOUSE_BUTTON_LEFT)
	# --- ADDED: Explicitly add mouse button mapping for attack ---
	add_mouse_button_mapping("attack", MOUSE_BUTTON_LEFT)
	# -----------------------------------------------------------

	# --- Add default GAMEPAD events for ALL relevant actions ---
	# Movement (Left Stick)
	add_joypad_mapping("move_forward", JOY_AXIS_LEFT_Y, -1.0) 
	add_joypad_mapping("move_backward", JOY_AXIS_LEFT_Y, 1.0)
	add_joypad_mapping("move_left", JOY_AXIS_LEFT_X, -1.0)
	add_joypad_mapping("move_right", JOY_AXIS_LEFT_X, 1.0)
	
	# Camera (Right Stick) 
	add_joypad_mapping("camera_up", JOY_AXIS_RIGHT_Y, -1.0) 
	add_joypad_mapping("camera_down", JOY_AXIS_RIGHT_Y, 1.0)
	add_joypad_mapping("camera_left", JOY_AXIS_RIGHT_X, -1.0)
	add_joypad_mapping("camera_right", JOY_AXIS_RIGHT_X, 1.0)
	
	# Buttons (Standard Layout + Attack/Activate)
	add_button_mapping("move_jump", JOY_BUTTON_A) # A / Cross
	add_button_mapping("move_sprint", JOY_BUTTON_LEFT_STICK) # L3 Click 
	add_button_mapping("action", JOY_BUTTON_X) # X / Square (Managed Action)
	add_button_mapping("target", JOY_BUTTON_LEFT_SHOULDER) # LB (Managed Action)
	
	# UI Buttons
	add_button_mapping("ui_accept", JOY_BUTTON_X) # X / Square also for UI accept
	add_button_mapping("ui_cancel", JOY_BUTTON_B) # B / Circle for UI cancel
	
	# Specific Activate / Attack Buttons (Mapping all to X / Square as requested)
	add_button_mapping("activate", JOY_BUTTON_X) # X / Square for activate
	add_button_mapping("activate_button", JOY_BUTTON_X) # X / Square for activate_button
	add_button_mapping("attack", JOY_BUTTON_X) # X / Square for attack


# Saves the current mappings for MANAGED_ACTIONS to the save file
func save_input_mappings():
	var config = ConfigFile.new()
	
	# Iterate through the actions we want to save
	for action_name in MANAGED_ACTIONS:
		if InputMap.has_action(action_name):
			var events = InputMap.action_get_events(action_name)
			var event_data_array = []
			for event in events:
				# Convert event to a dictionary for saving
				var event_data = event_to_dict(event)
				if event_data: # Only add if conversion was successful
					event_data_array.append(event_data)
					
			# Store the array of event dictionaries if not empty
			if not event_data_array.is_empty():
				config.set_value("InputMappings", action_name, event_data_array)
		#else: # Optional: Handle case where action exists but has no events 
		#	config.set_value("InputMappings", action_name, [])
	
	var err = config.save(SAVE_FILE_PATH)
	if err != OK:
		printerr("Error saving input mappings to ", SAVE_FILE_PATH, ": Error code ", err)
	#else: # Optional: Confirmation message
	#	print("Input mappings saved successfully to: ", SAVE_FILE_PATH)

# Loads mappings from the save file and applies them, OVERWRITING project.godot defaults
# Returns true on success, false on failure (e.g., file not found)
func load_input_mappings() -> bool:
	var config = ConfigFile.new()
	var err = config.load(SAVE_FILE_PATH)
	
	if err != OK:
		if err == ERR_FILE_NOT_FOUND:
			print("Input mapping save file not found at: ", SAVE_FILE_PATH)
		else:
			printerr("Error loading input mappings from ", SAVE_FILE_PATH, ": Error code ", err)
		return false

	if not config.has_section("InputMappings"):
		printerr("Input mapping file is missing 'InputMappings' section.")
		return false

	print("Loading user input mappings (overriding project defaults)...")
	var loaded_actions = config.get_section_keys("InputMappings")
	for action_name in loaded_actions:
		# Check if the loaded action is one we actually manage
		if action_name in MANAGED_ACTIONS: 
			# Action should exist due to ensure_actions_exist(), but check is safe
			if InputMap.has_action(action_name):
				# --- CHANGE: Erase events for this specific action BEFORE adding saved ones ---
				InputMap.action_erase_events(action_name) 
				var saved_events_data = config.get_value("InputMappings", action_name)
				# Ensure the loaded data is actually an array
				if typeof(saved_events_data) == TYPE_ARRAY:
					for event_data in saved_events_data:
						# Ensure the item in the array is a dictionary
						if typeof(event_data) == TYPE_DICTIONARY:
							var event = dict_to_event(event_data)
							if event:
								InputMap.action_add_event(action_name, event)
							else:
								printerr("Failed to convert saved dictionary back to InputEvent for action: ", action_name, ", Data: ", event_data)
						else:
							printerr("Invalid item type in event array for action '", action_name, "'. Expected Dictionary, got: ", typeof(event_data))
				else:
					printerr("Invalid data format for action '", action_name, "' in save file. Expected Array, got: ", typeof(saved_events_data))
		else:
			print("Skipping unknown or unmanaged action '", action_name, "' found in save file.")
			
	print("Finished loading user input mappings.")		
	return true


# Rebinds a specific action to a new event and saves
func rebind_action(action_name: String, new_event: InputEvent):
	if not action_name in MANAGED_ACTIONS:
		printerr("Attempted to rebind unmanaged action: ", action_name)
		return
		
	if not InputMap.has_action(action_name):
		# This shouldn't happen if ensure_actions_exist ran, but safety check
		printerr("Cannot rebind unknown action: ", action_name)
		return
		
	print("Rebinding action '", action_name, "' to event: ", new_event.as_text())
	InputMap.action_erase_events(action_name) # Remove old bindings
	InputMap.action_add_event(action_name, new_event) # Add the new one
	save_input_mappings() # Save the change immediately

# --- Helper functions for saving/loading events --- 
func event_to_dict(event: InputEvent) -> Dictionary:
	var data = {}
	if event is InputEventKey:
		data["type"] = "key"
		data["keycode"] = event.keycode
		data["physical_keycode"] = event.physical_keycode # Important for layout independence
		data["unicode"] = event.unicode # May not be needed but store anyway
		data["modifiers"] = event.get_modifiers_mask() # Ctrl, Alt, Shift, Meta
	elif event is InputEventMouseButton:
		data["type"] = "mouse_button"
		data["button_index"] = event.button_index
		data["modifiers"] = event.get_modifiers_mask()
	elif event is InputEventJoypadButton:
		data["type"] = "joy_button"
		data["button_index"] = event.button_index
	elif event is InputEventJoypadMotion:
		data["type"] = "joy_motion"
		data["axis"] = event.axis
		data["axis_value"] = event.axis_value # Store +1 or -1 for axis direction
	# Add other event types (MIDI, etc.) if needed
	else:
		printerr("Unsupported InputEvent type for saving: ", event)
		return {}
	return data

# Converts a Dictionary back to an InputEvent
func dict_to_event(data: Dictionary) -> InputEvent:
	if not data.has("type"):
		return null
		
	var type = data["type"]
	var event = null
	
	if type == "key":
		event = InputEventKey.new()
		event.keycode = data.get("keycode", 0)
		event.physical_keycode = data.get("physical_keycode", 0)
		event.unicode = data.get("unicode", 0)
		event.alt_pressed = (data.get("modifiers", 0) & KEY_MASK_ALT) != 0
		event.shift_pressed = (data.get("modifiers", 0) & KEY_MASK_SHIFT) != 0
		event.ctrl_pressed = (data.get("modifiers", 0) & KEY_MASK_CTRL) != 0
		event.meta_pressed = (data.get("modifiers", 0) & KEY_MASK_META) != 0
	elif type == "mouse_button":
		event = InputEventMouseButton.new()
		event.button_index = data.get("button_index", 0)
		event.alt_pressed = (data.get("modifiers", 0) & KEY_MASK_ALT) != 0
		event.shift_pressed = (data.get("modifiers", 0) & KEY_MASK_SHIFT) != 0
		event.ctrl_pressed = (data.get("modifiers", 0) & KEY_MASK_CTRL) != 0
		event.meta_pressed = (data.get("modifiers", 0) & KEY_MASK_META) != 0
	elif type == "joy_button":
		event = InputEventJoypadButton.new()
		event.button_index = data.get("button_index", 0)
	elif type == "joy_motion":
		event = InputEventJoypadMotion.new()
		event.axis = data.get("axis", 0)
		event.axis_value = data.get("axis_value", 0.0)
	# Add other event types if needed
	else:
		printerr("Unsupported InputEvent type for loading: ", type)
		return null
		
	return event

# --- Mapping Helpers --- 
func add_key_mapping(action_name: String, key_scancode: int) -> void:
	var event = InputEventKey.new()
	# Use physical keycode for better layout handling if available, else fallback
	event.physical_keycode = key_scancode 
	event.keycode = key_scancode # Fallback if physical isn't primary
	# Check if this specific event already exists for the action
	var existing_events = InputMap.action_get_events(action_name)
	for existing_event in existing_events:
		if existing_event is InputEventKey and existing_event.physical_keycode == event.physical_keycode:
			return # Already mapped
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

# --- ADDED: Helper function for mouse button mapping ---
func add_mouse_button_mapping(action_name: String, button_index: int) -> void:
	var event = InputEventMouseButton.new()
	event.button_index = button_index
	# Check if this specific event already exists for the action
	var existing_events = InputMap.action_get_events(action_name)
	for existing_event in existing_events:
		if existing_event is InputEventMouseButton and existing_event.button_index == event.button_index:
			return # Already mapped
	InputMap.action_add_event(action_name, event)
# -----------------------------------------------------

# --- Target Icon Logic (keep existing) ---
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
