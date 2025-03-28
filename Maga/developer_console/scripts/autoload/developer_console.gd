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

@tool
extends CanvasLayer

## Main UI Panel
@onready var panel_container: PanelContainer = $PanelContainer
## Draggable Header Area
@onready var header: Panel = $PanelContainer/VBoxContainer/Header
## Toggle Button (outside the panel)
@onready var toggle_button: Button = $ToggleButton
## Close Button (inside the panel header)
@onready var close_button: Button = $PanelContainer/VBoxContainer/Header/CloseButton
## Tab Container
@onready var tab_container: TabContainer = $PanelContainer/VBoxContainer/TabContainer
## Console Output RichTextLabel
@onready var console_output: RichTextLabel = $PanelContainer/VBoxContainer/TabContainer/Console/VBoxContainer/Output
## Console Input LineEdit
@onready var console_input: LineEdit = $PanelContainer/VBoxContainer/TabContainer/Console/VBoxContainer/Input
## Scene List ItemList
@onready var scene_list: ItemList = $PanelContainer/VBoxContainer/TabContainer/Scene/SceneList
## Log Output RichTextLabel
@onready var log_output: RichTextLabel = $PanelContainer/VBoxContainer/TabContainer/Log/Output

# --- Configuration ---
const CONSOLE_HOTKEY: StringName = "ui_quoteleft" # Action to toggle console visibility (Tilde/Backtick key `)
const RESIZE_MARGIN: float = 10.0 # Pixels from edge to trigger resize

# --- State ---
var _is_dragging: bool = false
var _drag_start_offset: Vector2 = Vector2.ZERO
var _is_resizing: bool = false
var _resize_edge_h: String = "" # "left", "right", ""
var _resize_edge_v: String = "" # "top", "bottom", ""
var _resize_start_mouse_pos: Vector2 = Vector2.ZERO
var _resize_start_pos: Vector2 = Vector2.ZERO
var _resize_start_size: Vector2 = Vector2.ZERO
var _scenes_scanned: bool = false # Flag to scan scenes only once needed

# --- Extensions ---
var scene_manager = null # Will hold the scene manager extension

# --- Command & Expression Handling ---
var registered_commands: Dictionary = {} # { "command_name": { "callable": Callable, "description": String } }
var _expression: Expression = Expression.new()

# --- History ---
var _history: PackedStringArray = []
var _history_index: int = -1


# ============================================================================ #
# region Godot Lifecycle Methods
# ============================================================================ #

func _ready() -> void:
	# Connect signals only at runtime, not in editor
	if not Engine.is_editor_hint():
		toggle_button.pressed.connect(toggle)
		close_button.pressed.connect(_hide_console)
		header.gui_input.connect(_on_header_gui_input)
		panel_container.gui_input.connect(_on_panel_container_gui_input)
		panel_container.mouse_exited.connect(_on_panel_container_mouse_exited)
		console_input.text_submitted.connect(_on_console_input_submitted)
		console_input.gui_input.connect(_on_console_input_gui_input) # For history navigation
		scene_list.item_activated.connect(_on_scene_list_item_activated)
		tab_container.tab_changed.connect(_on_tab_changed)
	
	# Setup initial state
	panel_container.custom_minimum_size = Vector2(400, 300) # Set a decent minimum size
	_hide_console() # Start hidden
	_register_default_commands()
	_initialize_extensions() # Initialize scene manager extension
	
	# Use self.log explicitly to avoid ambiguity with built-in log
	# Get the first key event associated with the action and convert its physical keycode to a readable string
	var events = InputMap.action_get_events(CONSOLE_HOTKEY)
	var key_label = "`" # Default label if not found or not a key
	if not events.is_empty() and events[0] is InputEventKey:
		key_label = OS.get_keycode_string(events[0].physical_keycode)
	self.log("DeveloperConsole initialized. Press '%s' to toggle." % key_label)


func _input(event: InputEvent) -> void:
	# Disable input processing in the editor to avoid InputMap errors
	if Engine.is_editor_hint():
		return
	if ((InputMap.has_action(CONSOLE_HOTKEY) and event.is_action_pressed(CONSOLE_HOTKEY)) or (InputMap.has_action("ui_quoteleft") and event.is_action_pressed("ui_quoteleft"))) and not event.is_echo():
		toggle()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	# --- Update Mouse Cursor for Resizing ---
	if not Engine.is_editor_hint() and panel_container.visible and not _is_dragging and not _is_resizing:
		_update_resize_cursor()

