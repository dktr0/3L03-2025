# .----------------------------------------------------------------------------.
# |:::    :::     :::     :::        ::::::::  :::   :::  ::::::::  ::::    :::|
# |:+:    :+:   :+: :+:   :+:       :+:    :+: :+:   :+: :+:    :+: :+:+:   :+:|
# |+:+    +:+  +:+   +:+  +:+       +:+         +:+ +:+  +:+    +:+ :+:+:+  +:+|
# |+#++:++#++ +#++:++#++: +#+       +#+          +#++:   +#+    +:+ +#+ +:+ +#+|
# |+#+    +#+ +#+     +#+ +#+       +#+           +#+    +#+    +#+ +#+  +#+#+#|
# |#+#    #+# #+#     #+# #+#       #+#    #+#    #+#    #+#    #+# #+#   #+#+#|
# |###    ### ###     ### ########## ########     ###     ########  ###    ####|
# '----------------------------------------------------------------------------'
# Developer Console Scenes Scene
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
var scene_search: LineEdit # Reference to the scene search bar
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

# --- Scene Data ---
var all_scenes: PackedStringArray = [] # Store all found scenes
var filtered_scenes: PackedStringArray = [] # Store filtered scenes based on search

# ============================================================================ #
# region Initialization
# ============================================================================ #

## Initialize the scene manager with references to the main console
func initialize(developer_console: Node) -> void:
	console = developer_console
	
	# Get references to existing nodes
	scene_tab = console.get_node_or_null("PanelContainer/VBoxContainer/TabContainer/Scene")
	if scene_tab == null:
		console._console_log("[ERROR] Could not find Scene tab")
		return
		
	console._console_log("Found Scene tab, visibility: " + str(scene_tab.visible))
	console._console_log("Scene tab path: " + str(scene_tab.get_path()))
	
	# Get reference to VBoxContainer in Scene tab
	var vbox = scene_tab.get_node_or_null("VBoxContainer")
	if vbox == null:
		console._console_log("[ERROR] Could not find VBoxContainer in Scene tab")
		return
		
	# Get reference to SceneList
	scene_list = vbox.get_node_or_null("SceneList")
	if scene_list == null:
		console._console_log("[ERROR] Could not find SceneList in Scene tab")
		return
	
	# Get reference to SceneSearch
	scene_search = vbox.get_node_or_null("SceneSearch") 
	if scene_search == null:
		console._console_log("[ERROR] Could not find SceneSearch in Scene tab")
		return
		
	# Connect search bar signals
	scene_search.text_changed.connect(_on_scene_search_changed)
	scene_search.text_submitted.connect(_on_scene_search_submitted)
	
	console._console_log("Found SceneList and SceneSearch, connecting signals...")
	
	# Create the new UI for buttons
	_setup_scene_tab_ui()
	
	# Create button styles
	_create_styles()
	
	# Connect to tab changed signal to load scenes when needed
	var tab_container = console.get_node("PanelContainer/VBoxContainer/TabContainer")
	if tab_container:
		console._console_log("Found TabContainer, current tab: " + str(tab_container.current_tab))
		console._console_log("TabContainer path: " + str(tab_container.get_path()))
		if tab_container.is_connected("tab_changed", _on_tab_changed):
			tab_container.disconnect("tab_changed", _on_tab_changed)
		tab_container.tab_changed.connect(_on_tab_changed)
	
	# Scan scenes immediately
	scan_scenes()
	
	# Log initialization
	console._console_log("Scene Tab Extension initialized")


## Set up the UI components for the scene tab
func _setup_scene_tab_ui() -> void:
	console._console_log("Setting up Scene tab UI...")
	
	# Get reference to VBoxContainer in Scene tab
	var vbox = scene_tab.get_node_or_null("VBoxContainer")
	if vbox == null:
		console._console_log("[ERROR] Could not find VBoxContainer in Scene tab for UI setup")
		return

	# Find SceneSearch within the VBox
	scene_search = vbox.get_node_or_null("SceneSearch")
	if scene_search == null:
		console._console_log("[WARNING] SceneSearch not found within VBoxContainer during UI setup.")
	
	# Optional: Hide the old SceneList if it exists in VBox
	var old_scene_list = vbox.get_node_or_null("SceneList")
	if old_scene_list:
		old_scene_list.visible = false # Hide it instead of removing, just in case

	# Remove any existing button scroll container that might be misplaced
	var existing_scroll = scene_tab.get_node_or_null("SceneButtonScroll") # Check in scene_tab first
	if existing_scroll:
		console._console_log("Removing existing scroll container from scene_tab...")
		existing_scroll.queue_free()
	else:
		existing_scroll = vbox.get_node_or_null("SceneButtonScroll") # Check in vbox too
		if existing_scroll:
			console._console_log("Removing existing scroll container from vbox...")
			existing_scroll.queue_free()

	# Create the main scroll container for buttons
	scroll_container = ScrollContainer.new()
	scroll_container.name = "SceneButtonScroll"
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll_container.size_flags_horizontal = Control.SIZE_FILL
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL # Make it expand vertically
	
	# Create the container to hold the buttons within the scroll area
	button_container = VBoxContainer.new()
	button_container.name = "SceneButtonContainer"
	button_container.size_flags_horizontal = Control.SIZE_FILL # Fill horizontally within scroll
	button_container.size_flags_vertical = Control.SIZE_FILL # Fill vertically within scroll
	button_container.add_theme_constant_override("separation", BUTTON_MARGIN)
	
	# Add to scene tree: Button container inside Scroll, Scroll inside VBox
	scroll_container.add_child(button_container)
	vbox.add_child(scroll_container) # Place the scroll container inside the main VBox
	
	scroll_container.visible = true
	button_container.visible = true
	
	console._console_log("Scene tab UI initialized (buttons inside VBox)")


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
	console._console_log("Starting scene scan...")
	
	# Clear existing buttons before adding new ones
	if button_container:
		for child in button_container.get_children():
			child.queue_free()
	
	# Add a label at the top for context
	var label = Label.new()
	label.text = "Available Scenes:"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	button_container.add_child(label)
	
	all_scenes = _find_all_scenes()
	
	all_scenes.sort() # Sort scenes alphabetically for consistency
	
	console._console_log("Found " + str(all_scenes.size()) + " scenes")
	
	# Reset search field to ensure fresh state
	if scene_search:
		scene_search.text = ""
	
	# Initially, display all scenes
	filtered_scenes = all_scenes.duplicate()
	
	update_scene_buttons() # Create buttons for the filtered list
	
	console._console_log("Scene buttons created - found %d scenes." % all_scenes.size())


