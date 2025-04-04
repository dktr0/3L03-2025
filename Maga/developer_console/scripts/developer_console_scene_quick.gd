# .----------------------------------------------------------------------------.
# |:::    :::     :::     :::        ::::::::  :::   :::  ::::::::  ::::    :::|
# |:+:    :+:   :+: :+:   :+:       :+:    :+: :+:   :+: :+:    :+: :+:+:   :+:|
# |+:+    +:+  +:+   +:+  +:+       +:+         +:+ +:+  +:+    +:+ :+:+:+  +:+|
# |+#++:++#++ +#++:++#++: +#+       +#+          +#++:   +#+    +:+ +#+ +:+ +#+|
# |+#+    +#+ +#+     +#+ +#+       +#+           +#+    +#+    +#+ +#+  +#+#+#|
# |#+#    #+# #+#     #+# #+#       #+#    #+#    #+#    #+#    #+# #+#   #+#+#|
# |###    ### ###     ### ########## ########     ###     ########  ###    ####|
# '----------------------------------------------------------------------------'
# Developer Console Quick Scene	
#
# Developed by:
# - Liam Maga
# - 
# - 
# .----------------------------------------------------------------------------.

extends RefCounted

class_name DeveloperConsoleQuickManager

# --- References ---
var console: Node # Reference to the main developer console
var quick_tab: Control # Reference to the Quick tab
var close_button: Button # Reference to the Close Game button

# ============================================================================ #
# region Initialization
# ============================================================================ #

## Initialize the quick tab manager with references to the main console
func initialize(developer_console: Node) -> void:
	console = developer_console
	
	quick_tab = console.get_node_or_null("PanelContainer/VBoxContainer/TabContainer/Quick")
	if not quick_tab:
		console._console_log("[ERROR] Could not find Quick tab")
		return
	
	_setup_quick_tab_ui()
	
	console._console_log("Quick Tab Extension initialized")