# endregion


# ============================================================================ #
# region Public API (for Autoload usage: DeveloperConsole.log("..."))
# ============================================================================ #

## Toggles the visibility of the developer console UI.
func toggle() -> void:
	panel_container.visible = not panel_container.visible
	
	if panel_container.visible:
		# Show console and request cursor visibility
		panel_container.grab_focus() # Focus panel when shown
		console_input.grab_focus() # Focus input line
		
		# Request cursor visibility from the CursorManager
		if get_node_or_null("/root/Cursor"):
			get_node("/root/Cursor").request_cursor("console", true)
		
		# Scan scenes when console is opened and Scene tab exists, if not already scanned
		if is_instance_valid(scene_list) and tab_container.get_tab_idx_from_control(scene_list.get_parent()) != -1 and not _scenes_scanned:
			_scan_project_scenes()
	else:
		# Hide console and release cursor visibility request
		if get_node_or_null("/root/Cursor"):
			get_node("/root/Cursor").request_cursor("console", false)
		
		# Optional: Return focus to game viewport if needed
		# get_viewport().grab_focus()
		pass


## Logs a message to the Log tab. Adds a timestamp.
## Can be called from anywhere using DeveloperConsole.log("message")
func log(message: String) -> void:
	if not is_instance_valid(log_output): return # Avoid errors if called before ready or node deleted
	var timestamp = Time.get_datetime_string_from_system(false, true) # UTC=false, use_msec=true
	# Append with BBCode for potential formatting
	log_output.append_text("\n[%s] %s" % [timestamp, message])
	# Optional: Add color based on message type (e.g., check for "[ERROR]" prefix)


## Registers a custom command accessible via the console input.
## Example: DeveloperConsole.register_command("hello", Callable(self, "_cmd_hello"), "Prints a greeting.")
func register_command(command_name: String, command_callable: Callable, description: String = "") -> void:
	if registered_commands.has(command_name):
		printerr("DeveloperConsole: Command '%s' is already registered. Overwriting." % command_name)
	if not command_callable.is_valid():
		printerr("DeveloperConsole: Invalid Callable provided for command '%s'." % command_name)
		return
	registered_commands[command_name] = { "callable": command_callable, "description": description }
	self.log("Registered command: %s" % command_name) # Use self.log

#endregion


# ============================================================================ #
#region Internal Methods & Signal Callbacks
# ============================================================================ #

func _hide_console() -> void:
	panel_container.hide()
	# Release cursor visibility request
	if get_node_or_null("/root/Cursor"):
		get_node("/root/Cursor").request_cursor("console", false)

func _register_default_commands() -> void:
	register_command("help", Callable(self, "_cmd_help"), "Lists all available commands.")
	register_command("clear", Callable(self, "_cmd_clear"), "Clears the console output.")
	register_command("quit", Callable(self, "_cmd_quit"), "Quits the application.")
	register_command("log", Callable(self, "_cmd_log"), "Logs a message to the Log tab. Usage: log <message>")
	register_command("scene.change", Callable(self, "_cmd_scene_change"), "Changes scene by file path. Usage: scene.change <res://path/to/scene.tscn>")

# --- Command Implementations ---

func _cmd_help(_args: Array) -> String:
	var output_text = "Available commands:"
	# Sort command names alphabetically for better readability
	var sorted_keys = registered_commands.keys()
	sorted_keys.sort()
	for cmd_name in sorted_keys:
		output_text += "\n- %s" % cmd_name
		var description = registered_commands[cmd_name].get("description", "")
		if not description.is_empty():
			output_text += ": %s" % description
	return output_text

func _cmd_clear(_args: Array) -> String:
	console_output.clear()
	return "[i]Console cleared.[/i]" # Return confirmation string

func _cmd_quit(_args: Array) -> String:
	self.log("Quit command executed.") # Use self.log
	get_tree().quit()
	return "Quitting..." # This might not be seen if quit is immediate

func _cmd_log(args: Array) -> String:
	if args.is_empty():
		return "[color=yellow]Usage: log <message>[/color]"
	var message_to_log = " ".join(args) # Join args back into a string
	self.log("From console command: %s" % message_to_log) # Use self.log
	return "Logged to Log tab: '%s'" % message_to_log

