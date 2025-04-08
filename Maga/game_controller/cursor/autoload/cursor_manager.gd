# .----------------------------------------------------------------------------.
# |:::    :::     :::     :::        ::::::::  :::   :::  ::::::::  ::::    :::|
# |:+:    :+:   :+: :+:   :+:       :+:    :+: :+:   :+: :+:    :+: :+:+:   :+:|
# |+:+    +:+  +:+   +:+  +:+       +:+         +:+ +:+  +:+    +:+ :+:+:+  +:+|
# |+#++:++#++ +#++:++#++: +#+       +#+          +#++:   +#+    +:+ +#+ +:+ +#+|
# |+#+    +#+ +#+     +#+ +#+       +#+           +#+    +#+    +#+ +#+  +#+#+#|
# |#+#    #+# #+#     #+# #+#       #+#    #+#    #+#    #+#    #+# #+#   #+#+#|
# |###    ### ###     ### ########## ########     ###     ########  ###    ####|
# '----------------------------------------------------------------------------'
# Developer Console
#
# Developed by:
# - Liam Maga
# - 
# - 
# .----------------------------------------------------------------------------.

extends Node

class_name CursorManager

signal cursor_state_changed(is_visible: bool)

# Default cursor state
var is_cursor_visible: bool = false:
	set(value):
		if is_cursor_visible != value:
			is_cursor_visible = value
			_update_cursor_state()
			cursor_state_changed.emit(is_cursor_visible)

# Dictionary of scenes that should always show cursor
var scene_overrides: Dictionary = {}

# Resource reference
var cursor_settings: Resource

# Tracks which systems have requested cursor visibility
var visibility_requests: Dictionary = {
	"console": false,
	"ui_menu": false,
	"dialogue": false,
	"cutscene": false,
	"other": false
}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Load cursor settings resource
	var resource_path = "res://Maga/game_controller/resources/cursor_resource.tres"
	if ResourceLoader.exists(resource_path):
		cursor_settings = load(resource_path)
		
	# Connect to scene tree change notification
	get_tree().node_added.connect(_on_node_added)
	
	# Initial cursor state (locked by default)
	is_cursor_visible = false
	_update_cursor_state()
	
	# Check the current scene on start
	_check_current_scene()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	# Check if Escape key was just pressed to toggle cursor in development builds
	if OS.has_feature("editor") or OS.has_feature("debug"):
		if Input.is_action_just_pressed("anything"):
			toggle_cursor()

# Main function to request cursor visibility
func request_cursor(requester: String, should_be_visible: bool) -> void:
	if visibility_requests.has(requester):
		visibility_requests[requester] = should_be_visible
	else:
		visibility_requests["other"] = should_be_visible
	
	# Update cursor state based on all requests
	_evaluate_cursor_state()

# Toggle cursor visibility directly (use sparingly)
func toggle_cursor() -> void:
	is_cursor_visible = !is_cursor_visible

# Force cursor to specific state (use sparingly)
func force_cursor_visible(visible: bool) -> void:
	is_cursor_visible = visible

# Check if current scene should override cursor state
func _check_current_scene() -> void:
	var current_scene = get_tree().current_scene
	if current_scene:
		var scene_name = current_scene.scene_file_path
		var scene_needs_cursor = _scene_requires_cursor(scene_name)
		
		if scene_needs_cursor:
			request_cursor("scene_override", true)
		else:
			request_cursor("scene_override", false)

# Called when a new node is added to the scene tree
func _on_node_added(node: Node) -> void:
	# If the new node is a scene root, check if it affects cursor
	if node.get_parent() == get_tree().root:
		_check_current_scene()

# Determine if a scene requires cursor visibility
func _scene_requires_cursor(scene_path: String) -> bool:
	# Check scene overrides dictionary
	if scene_overrides.has(scene_path) and scene_overrides[scene_path]:
		return true
		
	# Check resource for scene settings if available
	if cursor_settings and cursor_settings.get("always_visible_scenes"):
		var scenes = cursor_settings.get("always_visible_scenes")
		if scenes.has(scene_path):
			return true
			
	# Special handling for specific scenes
	if scene_path.contains("developer_console_scene") or scene_path.contains("placeholder_launch_scene"):
		return true
		
	return false

# Evaluate if cursor should be visible based on all requests
func _evaluate_cursor_state() -> void:
	var should_be_visible = false
	
	# If any system requests visibility, show cursor
	for requester in visibility_requests:
		if visibility_requests[requester]:
			should_be_visible = true
			break
			
	is_cursor_visible = should_be_visible

# Actually update the cursor state in the engine
func _update_cursor_state() -> void:
	if is_cursor_visible:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