## Set up the UI for the Quick tab
func _setup_quick_tab_ui() -> void:
	# Clear any existing content first
	for child in quick_tab.get_children():
		child.queue_free()
	
	# Add padding around the content
	var margin = MarginContainer.new()
	margin.name = "MarginContainer"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT) # Fill the entire parent
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	quick_tab.add_child(margin)
	
	# Use a VBox to arrange elements vertically
	var vbox = VBoxContainer.new()
	vbox.name = "VBoxContainer"
	vbox.add_theme_constant_override("separation", 20)
	vbox.size_flags_horizontal = Control.SIZE_FILL
	vbox.size_flags_vertical = Control.SIZE_FILL
	margin.add_child(vbox)
	
	var title = Label.new()
	title.text = "Quick Actions"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.size_flags_horizontal = Control.SIZE_FILL
	
	close_button = Button.new()
	close_button.text = "Close Game"
	close_button.tooltip_text = "Close the game application"
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_button.add_theme_font_size_override("font_size", 18)
	
	# Ensure button has a reasonable minimum size that scales
	var min_width = max(200, quick_tab.size.x * 0.3) # 30% of tab width or at least 200px
	close_button.custom_minimum_size = Vector2(min_width, 60)
	
	# Style the close button (red theme)
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.8, 0.2, 0.2, 1.0) # Red for close/exit
	normal_style.border_width_left = 2
	normal_style.border_width_top = 2
	normal_style.border_width_right = 2
	normal_style.border_width_bottom = 2
	normal_style.border_color = Color(0.9, 0.3, 0.3, 1.0)
	normal_style.corner_radius_top_left = 8
	normal_style.corner_radius_top_right = 8
	normal_style.corner_radius_bottom_right = 8
	normal_style.corner_radius_bottom_left = 8
	
	var hover_style = normal_style.duplicate()
	hover_style.bg_color = Color(0.9, 0.3, 0.3, 1.0)
	
	var pressed_style = normal_style.duplicate()
	pressed_style.bg_color = Color(0.7, 0.1, 0.1, 1.0)
	
	close_button.add_theme_stylebox_override("normal", normal_style)
	close_button.add_theme_stylebox_override("hover", hover_style)
	close_button.add_theme_stylebox_override("pressed", pressed_style)
	
	close_button.pressed.connect(_on_close_button_pressed)
	
	var spacer1 = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 20)
	
	# Use HBox for buttons side-by-side
	var button_row = HBoxContainer.new()
	button_row.name = "ButtonRow"
	button_row.size_flags_horizontal = Control.SIZE_FILL
	button_row.add_theme_constant_override("separation", 15)
	
	var reset_button = Button.new()
	reset_button.text = "Reset Scene"
	reset_button.tooltip_text = "Reset the current scene"
	reset_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset_button.add_theme_font_size_override("font_size", 18)
	
	var reset_min_width = max(180, quick_tab.size.x * 0.25) # 25% of tab width or at least 180px
	reset_button.custom_minimum_size = Vector2(reset_min_width, 60)
	
	# Style the reset button (yellow/orange theme)
	var reset_normal_style = StyleBoxFlat.new()
	reset_normal_style.bg_color = Color(0.9, 0.6, 0.1, 1.0) # Orange/yellow for reset
	reset_normal_style.border_width_left = 2
	reset_normal_style.border_width_top = 2
	reset_normal_style.border_width_right = 2
	reset_normal_style.border_width_bottom = 2
	reset_normal_style.border_color = Color(0.95, 0.7, 0.2, 1.0)
	reset_normal_style.corner_radius_top_left = 8
	reset_normal_style.corner_radius_top_right = 8
	reset_normal_style.corner_radius_bottom_right = 8
	reset_normal_style.corner_radius_bottom_left = 8
	
	var reset_hover_style = reset_normal_style.duplicate()
	reset_hover_style.bg_color = Color(0.95, 0.7, 0.2, 1.0)
	
	var reset_pressed_style = reset_normal_style.duplicate()
	reset_pressed_style.bg_color = Color(0.8, 0.5, 0.1, 1.0)
	
	reset_button.add_theme_stylebox_override("normal", reset_normal_style)
	reset_button.add_theme_stylebox_override("hover", reset_hover_style)
	reset_button.add_theme_stylebox_override("pressed", reset_pressed_style)
	
	reset_button.pressed.connect(_on_reset_button_pressed)
	
	close_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL # Let close button fill remaining space
	
	button_row.add_child(reset_button)
	button_row.add_child(close_button)
	
	# Add elements to the main VBox
	vbox.add_child(title)
	vbox.add_child(spacer1)
	vbox.add_child(button_row)
	
	var separator = HSeparator.new()
	separator.size_flags_horizontal = Control.SIZE_FILL
	vbox.add_child(separator)
	
	var levels_title = Label.new()
	levels_title.text = "Launch Levels"
	levels_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	levels_title.add_theme_font_size_override("font_size", 18)
	levels_title.size_flags_horizontal = Control.SIZE_FILL
	vbox.add_child(levels_title)
	
	# Use a GridContainer for level buttons for better arrangement
	var grid = GridContainer.new()
	grid.name = "ButtonGrid"
	grid.columns = 2 # Use 2 columns for layout
	grid.add_theme_constant_override("h_separation", 15)
	grid.add_theme_constant_override("v_separation", 15)
	grid.size_flags_horizontal = Control.SIZE_FILL
	grid.size_flags_vertical = Control.SIZE_FILL
	vbox.add_child(grid)
	
	# Add specific level launch buttons
	_add_level_button(grid, "Beginning Level", "res://Yunhan Liu2/beginning.tscn")
	_add_level_button(grid, "Present Level", "res://Omar/present.tscn")
	_add_level_button(grid, "Past Level", "res://Sandhya/past.tscn")
	_add_level_button(grid, "Good Ending", "res://Yunhan Liu2/good.tscn")
	_add_level_button(grid, "Bad Ending", "res://Yunhan Liu2/bad.tscn")
	
	# Connect to window resize signal to adjust layout dynamically
	console.get_tree().root.size_changed.connect(_on_window_size_changed)

## Handles window resizing to adjust button sizes
func _on_window_size_changed() -> void:
	if not is_instance_valid(quick_tab):
		return
		
	# Update level button sizes
	var grid = quick_tab.get_node_or_null("MarginContainer/VBoxContainer/ButtonGrid")
	if grid:
		for button in grid.get_children():
			if button is Button:
				var min_width = max(150, quick_tab.size.x * 0.2) # 20% of tab width or at least 150px
				button.custom_minimum_size = Vector2(min_width, 40)
	
	# Update close/reset button sizes
	if is_instance_valid(close_button):
		var close_min_width = max(200, quick_tab.size.x * 0.3) # 30% of tab width or at least 200px
		close_button.custom_minimum_size = Vector2(close_min_width, 60)
	var reset_button = quick_tab.get_node_or_null("MarginContainer/VBoxContainer/ButtonRow/Button") # Assuming reset is first button
	if is_instance_valid(reset_button):
		var reset_min_width = max(180, quick_tab.size.x * 0.25) # 25% of tab width or at least 180px
		reset_button.custom_minimum_size = Vector2(reset_min_width, 60)