func _cmd_scene_change(args: Array) -> String:
	if args.is_empty() or args.size() > 1:
		return "[color=yellow]Usage: scene.change <res://path/to/scene.tscn>[/color]"
	var scene_path = args[0]
	if not scene_path.begins_with("res://") or not scene_path.ends_with(".tscn"):
		return "[color=red]Error: Invalid scene path format. Must be like res://path/to/scene.tscn[/color]"

	# Check if file exists before attempting to change
	if FileAccess.file_exists(scene_path):
		self.log("Changing scene to: %s" % scene_path) # Use self.log
		var err = get_tree().change_scene_to_file(scene_path)
		if err == OK:
			# Scene change initiated, hide console to avoid issues during transition
			_hide_console()
			return "Changing scene to %s..." % scene_path
		else:
			return "[color=red]Error changing scene (code %d). Check Godot output.[/color]" % err
	else:
		return "[color=red]Error: Scene file not found at %s[/color]" % scene_path


# --- Input & UI Callbacks ---

func _on_console_input_submitted(text: String) -> void:
	if text.is_empty():
		return

	_add_console_output("\n[color=gray]> %s[/color]" % text) # Echo input
	console_input.clear()

	# Add to history (only if different from last entry)
	if _history.is_empty() or _history[_history.size() - 1] != text: # Use index access instead of back()
		_history.push_back(text)
		# Optional: Limit history size
		# if _history.size() > MAX_HISTORY_SIZE:
		#     _history.remove_at(0)
	_history_index = -1 # Reset history navigation index

	# Parse command and arguments
	var parts = text.strip_edges().split(" ", false, 1) # Split only on first space
	var command_name = parts[0]
	var args_str = parts[1] if parts.size() > 1 else ""
	# Further split args_str respecting quotes if needed (more complex parsing)
	# For simplicity now, we pass args as strings - command needs to parse/convert
	var args_array = args_str.split(" ", false) if not args_str.is_empty() else []

	# Execute
	if registered_commands.has(command_name):
		_execute_command(command_name, args_array)
	else:
		_evaluate_expression(text)


func _on_console_input_gui_input(event: InputEvent) -> void:
	# Handle history navigation (Up/Down arrows)
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		var handled = false
		if event.keycode == KEY_UP:
			if _history_index == -1: # Starting navigation or at the newest entry
				if not _history.is_empty():
					_history_index = _history.size() - 1
					console_input.text = _history[_history_index]
					handled = true
			elif _history_index > 0:
				_history_index -= 1
				console_input.text = _history[_history_index]
				handled = true

			if handled:
				console_input.caret_column = console_input.text.length() # Move cursor to end
				get_viewport().set_input_as_handled() # Use correct method

		elif event.keycode == KEY_DOWN:
			if _history_index != -1: # Currently navigating history
				if _history_index < _history.size() - 1:
					_history_index += 1
					console_input.text = _history[_history_index]
					handled = true
				else: # Reached the newest entry, clear input
					_history_index = -1
					console_input.clear()
					handled = true

				if handled:
					console_input.caret_column = console_input.text.length()
					get_viewport().set_input_as_handled() # Use correct method


func _add_console_output(text: String) -> void:
	# Ensure we don't try to append if the node isn't valid (e.g., during shutdown)
	if is_instance_valid(console_output):
		console_output.append_text("\n" + text)
		# Optional: Limit output lines to prevent performance issues
		# if console_output.get_line_count() > MAX_OUTPUT_LINES:
		#     console_output.remove_line(0) # Remove the oldest line

func _execute_command(command_name: String, args: Array) -> void:
	var cmd_data = registered_commands[command_name]
	var callable: Callable = cmd_data["callable"]
	if callable.is_valid():
		# We assume the callable handles argument parsing/validation for now
		# A more robust system would check expected arg types/counts here
		var result = callable.callv(args) # Pass args as an array
		if result != null: # Only print if the command returned something
			_add_console_output(str(result)) # Convert result to string
	else:
		_add_console_output("[color=red]Error: Invalid Callable for command '%s'.[/color]" % command_name)


