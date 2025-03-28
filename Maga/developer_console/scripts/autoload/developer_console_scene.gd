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

extends RefCounted

class_name DeveloperConsoleSceneManager

# --- Scene Tab References ---
var console: Node # Reference to the main developer console node
var scene_tab: Control # Reference to the Scene tab Control node 
var scene_list: ItemList # Reference to the existing SceneList ItemList
var scroll_container: ScrollContainer # Container for scene buttons
var button_container: VBoxContainer # Container for organizing buttons vertically

# --- Style Resources ---
var button_style_normal: StyleBoxFlat
var button_style_hover: StyleBoxFlat
var button_style_pressed: StyleBoxFlat

# --- Constants ---
const MAX_BUTTON_WIDTH = 1000
const BUTTON_HEIGHT = 30
const BUTTON_MARGIN = 5

# ============================================================================ #
# region Initialization
# ============================================================================ #

## Initialize the scene manager with references to the main console
func initialize(developer_console: Node) -> void:
	console = developer_console
	
	# Get references to existing nodes
	scene_tab = console.get_node_or_null("PanelContainer/VBoxContainer/TabContainer/Scene")
	if scene_tab == null:
		console.log("[ERROR] Could not find Scene tab")
		return
		
	scene_list = scene_tab.get_node_or_null("SceneList")
	if scene_list == null:
		console.log("[ERROR] Could not find SceneList in Scene tab")
		return
	
	# Hide the original scene list as we'll replace it with buttons
	scene_list.visible = false
	
	# Create the new UI for buttons
	_setup_scene_tab_ui()
	
	# Create button styles
	_create_styles()
	
	# Connect to tab changed signal to load scenes when needed
	var tab_container = console.get_node("PanelContainer/VBoxContainer/TabContainer")
	if tab_container:
		if tab_container.is_connected("tab_changed", _on_tab_changed):
			tab_container.disconnect("tab_changed", _on_tab_changed)
		tab_container.tab_changed.connect(_on_tab_changed)
	
	# Scan scenes immediately
	scan_scenes()
	
	# Log initialization
	console.log("Scene Tab Extension initialized")


## Set up the UI components for the scene tab
func _setup_scene_tab_ui() -> void:
	# First, remove any existing UI that might be there from previous attempts
	var existing_scroll = scene_tab.get_node_or_null("SceneButtonScroll")
	if existing_scroll:
		existing_scroll.queue_free()
	
	# Create scroll container
	scroll_container = ScrollContainer.new()
	scroll_container.name = "SceneButtonScroll"
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	
	# Setup anchors and position
	scroll_container.anchor_right = 1.0
	scroll_container.anchor_bottom = 1.0
	scroll_container.offset_left = 10
	scroll_container.offset_top = 10
	scroll_container.offset_right = -10
	scroll_container.offset_bottom = -10
	
	# Create button container
	button_container = VBoxContainer.new()
	button_container.name = "SceneButtonContainer"
	button_container.size_flags_horizontal = Control.SIZE_FILL
	button_container.size_flags_vertical = Control.SIZE_FILL
	button_container.add_theme_constant_override("separation", BUTTON_MARGIN)
	
	# Add to scene tree
	scroll_container.add_child(button_container)
	scene_tab.add_child(scroll_container)
	
	# Log UI setup
	console.log("Scene tab UI initialized")


## Create styles for the scene buttons
func _create_styles() -> void:
	# Normal style
	button_style_normal = StyleBoxFlat.new()
	button_style_normal.bg_color = Color(0.2, 0.2, 0.2, 1.0)
	button_style_normal.border_width_left = 1
	button_style_normal.border_width_top = 1
	button_style_normal.border_width_right = 1
	button_style_normal.border_width_bottom = 1
	button_style_normal.border_color = Color(0.4, 0.4, 0.4, 1.0)
	button_style_normal.corner_radius_top_left = 4
	button_style_normal.corner_radius_top_right = 4
	button_style_normal.corner_radius_bottom_right = 4
	button_style_normal.corner_radius_bottom_left = 4
	
	# Hover style
	button_style_hover = button_style_normal.duplicate()
	button_style_hover.bg_color = Color(0.25, 0.25, 0.25, 1.0)
	button_style_hover.border_color = Color(0.5, 0.5, 0.5, 1.0)
	
	# Pressed style
	button_style_pressed = button_style_normal.duplicate()
	button_style_pressed.bg_color = Color(0.15, 0.15, 0.15, 1.0)
	button_style_pressed.border_color = Color(0.6, 0.6, 0.6, 1.0)