## Creates a level button, styles it, and adds it to the container
func _add_level_button(container: Container, button_text: String, scene_path: String) -> void:
	var button = Button.new()
	button.text = button_text
	button.tooltip_text = "Change to " + scene_path
	
	# Size flags for flexible layout within the grid
	button.size_flags_horizontal = Control.SIZE_FILL
	button.add_theme_font_size_override("font_size", 16)
	
	# Set initial minimum size, adjusts dynamically with window size
	var min_width = max(150, quick_tab.size.x * 0.2) # 20% of tab width or at least 150px
	button.custom_minimum_size = Vector2(min_width, 40)
	
	# Style the level button (blue theme)
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.2, 0.4, 0.6, 1.0) # Blue for level buttons
	normal_style.border_width_left = 1
	normal_style.border_width_top = 1
	normal_style.border_width_right = 1
	normal_style.border_width_bottom = 1
	normal_style.border_color = Color(0.3, 0.5, 0.7, 1.0)
	normal_style.corner_radius_top_left = 6
	normal_style.corner_radius_top_right = 6
	normal_style.corner_radius_bottom_right = 6
	normal_style.corner_radius_bottom_left = 6
	
	var hover_style = normal_style.duplicate()
	hover_style.bg_color = Color(0.3, 0.5, 0.7, 1.0)
	
	var pressed_style = normal_style.duplicate()
	pressed_style.bg_color = Color(0.1, 0.3, 0.5, 1.0)
	
	button.add_theme_stylebox_override("normal", normal_style)
	button.add_theme_stylebox_override("hover", hover_style)
	button.add_theme_stylebox_override("pressed", pressed_style)
	
	# Connect the button signal
	button.pressed.connect(_on_level_button_pressed.bind(scene_path))
	
	# Add to container
	container.add_child(button)

## Handle level button press
func _on_level_button_pressed(scene_path: String) -> void:
	console._console_log("Changing to scene: " + scene_path)
	
	# Check if the file exists
	if not FileAccess.file_exists(scene_path):
		console._console_log("[ERROR] Scene file not found: " + scene_path)
		return
	
	# Change scene
	var error = console.get_tree().change_scene_to_file(scene_path)
	if error != OK:
		console._console_log("[ERROR] Failed to change scene. Error code: " + str(error))
	else:
		# Hide console when changing scene
		console._hide_console()
		console._console_log("Successfully changed to scene: " + scene_path)

## Handle close button press
func _on_close_button_pressed() -> void:
	console._console_log("Close game button pressed")
	
	# Show a confirmation dialog
	var confirm_dialog = ConfirmationDialog.new()
	confirm_dialog.title = "Close Game"
	confirm_dialog.dialog_text = "Are you sure you want to exit the game?"
	confirm_dialog.min_size = Vector2(400, 100)
	
	# We need to add it to the tree to show it
	console.add_child(confirm_dialog)
	
	# Connect confirmation signal
	confirm_dialog.confirmed.connect(_on_close_confirmed)
	
	# Connect cancel signal for cleanup
	confirm_dialog.canceled.connect(func(): confirm_dialog.queue_free())
	
	# Show the dialog
	confirm_dialog.popup_centered()

## Handle confirmation of game closure
func _on_close_confirmed() -> void:
	console._console_log("Closing game...")
	console.get_tree().quit()

## Handle reset button press
func _on_reset_button_pressed() -> void:
	console._console_log("Reset scene button pressed")
	
	# Get the current scene
	var current_scene_path = console.get_tree().current_scene.scene_file_path
	if current_scene_path.is_empty():
		console._console_log("[ERROR] Could not determine current scene path")
		return
	
	console._console_log("Reloading current scene: " + current_scene_path)
	
	# Show a small confirmation dialog
	var confirm_dialog = ConfirmationDialog.new()
	confirm_dialog.title = "Reset Scene"
	confirm_dialog.dialog_text = "Are you sure you want to reset the current scene?"
	confirm_dialog.min_size = Vector2(400, 100)
	console.add_child(confirm_dialog)
	
	# Connect confirmation signal
	confirm_dialog.confirmed.connect(func():
		# Reload the current scene
		var err = console.get_tree().reload_current_scene()
		if err != OK:
			console._console_log("[ERROR] Failed to reload scene. Error code: " + str(err))
		else:
			# Hide console when scene resets
			console._hide_console()
			console._console_log("Successfully reset scene: " + current_scene_path)
	)
	
	# Connect cancel signal for cleanup
	confirm_dialog.canceled.connect(func(): confirm_dialog.queue_free())
	
	# Show the dialog
	confirm_dialog.popup_centered()

# endregion