func _evaluate_expression(code: String) -> void:
	var err = _expression.parse(code)
	if err != OK:
		_add_console_output("[color=red]Expression Parse Error: %s[/color]" % _expression.get_error_text())
		return

	# Execute the expression - base_instance=self allows accessing console's own methods/vars
	# Note: Be careful executing arbitrary code!
	var result = _expression.execute([], self, true) # show_error=true

	if _expression.has_execute_failed():
		# Error already printed by execute() if show_error is true
		# _add_console_output("[color=red]Expression Execute Error.[/color]") # Simpler message
		pass # Error text is already output by Expression.execute with show_error=true
	else:
		if result != null:
			_add_console_output(str(result))
		else:
			_add_console_output("[i]Expression returned null or void.[/i]")


func _scan_project_scenes() -> void:
	# If we have the scene manager extension, let it handle scene scanning
	if scene_manager != null:
		# The scene manager will handle the scene scanning
		self.log("Using SceneManager extension for scene scanning...")
		return
		
	# Otherwise, use the original implementation
	self.log("Scanning for scene files...") # Use self.log
	scene_list.clear()
	
	# FIX: Use the correct method to check if the directory exists in Godot 4
	var dir = DirAccess.open("res://")
	if dir == null:
		printerr("DeveloperConsole: Failed to open root directory 'res://'. Error code: ", DirAccess.get_open_error())
		self.log("[ERROR] Failed to scan scenes: Cannot access 'res://'.") # Use self.log
		return

	var queue: Array = ["res://"] # Use standard Array for pop_front()
	var found_scenes: PackedStringArray = []

	while not queue.is_empty():
		var current_path = queue.pop_front() # pop_front works on Array
		if typeof(current_path) != TYPE_STRING:
			printerr("DeveloperConsole: Non-string path found in scan queue:", current_path)
			continue # Skip non-string paths

		dir = DirAccess.open(current_path)
		if dir:
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
					# Exclude .git and .godot directories from scan
					if file_name != ".git" and file_name != ".godot":
						queue.push_back(full_path)
				elif file_name.ends_with(".tscn"):
					found_scenes.push_back(full_path)

				file_name = dir.get_next()
		else:
			printerr("DeveloperConsole: Failed to open directory: %s" % current_path)

	found_scenes.sort()
	for scene_path in found_scenes:
		# Add item with path as text and maybe tooltip
		scene_list.add_item(scene_path.replace("res://", ""), null, true) # Use relative path for display
		scene_list.set_item_tooltip(scene_list.item_count - 1, scene_path) # Store full path in tooltip

	_scenes_scanned = true
	self.log("Scene scan complete. Found %d scenes." % scene_list.item_count) # Use self.log


func _on_scene_list_item_activated(index: int) -> void:
	if index < 0 or index >= scene_list.item_count:
		return
	var scene_path = scene_list.get_item_tooltip(index) # Get full path from tooltip
	if scene_path.is_empty():
		_add_console_output("[color=red]Error: Could not get scene path for selected item.[/color]")
		return

	_add_console_output("Attempting to change scene to: %s" % scene_path)
	var result_str = _cmd_scene_change([scene_path]) # Reuse command logic
	_add_console_output(result_str)


func _on_tab_changed(tab_idx: int) -> void:
	var tab_control = tab_container.get_tab_control(tab_idx)
	
	if scene_manager != null and is_instance_valid(tab_control) and tab_control == scene_list.get_parent():
		scene_manager.scan_scenes()
		return
	
	if is_instance_valid(scene_list) and is_instance_valid(tab_control) and tab_control == scene_list.get_parent() and not _scenes_scanned:
		_scan_project_scenes()


# --- Dragging & Resizing Logic ---

func _on_header_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.is_pressed():
				_is_dragging = true
				_drag_start_offset = panel_container.get_global_mouse_position() - panel_container.global_position
				get_viewport().set_input_as_handled()
			else:
				_is_dragging = false
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		if _is_dragging:
			panel_container.global_position = panel_container.get_global_mouse_position() - _drag_start_offset
			get_viewport().set_input_as_handled()


