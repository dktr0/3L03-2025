extends Control

@onready var button_container: Control = get_node_or_null("ButtonContainer")

# --- Modified scan_scenes function ---
func scan_scenes() -> void:
	if button_container:
		button_container.clear()
	else:
		printerr("Scene Manager: button_container not set.")
		return
	
	var scenes: Array = _find_all_scenes()
	if scenes.size() == 0:
		print("Scene Manager: No scenes found.")
		return
	
	for scene_path in scenes:
		_create_scene_button(scene_path)

# --- New helper function to scan for scenes ---
func _find_all_scenes() -> Array:
	var scenes = []
	var queue = ["res://"]
	while queue.size() > 0:
		var current_path = queue.pop_front()
		var dir = DirAccess.open(current_path)
		if dir:
			dir.list_dir_begin()
			var file_name = dir.get_next()
			while file_name != "":
				if file_name == "." or file_name == "..":
					file_name = dir.get_next()
					continue
				var full_path = current_path
				if not full_path.ends_with("/"):
					full_path += "/"
				full_path += file_name
				if dir.current_is_dir():
					if file_name != ".git" and file_name != ".godot":
						queue.push_back(full_path)
				elif file_name.ends_with(".tscn"):
					scenes.append(full_path)
				file_name = dir.get_next()
		else:
			printerr("Scene Manager: Failed to open directory: %s" % current_path)
	scenes.sort()
	return scenes

# --- New helper function to create a scene button ---
func _create_scene_button(scene_path: String) -> void:
	var btn = Button.new()
	var display_name = scene_path.replace("res://", "")
	btn.text = display_name
	var button_callable = Callable(self, "_on_scene_button_pressed").bind(scene_path)
	btn.connect("pressed", button_callable)
	button_container.add_child(btn)

# --- New callback for scene button press ---
func _on_scene_button_pressed(scene_path: String) -> void:
	if FileAccess.file_exists(scene_path):
		get_tree().change_scene_to_file(scene_path)
		print("Scene Manager: Changing scene to: %s" % scene_path)
	else:
		printerr("Scene Manager: Scene file not found: %s" % scene_path) 