## Create a button for a scene file
func _create_scene_button(scene_path: String) -> void:
	var button = Button.new()
	
	# Get a clean name (remove res:// prefix) for display
	var display_name = scene_path.replace("res://", "")
	
	button.text = display_name
	button.tooltip_text = scene_path # Show full path on hover
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0, BUTTON_HEIGHT)
	button.focus_mode = Control.FOCUS_NONE # Buttons shouldn't grab focus
	button.size_flags_horizontal = Control.SIZE_FILL
	
	# Apply the pre-defined visual styles
	button.add_theme_stylebox_override("normal", button_style_normal)
	button.add_theme_stylebox_override("hover", button_style_hover)
	button.add_theme_stylebox_override("pressed", button_style_pressed)
	
	# Connect signal
	button.pressed.connect(_on_scene_button_pressed.bind(scene_path))
	
	# Add to container
	button_container.add_child(button)
	
	# Logging for debugging
	console._console_log("Created scene button: " + display_name)


## Find all scene files in the project
func _find_all_scenes() -> PackedStringArray:
	var found_scenes: PackedStringArray = []
	
	console._console_log("Starting scene scan...")
	
	# Fix: Use the correct directory open method for Godot 4
	var dir = DirAccess.open("res://")
	if dir == null:
		console._console_log("[ERROR] Failed to access res:// directory. Error code: " + str(DirAccess.get_open_error()))
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
			console._console_log("[ERROR] Failed to open directory: " + current_path)
	
	console._console_log("Scene scan complete. Found " + str(found_scenes.size()) + " scenes")
	return found_scenes


## Handle button press - change to the selected scene
func _on_scene_button_pressed(scene_path: String) -> void:
	console._console_log("Changing to scene: " + scene_path)
	
	# Check if the file exists
	if not FileAccess.file_exists(scene_path):
		console._console_log("[ERROR] Scene file not found: " + scene_path)
		return
	
	# Change scene
	var result = console.get_tree().change_scene_to_file(scene_path)
	if result != OK:
		console._console_log("[ERROR] Failed to change scene. Error code: " + str(result))
	else:
		# Hide console after successful scene change
		console._hide_console()


## Handle tab changed event
func _on_tab_changed(tab_idx: int) -> void:
	var tab_container = console.get_node_or_null("PanelContainer/VBoxContainer/TabContainer")
	if not tab_container:
		console._console_log("[ERROR] Tab container not found")
		return
		
	var tab_control = tab_container.get_tab_control(tab_idx)
	
	# If Scene tab is selected, refresh buttons
	if tab_control == scene_tab:
		console._console_log("Scene tab selected, scanning scenes...")
		scan_scenes()

# Handle scene search text changes
func _on_scene_search_changed(search_text: String) -> void:
	filter_scenes(search_text)
	update_scene_buttons()

# Handle scene search text submission (Enter key)
func _on_scene_search_submitted(search_text: String) -> void:
	filter_scenes(search_text)
	update_scene_buttons()
	
# Filter scenes based on search text
func filter_scenes(search_text: String) -> void:
	# If search is empty, use all scenes
	if search_text.strip_edges() == "":
		filtered_scenes = all_scenes
		return
	
	# Perform case-insensitive search
	filtered_scenes = []
	var lowercase_search = search_text.to_lower()
	
	for scene_path in all_scenes:
		if scene_path.to_lower().contains(lowercase_search):
			filtered_scenes.append(scene_path)
	
	console._console_log("Found %d scenes matching search: '%s'" % [filtered_scenes.size(), search_text])

# Update scene buttons based on current filtered scenes
func update_scene_buttons() -> void:
	# Clear existing buttons
	if button_container:
		for child in button_container.get_children():
			if not child is Label:  # Keep the "Available Scenes:" label
				child.queue_free()
	
	# If no scenes match the filter, show a message
	if filtered_scenes.is_empty():
		var label = Label.new()
		label.text = "No matching scenes found"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 14)
		label.modulate = Color(0.7, 0.7, 0.7)
		button_container.add_child(label)
		return
	
	# Create a button for each filtered scene
	for scene_path in filtered_scenes:
		_create_scene_button(scene_path)

# endregion 