func _on_panel_container_gui_input(event: InputEvent) -> void:
	var mouse_pos = panel_container.get_local_mouse_position()
	var panel_size = panel_container.size

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.is_pressed():
				_resize_edge_h = ""
				_resize_edge_v = ""
				
				if mouse_pos.x < RESIZE_MARGIN:
					_resize_edge_h = "left"
				elif mouse_pos.x > panel_size.x - RESIZE_MARGIN:
					_resize_edge_h = "right"
					
				if mouse_pos.y < RESIZE_MARGIN:
					_resize_edge_v = "top"
				elif mouse_pos.y > panel_size.y - RESIZE_MARGIN:
					_resize_edge_v = "bottom"

				if _resize_edge_h != "" or _resize_edge_v != "":
					_is_resizing = true
					_resize_start_mouse_pos = panel_container.get_global_mouse_position()
					_resize_start_pos = panel_container.global_position
					_resize_start_size = panel_container.size
				
				get_viewport().set_input_as_handled()
			else:
				if _is_resizing:
					_is_resizing = false
					_resize_edge_h = ""
					_resize_edge_v = ""
				
				panel_container.mouse_default_cursor_shape = Control.CURSOR_ARROW
				get_viewport().set_input_as_handled()

	elif event is InputEventMouseMotion:
		if _is_resizing:
			var global_mouse_pos = panel_container.get_global_mouse_position()
			var delta = global_mouse_pos - _resize_start_mouse_pos
			var new_pos = _resize_start_pos
			var new_size = _resize_start_size
			var min_size = panel_container.custom_minimum_size

			if _resize_edge_h == "left":
				new_pos.x = _resize_start_pos.x + delta.x
				new_size.x = _resize_start_size.x - delta.x
				if new_size.x < min_size.x:
					new_size.x = min_size.x
					new_pos.x = _resize_start_pos.x + _resize_start_size.x - min_size.x
			elif _resize_edge_h == "right":
				new_size.x = _resize_start_size.x + delta.x
				new_size.x = max(new_size.x, min_size.x)

			if _resize_edge_v == "top":
				new_pos.y = _resize_start_pos.y + delta.y
				new_size.y = _resize_start_size.y - delta.y
				if new_size.y < min_size.y:
					new_size.y = min_size.y
					new_pos.y = _resize_start_pos.y + _resize_start_size.y - min_size.y
			elif _resize_edge_v == "bottom":
				new_size.y = _resize_start_size.y + delta.y
				new_size.y = max(new_size.y, min_size.y)

			panel_container.global_position = new_pos
			panel_container.size = new_size
			
			get_viewport().set_input_as_handled()


func _update_resize_cursor() -> void:
	var mouse_pos: Vector2 = panel_container.get_local_mouse_position()
	var panel_size: Vector2 = panel_container.size
	var current_edge_h: String = ""
	var current_edge_v: String = ""

	if mouse_pos.x < RESIZE_MARGIN: current_edge_h = "left"
	elif mouse_pos.x > panel_size.x - RESIZE_MARGIN: current_edge_h = "right"
	if mouse_pos.y < RESIZE_MARGIN: current_edge_v = "top"
	elif mouse_pos.y > panel_size.y - RESIZE_MARGIN: current_edge_v = "bottom"

	var cursor_shape = Control.CURSOR_ARROW # Default
	if current_edge_h == "left" and current_edge_v == "top": cursor_shape = Control.CURSOR_BDIAGSIZE
	elif current_edge_h == "right" and current_edge_v == "bottom": cursor_shape = Control.CURSOR_BDIAGSIZE
	elif current_edge_h == "right" and current_edge_v == "top": cursor_shape = Control.CURSOR_FDIAGSIZE
	elif current_edge_h == "left" and current_edge_v == "bottom": cursor_shape = Control.CURSOR_FDIAGSIZE
	elif current_edge_h != "": cursor_shape = Control.CURSOR_HSIZE
	elif current_edge_v != "": cursor_shape = Control.CURSOR_VSIZE

	panel_container.mouse_default_cursor_shape = cursor_shape


func _on_panel_container_mouse_exited() -> void:
	if not _is_resizing: # Don't reset cursor if actively resizing
		panel_container.mouse_default_cursor_shape = Control.CURSOR_ARROW

# endregion

# Initialize all extensions
func _initialize_extensions() -> void:
	# Initialize Scene Manager
	var SceneManagerClass = load("res://Maga/developer_console/scripts/autoload/developer_console_scene.gd")
	if SceneManagerClass:
		scene_manager = SceneManagerClass.new()
		scene_manager.initialize(self)
	else:
		printerr("Failed to load Scene Manager extension")
