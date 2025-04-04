# .----------------------------------------------------------------------------.
# |:::    :::     :::     :::        ::::::::  :::   :::  ::::::::  ::::    :::|
# |:+:    :+:   :+: :+:   :+:       :+:    :+: :+:   :+: :+:    :+: :+:+:   :+:|
# |+:+    +:+  +:+   +:+  +:+       +:+         +:+ +:+  +:+    +:+ :+:+:+  +:+|
# |+#++:++#++ +#++:++#++: +#+       +#+          +#++:   +#+    +:+ +#+ +:+ +#+|
# |+#+    +#+ +#+     +#+ +#+       +#+           +#+    +#+    +#+ +#+  +#+#+#|
# |#+#    #+# #+#     #+# #+#       #+#    #+#    #+#    #+#    #+# #+#   #+#+#|
# |###    ### ###     ### ########## ########     ###     ########  ###    ####|
# '----------------------------------------------------------------------------'
# Developer Console Search
#
# Developed by:
# - Liam Maga
# - 
# - 
# .----------------------------------------------------------------------------.

extends Control

@onready var button_container: Control = get_node_or_null("ButtonContainer") # Container for search result buttons

# Reference to the main developer console
var console: Node

# ============================================================================ #
# region Initialization
# ============================================================================ #

## Initialize the search manager with references to the main console
func initialize(developer_console: Node) -> void:
	console = developer_console
	# Add any specific initialization needed for the search manager here
	if console and console.has_method("_console_log"):
		console._console_log("Search Manager Extension initialized")
	else:
		printerr("Search Manager Error: Invalid console reference during initialization.")

# endregion

# ============================================================================ #
# region Public Methods
# ============================================================================ #

## Placeholder for handling search queries (e.g., called from console input)
func handle_search(query: String) -> void:
	if not console or not console.has_method("_console_log"):
		printerr("Search Manager Error: Invalid console reference.")
		return
	
	console._console_log("Search handled with query: " + query)
	# Implement actual search logic here (e.g., filter scenes, nodes, etc.)


## Scans for scenes and populates the button container.
func scan_scenes() -> void:
	if button_container:
		# Clear previous results
		for child in button_container.get_children():
			child.queue_free()
	else:
		printerr("Scene Manager: button_container not set.")
		return
	
	var scenes: Array = _find_all_scenes()
	if scenes.is_empty():
		print("Scene Manager: No scenes found.") # Consider adding a label to UI
		return
	
	for scene_path in scenes:
		_create_scene_button(scene_path)

# endregion

# ============================================================================ #
# region Helper Methods
# ============================================================================ #

## Recursively finds all .tscn files starting from res://
func _find_all_scenes() -> Array:
	var scenes = []
	var queue = ["res://"] # Start scan from the root resource directory
	
	while not queue.is_empty():
		var current_path = queue.pop_front()
		var dir = DirAccess.open(current_path)
		
		if dir:
			dir.list_dir_begin()
			var file_name = dir.get_next()
			
			while file_name != "":
				# Skip current and parent directory entries
				if file_name == "." or file_name == "..":
					file_name = dir.get_next()
					continue 
				
				var full_path = current_path.path_join(file_name)
				
				if dir.current_is_dir():
					# Skip common hidden/system directories
					if file_name != ".git" and file_name != ".godot" and file_name != ".vscode":
						queue.push_back(full_path) # Add subdirectory to the queue for scanning
				elif file_name.ends_with(".tscn"):
					scenes.append(full_path) # Found a scene file
					
				file_name = dir.get_next()
		else:
			printerr("Scene Manager: Failed to open directory: %s" % current_path)
			
	scenes.sort() # Sort alphabetically for consistent order
	return scenes

## Creates a button for a specific scene path and adds it to the container.
func _create_scene_button(scene_path: String) -> void:
	var btn = Button.new()
	var display_name = scene_path.replace("res://", "") # Use relative path for display
	btn.text = display_name
	
	# Connect button press to load the scene, passing the path
	var button_callable = Callable(self, "_on_scene_button_pressed").bind(scene_path)
	btn.connect("pressed", button_callable)
	
	if button_container:
		button_container.add_child(btn)
	else:
		printerr("Scene Manager: Cannot add button, container is null.")

## Callback function executed when a scene button is pressed.
func _on_scene_button_pressed(scene_path: String) -> void:
	if FileAccess.file_exists(scene_path):
		get_tree().change_scene_to_file(scene_path)
		# Optionally close the console after changing scene
		if console and console.has_method("hide_console"):
			console.hide_console()
		print("Scene Manager: Changing scene to: %s" % scene_path)
	else:
		printerr("Scene Manager: Scene file not found: %s" % scene_path)
		# Optionally provide feedback to the user in the console log
		if console and console.has_method("_console_log"):
			console._console_log("[ERROR] Scene file not found: %s" % scene_path)

# endregion 