# endregion

# ============================================================================ #
# region Scene Management
# ============================================================================ #

## Scan the project for scene files and create buttons
func scan_scenes() -> void:
	# Clear existing buttons
	for child in button_container.get_children():
		child.queue_free()
	
	# Add a label at the top
	var label = Label.new()
	label.text = "Available Scenes:"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button_container.add_child(label)
	
	# Get scenes from the console's scanning function (reuse existing code)
	var scenes = _find_all_scenes()
	
	# Sort scenes alphabetically
	scenes.sort()
	
	# Create a button for each scene
	for scene_path in scenes:
		_create_scene_button(scene_path)
	
	console.log("Scene buttons created - found %d scenes." % scenes.size())


## Create a button for a scene file
func _create_scene_button(scene_path: String) -> void:
	var button = Button.new()
	
	# Get a clean name for display
	var display_name = scene_path.replace("res://", "")
	
	# Configure button
	button.text = display_name
	button.tooltip_text = scene_path
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0, BUTTON_HEIGHT)
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_horizontal = Control.SIZE_FILL
	
	# Apply styles
	button.add_theme_stylebox_override("normal", button_style_normal)
	button.add_theme_stylebox_override("hover", button_style_hover)
	button.add_theme_stylebox_override("pressed", button_style_pressed)
	
	# Connect signal
	button.pressed.connect(_on_scene_button_pressed.bind(scene_path))
	
	# Add to container
	button_container.add_child(button)
	
	# Logging for debugging
	console.log("Created scene button: " + display_name)


## Find all scene files in the project
func _find_all_scenes() -> PackedStringArray:
	var found_scenes: PackedStringArray = []
	
	console.log("Starting scene scan...")
	
	# Fix: Use the correct directory open method for Godot 4
	var dir = DirAccess.open("res://")
	if dir == null:
		console.log("[ERROR] Failed to access res:// directory. Error code: " + str(DirAccess.get_open_error()))
		return found_scenes
	
	var queue: Array = ["res://"]
	
	while not queue.is_empty():
		var current_path = queue.pop_front()
		
		dir = DirAccess.open(current_path)
		if dir:
			# Make sure to use the correct method to list files
			dir.list_dir_begin()
			var file_name = dir.get_next()
			
			while file_name != "":
				if file_name == "." or file_name == "..":
					file_name = dir.get_next()
					continue
				
				# Handle .remap files by removing the .remap extension
				file_name = file_name.replace(".remap", "")
				var full_path = current_path
				if not full_path.ends_with("/"):
					full_path += "/"
				full_path += file_name
				
				if dir.current_is_dir():
					# Skip hidden directories
					if not file_name.begins_with("."):
						queue.push_back(full_path)
				elif file_name.ends_with(".tscn"):
					found_scenes.push_back(full_path)
					
				file_name = dir.get_next()
			dir.list_dir_end()
		else:
			console.log("[ERROR] Failed to open directory: " + current_path)
	
	console.log("Scene scan complete. Found " + str(found_scenes.size()) + " scenes")
	return found_scenes


## Handle button press - change to the selected scene
func _on_scene_button_pressed(scene_path: String) -> void:
	console.log("Changing to scene: " + scene_path)
	
	# Check if the file exists
	if not FileAccess.file_exists(scene_path):
		console.log("[ERROR] Scene file not found: " + scene_path)
		return
	
	# Change scene
	var result = console.get_tree().change_scene_to_file(scene_path)
	if result != OK:
		console.log("[ERROR] Failed to change scene. Error code: " + str(result))
	else:
		# Hide console after successful scene change
		console._hide_console()


## Handle tab changed event
func _on_tab_changed(tab_idx: int) -> void:
	var tab_container = console.get_node_or_null("PanelContainer/VBoxContainer/TabContainer")
	if not tab_container:
		console.log("[ERROR] Tab container not found")
		return
		
	var tab_control = tab_container.get_tab_control(tab_idx)
	
	# If Scene tab is selected, refresh buttons
	if tab_control == scene_tab:
		console.log("Scene tab selected, scanning scenes...")
		scan_scenes()

# endregion 