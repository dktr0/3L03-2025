# .----------------------------------------------------------------------------.
# |:::    :::     :::     :::        ::::::::  :::   :::  ::::::::  ::::    :::|
# |:+:    :+:   :+: :+:   :+:       :+:    :+: :+:   :+: :+:    :+: :+:+:   :+:|
# |+:+    +:+  +:+   +:+  +:+       +:+         +:+ +:+  +:+    +:+ :+:+:+  +:+|
# |+#++:++#++ +#++:++#++: +#+       +#+          +#++:   +#+    +:+ +#+ +:+ +#+|
# |+#+    +#+ +#+     +#+ +#+       +#+           +#+    +#+    +#+ +#+  +#+#+#|
# |#+#    #+# #+#     #+# #+#       #+#    #+#    #+#    #+#    #+# #+#   #+#+#|
# |###    ### ###     ### ########## ########     ###     ########  ###    ####|
# '----------------------------------------------------------------------------'
# Developer Console Autoload Script
#
#
# Developed by:
# - Liam Maga
# - 
# - 
# .----------------------------------------------------------------------------.

@tool
extends CanvasLayer

# --- Signals ---
signal command_registered(command_name: String, description: String)
# signal command_unregistered(command_name: String) # Commented out: Unused signal

# --- Constants ---
const HISTORY_MAX_SIZE = 50 # Maximum number of commands to store in history
const DEFAULT_COMMAND_PREFIX = "/" # Default command prefix

# --- Variables ---
# Numeric log levels (initialized via Logger singleton if available)
var _log_level_info: int = 1 # Default fallback if Logger not found
var _log_level_warning: int = 2
var _log_level_error: int = 3
var _log_level_debug: int = 0
var _log_level_fatal: int = 4
var DEFAULT_LOG_LEVEL: int # Set in _ready based on Logger or fallback

# --- Node References ---
@onready var panel_container: PanelContainer = $PanelContainer
@onready var tab_container: TabContainer = $PanelContainer/VBoxContainer/TabContainer
@onready var console_input: LineEdit = $PanelContainer/VBoxContainer/TabContainer/Console/VBoxContainer/Input
@onready var console_output: RichTextLabel = $PanelContainer/VBoxContainer/TabContainer/Console/VBoxContainer/Output
@onready var toggle_button: Button = $ToggleButton
@onready var close_button: Button = $PanelContainer/VBoxContainer/Header/CloseButton
@onready var header: Panel = $PanelContainer/VBoxContainer/Header # Needed for dragging functionality
# References potentially needed by extensions or commands
@onready var scene_list: ItemList = $PanelContainer/VBoxContainer/TabContainer/Scene/VBoxContainer/SceneList
@onready var scene_search: LineEdit = $PanelContainer/VBoxContainer/TabContainer/Scene/VBoxContainer/SceneSearch
@onready var log_output: RichTextLabel = $PanelContainer/VBoxContainer/TabContainer/Log/VBoxContainer/Output

# --- Command Management ---
var commands: Dictionary = {} # Stores registered commands { "name": { "callable": Callable, "description": String, "args": Array[String] } }
var command_history: Array[String] = [] # Stores executed commands for history navigation
var history_index: int = -1 # Current position in command history (for up/down arrow)

# --- State ---
# Removed shadowed/redundant variable
# var is_visible: bool = false 

# --- Child Managers ---
# Removed type hints to resolve scope errors temporarily.
# Add class_name definitions to the manager scripts later.
var quick_actions_manager # : DeveloperConsoleQuickActionsManager
var scene_manager # : DeveloperConsoleSceneManager
var log_manager # : DeveloperConsoleLogManager
var search_manager # : DeveloperConsoleSearchManager

# --- Initialization ---
var is_initialized: bool = false

# ============================================================================ #
# region Godot Lifecycle Methods (Primary Definition)
# ============================================================================ #

func _ready() -> void:
	# Initialize Log Level variables safely using Logger Autoload if present
	if Engine.has_singleton("Logger"):
		var LoggerSingleton = Engine.get_singleton("Logger")
		if LoggerSingleton.has_meta("LogLevel"):
			var LogLevel = LoggerSingleton.LogLevel # Access LogLevel enum via the singleton instance
			if "INFO" in LogLevel: _log_level_info = LogLevel.INFO
			if "WARNING" in LogLevel: _log_level_warning = LogLevel.WARNING
			if "ERROR" in LogLevel: _log_level_error = LogLevel.ERROR
			if "DEBUG" in LogLevel: _log_level_debug = LogLevel.DEBUG
			if "FATAL" in LogLevel: _log_level_fatal = LogLevel.FATAL
		else:
			# Log error only if not in editor, as Logger might not be set up there
			if not Engine.is_editor_hint(): 
				printerr("DeveloperConsole: Logger Autoload or LogLevel not found/valid. Using fallback numeric log levels.")
	
	# Set the default log level using the potentially updated numeric value
	DEFAULT_LOG_LEVEL = _log_level_info
	
	# Prevent full initialization and hide UI elements in the Godot editor
	if Engine.is_editor_hint():
		if is_instance_valid(toggle_button):
			toggle_button.visible = false
		return # Stop initialization here if in editor

	# --- Proceed only if not in editor and not already initialized ---
	if is_initialized:
		return

	self._console_log("Developer Console Initializing...")

	# Set initial UI visibility state
	panel_container.visible = false
	if is_instance_valid(toggle_button):
		toggle_button.visible = true # Ensure toggle button is visible at runtime start

	# --- Connect Signals for UI Interaction and Functionality ---
	# Check node validity and prevent duplicate connections
	if is_instance_valid(toggle_button) and not toggle_button.is_connected("pressed", _on_toggle_button_pressed):
		toggle_button.pressed.connect(_on_toggle_button_pressed)
	if is_instance_valid(close_button) and not close_button.is_connected("pressed", _on_close_button_pressed):
		close_button.pressed.connect(_on_close_button_pressed)
	if is_instance_valid(console_input) and not console_input.is_connected("text_submitted", _on_input_submitted):
		console_input.text_submitted.connect(_on_input_submitted)
	# Connect input signals for history navigation (up/down arrows)
	if is_instance_valid(console_input) and not console_input.is_connected("gui_input", _on_console_input_gui_input):
		console_input.gui_input.connect(_on_console_input_gui_input)
	# Connect signals for dragging and resizing the console panel
	if is_instance_valid(header) and !header.is_connected("gui_input", _on_header_gui_input):
		header.gui_input.connect(_on_header_gui_input)
	if is_instance_valid(panel_container):
		if !panel_container.is_connected("gui_input", _on_panel_container_gui_input):
			panel_container.gui_input.connect(_on_panel_container_gui_input)
		if !panel_container.is_connected("mouse_exited", _on_panel_container_mouse_exited):
			panel_container.mouse_exited.connect(_on_panel_container_mouse_exited)
		if !panel_container.is_connected("draw", _draw_resize_handles):
			panel_container.draw.connect(_draw_resize_handles)
	# Connect tab changed signal to handle tab-specific logic
	if is_instance_valid(tab_container) and !tab_container.is_connected("tab_changed", _on_tab_changed):
		tab_container.tab_changed.connect(_on_tab_changed)
			
	# --- Initialize Child Managers ---
	# Load manager scripts (use class_name if defined in those scripts, otherwise preload path)
	var QuickActionsManagerClass = load("res://Maga/developer_console/scripts/developer_console_scene_quick.gd")
	var SceneManagerClass = load("res://Maga/developer_console/scripts/developer_console_scene_scene.gd")
	var LogManagerClass = load("res://Maga/developer_console/scripts/developer_console_scene_logs.gd")
	var SearchManagerClass = load("res://Maga/developer_console/scripts/developer_console_scene_search.gd")
	
	if QuickActionsManagerClass: quick_actions_manager = QuickActionsManagerClass.new()
	else: printerr("Failed to load QuickActionsManager script")
	if SceneManagerClass: scene_manager = SceneManagerClass.new()
	else: printerr("Failed to load SceneManager script")
	if LogManagerClass: log_manager = LogManagerClass.new()
	else: printerr("Failed to load LogManager script")
	if SearchManagerClass: search_manager = SearchManagerClass.new()
	else: printerr("Failed to load SearchManager script")
	
	# Pass console reference to managers if they were loaded successfully
	if quick_actions_manager: quick_actions_manager.initialize(self)
	if scene_manager: scene_manager.initialize(self)
	if log_manager: log_manager.initialize(self)
	if search_manager: search_manager.initialize(self) # Initialize the search manager
	
	# Register built-in console commands
	_register_core_commands()
	
	self._console_log("Welcome to the Developer Console! Type 'help' for commands.", DEFAULT_LOG_LEVEL, "DEV_CONSOLE")

	is_initialized = true
	self._console_log("Developer Console Initialized Successfully.", DEFAULT_LOG_LEVEL, "DEV_CONSOLE")


func _unhandled_input(event: InputEvent) -> void:
	# Ignore input processing in the editor
	if Engine.is_editor_hint():
		return
		
	# Toggle console visibility using the defined hotkey action
	if InputMap.has_action(CONSOLE_HOTKEY) and event.is_action_pressed(CONSOLE_HOTKEY) and not event.is_echo():
		toggle()
		get_viewport().set_input_as_handled() # Prevent game from processing the key
	# Fallback check for the default key if the action isn't defined (optional, provides robustness)
	elif event is InputEventKey and event.keycode == KEY_QUOTELEFT and event.is_pressed() and not event.is_echo():
		printerr("Warning: Input action '%s' not found. Using default backtick key for console toggle." % CONSOLE_HOTKEY)
		toggle()
		get_viewport().set_input_as_handled()

# --- Configuration ---
const CONSOLE_HOTKEY: StringName = "ui_quoteleft" # Action to toggle console visibility (Tilde/Backtick key `)
const RESIZE_MARGIN: float = 8.0 # Pixels from edge to detect resize hover
const RESIZE_BORDER_COLOR: Color = Color(0.6, 0.6, 0.6, 0.5) # Visual indicator for resize handles

# --- State Variables for Dragging and Resizing ---
var _is_dragging: bool = false
var _drag_start_offset: Vector2 = Vector2.ZERO
var _is_resizing: bool = false
var _resize_edge_h: String = "" # Horizontal resize edge ("left", "right", "")
var _resize_edge_v: String = "" # Vertical resize edge ("top", "bottom", "")
var _resize_start_mouse_pos: Vector2 = Vector2.ZERO
var _resize_start_pos: Vector2 = Vector2.ZERO
var _resize_start_size: Vector2 = Vector2.ZERO
var _hover_edge_h: String = "" # For visual feedback (cursor change)
var _hover_edge_v: String = "" # For visual feedback (cursor change)

# --- State Variables for Scene Management ---
var _scenes_scanned: bool = false # Flag to scan scenes only once when needed
var _all_scene_items: Array = [] # Cache for all scene items (used by search/filter)

# --- Extensions ---
var quick_manager = null # Note: Seems distinct from quick_actions_manager - Check if intended

# --- Command & Expression Handling ---
# Keeping `commands` as defined in the script earlier
# var registered_commands: Dictionary = {} # This was likely a rename artifact

# --- History ---
# command_history and history_index already defined

# ============================================================================ #
# region Godot Lifecycle Methods (No Duplicates Found)
# ============================================================================ #

# Note: No duplicate _ready found.

# Note: _input function seems fine, no duplicate found here in the read file.

func _process(_delta: float) -> void:
	# Update mouse cursor style when hovering over resize edges
	if not Engine.is_editor_hint() and is_instance_valid(panel_container) and panel_container.visible and not _is_dragging and not _is_resizing:
		_update_resize_cursor()

# endregion

# ============================================================================ #
# region Public API (for Autoload usage: DeveloperConsole.toggle(), etc.)
# ============================================================================ #

## Toggles the visibility of the developer console UI.
func toggle() -> void:
	if not is_instance_valid(panel_container):
		printerr("Developer Console PanelContainer node is not valid!")
		return
		
	panel_container.visible = not panel_container.visible
	
	if panel_container.visible:
		# Actions when showing the console
		panel_container.grab_focus() # Ensure panel can receive input
		
		# Default to the Quick tab (index 0) when opening
		if is_instance_valid(tab_container):
			tab_container.current_tab = 0
		
		# If the Console tab (index 1) is somehow active, focus the input
		if is_instance_valid(tab_container) and tab_container.current_tab == 1 and is_instance_valid(console_input):
			console_input.grab_focus()
			
		# Update mouse mode if needed (e.g., if game hides cursor)
		if Input.get_mouse_mode() != Input.MOUSE_MODE_VISIBLE:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		# Actions when hiding the console
		if console_input.has_focus():
			console_input.release_focus()
		# Potentially restore previous mouse mode if game requires it (needs more logic)
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED) # Restore captured mouse mode

## Logs a message to the console output and optionally to Godot's output/Logger
## Adjusted to match the signature used in _ready
func _console_log(message: String, level = -1, source: String = "Console") -> void: # Use -1 default to check if level was provided
	var actual_level = level if level != -1 else DEFAULT_LOG_LEVEL # Use default if not provided

	if log_manager and log_manager.has_method("add_log_entry"):
		log_manager.add_log_entry(message, actual_level, source)
		return # Let log_manager handle output

	# Fallback if log_manager is not available or doesn't have the method
	var timestamp = Time.get_datetime_string_from_system(false, true) # Get timestamp HH:MM:SS
	var color_tag = _get_log_level_color(actual_level)
	var level_str = "INFO" # Default level string
	# Safely get level string if Logger exists
	if Engine.has_singleton("Logger"):
		var LoggerSingleton = Engine.get_singleton("Logger") # Get instance
		if LoggerSingleton.has_method("log_level_to_string"): 
			level_str = LoggerSingleton.log_level_to_string(actual_level) # Use instance
	else: 
		# Fallback level string 
		match actual_level:
			_log_level_debug: level_str = "DEBUG"
			_log_level_info: level_str = "INFO"
			_log_level_warning: level_str = "WARNING"
			_log_level_error: level_str = "ERROR"
			_log_level_fatal: level_str = "FATAL"
			_: level_str = "LEVEL_%d" % actual_level 
	
	var formatted_message = "[color={color_tag}][{timestamp}] [{source}] {level_str}: {message}[/color]".format({
		"color_tag": color_tag,
		"timestamp": timestamp,
		"source": source,
		"level_str": level_str,
		"message": message
	})

	if is_instance_valid(console_output):
		console_output.append_text(formatted_message + "\n") # Use \n for RichTextLabel newline
	else:
		print("Console Output node is not valid!")

	# Print to external Logger if available
	if Engine.has_singleton("Logger"):
		var LoggerSingleton = Engine.get_singleton("Logger") # Get instance
		if LoggerSingleton.has_method("log"): 
			LoggerSingleton.log(message, actual_level, source) # Use instance
	else:
		# Fallback to standard print 
		var numeric_warning_level = _log_level_warning 
		# Check Logger existence again just for the meta check, but use stored numeric level
		if Engine.has_singleton("Logger"):
			var LoggerSingletonCheck = Engine.get_singleton("Logger")
			if LoggerSingletonCheck.has_meta("LogLevel") and "WARNING" in LoggerSingletonCheck.LogLevel: 
				pass # Log level already set correctly
			if actual_level >= numeric_warning_level: 
				printerr("[{source}] {level_str}: {message}".format({"source": source, "level_str": level_str, "message": message}))
			else:
				print("[{source}] {level_str}: {message}".format({"source": source, "level_str": level_str, "message": message}))


## Registers a custom command accessible via the console input.
## Example: DeveloperConsole.register_command("hello", Callable(self, "_cmd_hello"), "Prints a greeting.")
## Updated to match the first declaration of commands dictionary
func register_command(command_name: String, command_callable: Callable, description: String = "", arg_types: Array[String] = []) -> bool:
	var clean_name = command_name.to_lower().strip_edges()
	if clean_name.is_empty():
		self._console_log("Error: Cannot register command with empty name.", _log_level_error)
		return false
		
	# Check the correct dictionary name (used `commands` earlier)
	if commands.has(clean_name):
		self._console_log("Warning: Command '%s' already registered. Overwriting." % clean_name, _log_level_warning)

	if not command_callable.is_valid():
		self._console_log("Error: Invalid Callable provided for command '%s'." % clean_name, _log_level_error)
		return false

	commands[clean_name] = {
		"callable": command_callable,
		"description": description,
		"args": arg_types # Store expected argument types
	}
	self._console_log("Command registered: %s" % clean_name, _log_level_debug)
	command_registered.emit(clean_name, description)
	return true

#endregion


# ============================================================================ #
#region Internal Methods & Signal Callbacks (Restored)
# ============================================================================ #

func _hide_console() -> void:
	# Use panel visibility directly
	if is_instance_valid(panel_container): panel_container.visible = false
	# is_visible = false # Removed
	# Release cursor visibility request
	if has_node("/root/Cursor") and get_node("/root/Cursor").has_method("request_cursor"):
		get_node("/root/Cursor").request_cursor("console", false)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED) # Restore captured mouse mode

func _register_core_commands() -> void:
	if has_method("_command_help"): register_command("help", Callable(self, "_command_help"), "Lists available commands or shows help for a specific command.", ["string"])
	if has_method("_command_clear"): register_command("clear", Callable(self, "_command_clear"), "Clears the console output.")
	if has_method("_command_echo"): register_command("echo", Callable(self, "_command_echo"), "Prints the given arguments back to the console.", ["string"])
	if has_method("_command_quit"): register_command("quit", Callable(self, "_command_quit"), "Quits the application.")
	if has_method("_cmd_log"): register_command("log", Callable(self, "_cmd_log"), "Logs a message to the Log tab. Usage: log <message>")
	if has_method("_cmd_log_clear"): register_command("log.clear", Callable(self, "_cmd_log_clear"), "Clears the log output.")
	if has_method("_cmd_scene_change"): register_command("scene.change", Callable(self, "_cmd_scene_change"), "Changes scene by file path. Usage: scene.change <res://path/to/scene.tscn>")

# --- Command Implementations (Restored) ---

## Command: help - Lists commands or shows details for one
## Updated to match the `commands` dictionary structure
func _command_help(command_to_help: String = "") -> void:
	if command_to_help.is_empty():
		self._console_log("Available Commands (use 'help <command>' for details):")
		var command_names = commands.keys()
		command_names.sort()
		for cmd_name in command_names:
			var desc = commands[cmd_name].get("description", "No description available.")
			self._console_log("- %s: %s" % [cmd_name, desc])
	else:
		var clean_name = command_to_help.to_lower().strip_edges()
		if commands.has(clean_name):
			var data = commands[clean_name]
			var desc = data.get("description", "No description available.")
			var args: Array[String] = data.get("args", [])
			var usage = DEFAULT_COMMAND_PREFIX + clean_name
			if not args.is_empty():
				usage += " <" + "> <".join(args) + ">"
			self._console_log("Help for '%s':" % clean_name)
			self._console_log("  Usage: %s" % usage)
			self._console_log("  Description: %s" % desc)
		else:
			self._console_log("Error: Command '%s' not found." % clean_name, _log_level_error)

## Command: clear - Clears the console output
func _command_clear() -> void:
	if is_instance_valid(console_output):
		console_output.clear()
		self._console_log("Console cleared.", _log_level_debug) # Use stored debug level

## Command: echo - Prints arguments back
func _command_echo(message: String) -> void: # Now strictly takes one string arg
	self._console_log(message, DEFAULT_LOG_LEVEL, "ECHO")

## Command: quit - Exits the application
func _command_quit() -> void:
	self._console_log("Quitting application...")
	get_tree().quit()

# Restored other command implementations
func _cmd_log(args: Array) -> String:
	if log_manager != null and log_manager.has_method("handle_log_command"):
		return log_manager.handle_log_command(args)
	else:
		if args.is_empty():
			return "[color=yellow]Usage: log <message>[/color]"
		var message_to_log = " ".join(args) # Join args back into a string
		self._console_log("From console command: %s" % message_to_log) # Explicitly use renamed function here too
		return "Logged to Log tab: '%s'" % message_to_log

func _cmd_log_clear(_args: Array) -> String:
	if log_manager != null and log_manager.has_method("clear_log"):
		log_manager.clear_log()
		return "[i]Log cleared.[/i]"
	else:
		# Fallback if log manager or method is missing
		if is_instance_valid(log_output):
			log_output.clear()
			return "[i]Log cleared (fallback).[/i]"
		return "[color=red]Log manager not initialized or clear_log method missing.[/color]"

func _cmd_scene_change(args: Array) -> String:
	if args.is_empty() or args.size() > 1:
		return "[color=yellow]Usage: scene.change <res://path/to/scene.tscn>[/color]"
	var scene_path = args[0]
	if not typeof(scene_path) == TYPE_STRING or not scene_path.begins_with("res://") or not scene_path.ends_with(".tscn"):
		return "[color=red]Error: Invalid scene path format. Must be a string like res://path/to/scene.tscn[/color]"

	# Check if file exists before attempting to change
	if FileAccess.file_exists(scene_path):
		self._console_log("Changing scene to: %s" % scene_path)
		var err = get_tree().change_scene_to_file(scene_path)
		if err == OK:
			# Scene change initiated, hide console to avoid issues during transition
			_hide_console()
			return "Changing scene to %s..." % scene_path
		else:
			return "[color=red]Error changing scene (code %d). Check Godot output.[/color]" % err
	else:
		return "[color=red]Error: Scene file not found at %s[/color]" % scene_path

# --- Input & UI Callbacks (Restored/Combined) ---

func _on_toggle_button_pressed() -> void:
	toggle()

func _on_close_button_pressed() -> void:
	_hide_console()

func _on_input_submitted(text: String) -> void:
	if text.is_empty():
		return

	self._console_log("> " + text, _log_level_debug, "INPUT") # Use renamed function

	# Add to history
	if command_history.is_empty() or command_history.back() != text:
		command_history.append(text)
		if command_history.size() > HISTORY_MAX_SIZE:
			command_history.remove_at(0)
	history_index = -1 # Reset history navigation index

	# Clear input field
	if is_instance_valid(console_input): console_input.clear()

	# Process the input
	_process_input(text)

## Processes the raw input string to execute command or expression
func _process_input(input_string: String) -> void:
	var trimmed_input = input_string.strip_edges()

	if trimmed_input.begins_with(DEFAULT_COMMAND_PREFIX):
		# It's potentially a command
		var parts = trimmed_input.substr(DEFAULT_COMMAND_PREFIX.length()).split(" ", false, 1) # Split only once
		var command_name = parts[0].to_lower()
		var args_string = ""
		if parts.size() > 1:
			args_string = parts[1].strip_edges()

		if commands.has(command_name):
			_execute_command(command_name, args_string)
		else:
			self._console_log("Error: Unknown command '%s'. Type 'help' for available commands." % command_name, _log_level_error)
	else:
		# Treat as an expression (or potentially fallback if needed)
		_evaluate_expression(trimmed_input)

## Executes a registered command (Restored/Combined)
func _execute_command(command_name: String, args_string: String) -> void: # Changed from args: Array
	if not commands.has(command_name):
		self._console_log("Error: Command '%s' not found internally." % command_name, _log_level_error)
		return

	var command_data: Dictionary = commands[command_name]
	var command_callable: Callable = command_data["callable"]
	var expected_arg_types: Array[String] = command_data.get("args", []) # Get expected arg types

	# --- Argument Parsing --- 
	var provided_args: Array = []
	var error_parsing_args = false
	# Simple split by space - adjust if quotes needed
	var raw_args = args_string.split(" ", false) if not args_string.is_empty() else PackedStringArray() 

	if raw_args.size() != expected_arg_types.size():
		# Allow zero args if none expected
		if not (raw_args.is_empty() and expected_arg_types.is_empty()): 
			self._console_log("Error: Command '%s' expects %d arguments, but %d were given ('%s')." % [command_name, expected_arg_types.size(), raw_args.size(), args_string], _log_level_error)
			error_parsing_args = true
	else:
		for i in range(raw_args.size()):
			var raw_arg = raw_args[i]
			var expected_type = expected_arg_types[i].to_lower()
			var parsed_arg = _parse_argument(raw_arg, expected_type)
			if parsed_arg == null and expected_type not in ["string", "variant"]: # Allow null only if parsing failed for non-strings/variants
				self._console_log("Error: Could not parse argument %d ('%s') for command '%s' as type '%s'." % [i + 1, raw_arg, command_name, expected_type], _log_level_error)
				error_parsing_args = true
				break # Stop parsing on first error
			provided_args.append(parsed_arg)

	if error_parsing_args:
		return # Don't attempt to call if arguments are wrong

	# --- Execute Callable --- 
	var result # Store the result if any
	var call_error = false
	var error_message = ""

	if provided_args.is_empty():
		if command_callable.get_argument_count() == 0:
			result = command_callable.call() # Use call() for zero args
		else:
			# Check if args were expected but parsing resulted in empty (e.g. only whitespace provided)
			if expected_arg_types.is_empty(): 
				result = command_callable.call()
			else:
				error_message = "Command '%s' callable expects arguments, but none parsed/provided correctly." % command_name
				call_error = true
	else:
		if command_callable.get_argument_count() == provided_args.size():
			result = command_callable.callv(provided_args) # Use callv for array args
		else:
			error_message = "Argument count mismatch between parsed arguments (%d) and callable for command '%s' (%d)." % [provided_args.size(), command_name, command_callable.get_argument_count()]
			call_error = true

	if call_error:
		self._console_log("Error executing command '%s': %s" % [command_name, error_message], _log_level_error)
	else:
		self._console_log("Executed command: %s" % command_name, _log_level_debug)
		if result != null:
			self._console_log("Result: %s" % str(result))

## Parses a string argument into a specific type (Restored)
func _parse_argument(arg_string: String, type_hint: String) -> Variant:
	match type_hint:
		"string":
			return arg_string # No conversion needed
		"int":
			if arg_string.is_valid_int(): return arg_string.to_int()
			else: return null # Indicate parsing failure
		"float":
			if arg_string.is_valid_float(): return arg_string.to_float()
			else: return null
		"bool":
			var lower_arg = arg_string.to_lower()
			if lower_arg in ["true", "1", "yes", "on"]: return true
			elif lower_arg in ["false", "0", "no", "off"]: return false
			else: return null # Indicate parsing failure for bool
		"variant": # Allow passing as string for later manual conversion
			return arg_string
		_: 
			self._console_log("Warning: Unsupported argument type hint '%s' for argument '%s'. Treating as string." % [type_hint, arg_string], _log_level_warning)
			return arg_string # Fallback to string if type unknown


## Evaluates a GDScript expression (Restored)
func _evaluate_expression(expression_string: String) -> void:
	# SECURITY WARNING: Evaluating arbitrary code is inherently risky!
	var expression = Expression.new() # Create local expression, removed unused member var
	var parse_error = expression.parse(expression_string) # Basic GDScript subset

	if parse_error != OK:
		self._console_log("Error parsing expression: %s" % expression.get_error_text(), _log_level_error)
		return

	# Execute the expression.
	var result = expression.execute([], self, true) # Execute in the context of the console node itself

	if expression.has_execute_failed():
		self._console_log("Error executing expression: Potential runtime error.", _log_level_error)
	elif result != null:
		self._console_log("Expression Result: %s" % str(result))
	else:
		self._console_log("Expression executed.", _log_level_debug)


func _on_console_input_gui_input(event: InputEvent) -> void:
	# Handle history navigation (Up/Down arrows)
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if command_history.is_empty(): return # No history

		var navigated = false
		if event.keycode == KEY_UP:
			if history_index == -1: history_index = command_history.size() - 1
			elif history_index > 0: history_index -= 1
			else: history_index = 0 # Stay at top
			navigated = true
		elif event.keycode == KEY_DOWN:
			if history_index != -1 and history_index < command_history.size() - 1:
				history_index += 1
			else: # Reset to bottom
				history_index = -1
				if is_instance_valid(console_input): console_input.clear()
				get_viewport().set_input_as_handled()
				return # Exit early after clearing
			navigated = true

		if navigated and history_index >= 0 and history_index < command_history.size():
			if is_instance_valid(console_input):
				console_input.text = command_history[history_index]
				console_input.caret_column = console_input.text.length()
			get_viewport().set_input_as_handled()

func _add_console_output(text: String) -> void:
	# Ensure we don't try to append if the node isn't valid (e.g., during shutdown)
	if is_instance_valid(console_output):
		console_output.append_text("\n" + text)

# --- Helper for log level colors (Restored) ---
func _get_log_level_color(level: int) -> String:
	# Use stored numeric levels directly
	match level:
		_log_level_debug: return "gray"
		_log_level_info: return "white"
		_log_level_warning: return "yellow"
		_log_level_error: return "red"
		_log_level_fatal: return "magenta"
		_: return "white" # Default color

# --- Scene Scanning & Activation (Restored/Combined) ---
func _scan_project_scenes() -> void:
	# Use Scene Manager if available
	if scene_manager and scene_manager.has_method("scan_scenes"):
		self._console_log("Using SceneManager extension for scene scanning...")
		scene_manager.scan_scenes()
		_scenes_scanned = true # Assume manager sets its own scanned state if needed
		return
		
	# Fallback original implementation if manager not available
	if not is_instance_valid(scene_list): 
		printerr("SceneList node invalid, cannot scan scenes.")
		return
		
	self._console_log("Scanning for scene files (fallback)...") 
	scene_list.clear()
	_all_scene_items.clear() 
	
	var dir = DirAccess.open("res://")
	if dir == null:
		printerr("DeveloperConsole: Failed to open root directory 'res://'. Error: %s" % error_string(DirAccess.get_open_error()))
		self._console_log("[ERROR] Failed to scan scenes: Cannot access 'res://'.")
		return

	var queue: Array = ["res://"]
	var found_scenes: PackedStringArray = []

	while not queue.is_empty():
		var current_path = queue.pop_front()
		if typeof(current_path) != TYPE_STRING: continue

		dir = DirAccess.open(current_path)
		if dir:
			dir.list_dir_begin()
			var file_name = dir.get_next()
			while file_name != "":
				if file_name == "." or file_name == "..":
					file_name = dir.get_next()
					continue

				file_name = file_name.replace(".remap", "")
				var full_path = current_path.path_join(file_name)

				if dir.current_is_dir():
					if file_name != ".git" and file_name != ".godot": queue.push_back(full_path)
				elif file_name.ends_with(".tscn"): found_scenes.push_back(full_path)

				file_name = dir.get_next()
		else:
			printerr("DeveloperConsole: Failed to open directory: %s" % current_path)

	found_scenes.sort()
	for scene_path in found_scenes:
		var display_path = scene_path.replace("res://", "")
		scene_list.add_item(display_path, null, true)
		scene_list.set_item_tooltip(scene_list.item_count - 1, scene_path)
		_all_scene_items.append({"path": scene_path, "display": display_path, "index": scene_list.item_count - 1})

	_scenes_scanned = true
	self._console_log("Scene scan complete. Found %d scenes." % scene_list.item_count)


func _on_scene_list_item_activated(index: int) -> void:
	if not is_instance_valid(scene_list) or index < 0 or index >= scene_list.item_count:
		return
	var scene_path = scene_list.get_item_tooltip(index) # Get full path from tooltip
	if scene_path.is_empty():
		_add_console_output("[color=red]Error: Could not get scene path for selected item.[/color]")
		return

	_add_console_output("Attempting to change scene to: %s" % scene_path)
	var result_str = _cmd_scene_change([scene_path]) # Reuse command logic
	_add_console_output(result_str)


func _on_tab_changed(tab_idx: int) -> void:
	self._console_log("Switched to tab index: %d" % tab_idx, _log_level_debug)
	
	# Check if Scene tab (assuming index 2) was selected and scan if needed
	if tab_idx == 2 and is_instance_valid(scene_list) and not _scenes_scanned:
		_scan_project_scenes()
		
	# Call specific manager's selected function if available
	match tab_idx:
		0: if quick_actions_manager and quick_actions_manager.has_method("_on_tab_selected"): quick_actions_manager.call_deferred("_on_tab_selected")
		1: if is_instance_valid(console_input): console_input.call_deferred("grab_focus") # Focus input on Console tab
		2: if scene_manager and scene_manager.has_method("_on_tab_selected"): scene_manager.call_deferred("_on_tab_selected")
		3: if log_manager and log_manager.has_method("_on_tab_selected"): log_manager.call_deferred("_on_tab_selected")
		4: if search_manager and search_manager.has_method("_on_tab_selected"): search_manager.call_deferred("_on_tab_selected")
		_: self._console_log("Warning: Switched to unhandled tab index %d" % tab_idx, _log_level_warning)

# --- Dragging & Resizing Logic (Restored) ---

func _on_header_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.is_pressed():
			_is_dragging = true
			_drag_start_offset = panel_container.get_global_mouse_position() - panel_container.global_position
			get_viewport().set_input_as_handled()
		else:
			_is_dragging = false
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _is_dragging:
		panel_container.global_position = panel_container.get_global_mouse_position() - _drag_start_offset
		get_viewport().set_input_as_handled()


func _on_panel_container_gui_input(event: InputEvent) -> void:
	var mouse_pos = panel_container.get_local_mouse_position()
	var panel_size = panel_container.size

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.is_pressed():
			_resize_edge_h = ""
			_resize_edge_v = ""
			if mouse_pos.x < RESIZE_MARGIN: _resize_edge_h = "left"
			elif mouse_pos.x > panel_size.x - RESIZE_MARGIN: _resize_edge_h = "right"
			if mouse_pos.y < RESIZE_MARGIN: _resize_edge_v = "top"
			elif mouse_pos.y > panel_size.y - RESIZE_MARGIN: _resize_edge_v = "bottom"

			if _resize_edge_h != "" or _resize_edge_v != "":
				_is_resizing = true
				_resize_start_mouse_pos = panel_container.get_global_mouse_position()
				_resize_start_pos = panel_container.global_position
				_resize_start_size = panel_container.size
				panel_container.queue_redraw()
			get_viewport().set_input_as_handled()
		else:
			if _is_resizing:
				_is_resizing = false
				_resize_edge_h = ""
				_resize_edge_v = ""
				panel_container.queue_redraw()
			panel_container.mouse_default_cursor_shape = Control.CURSOR_ARROW
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _is_resizing:
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
		panel_container.queue_redraw()
		get_viewport().set_input_as_handled()

func _update_resize_cursor() -> void:
	var mouse_pos: Vector2 = panel_container.get_local_mouse_position()
	var panel_size: Vector2 = panel_container.size
	var old_h = _hover_edge_h
	var old_v = _hover_edge_v
	_hover_edge_h = ""
	_hover_edge_v = ""

	if mouse_pos.x < RESIZE_MARGIN: _hover_edge_h = "left"
	elif mouse_pos.x > panel_size.x - RESIZE_MARGIN: _hover_edge_h = "right"
	if mouse_pos.y < RESIZE_MARGIN: _hover_edge_v = "top"
	elif mouse_pos.y > panel_size.y - RESIZE_MARGIN: _hover_edge_v = "bottom"

	var cursor_shape = Control.CURSOR_ARROW
	if _hover_edge_h == "left" and _hover_edge_v == "top": cursor_shape = Control.CURSOR_BDIAGSIZE
	elif _hover_edge_h == "right" and _hover_edge_v == "bottom": cursor_shape = Control.CURSOR_BDIAGSIZE
	elif _hover_edge_h == "right" and _hover_edge_v == "top": cursor_shape = Control.CURSOR_FDIAGSIZE
	elif _hover_edge_h == "left" and _hover_edge_v == "bottom": cursor_shape = Control.CURSOR_FDIAGSIZE
	elif _hover_edge_h != "": cursor_shape = Control.CURSOR_HSIZE
	elif _hover_edge_v != "": cursor_shape = Control.CURSOR_VSIZE

	panel_container.mouse_default_cursor_shape = cursor_shape
	if old_h != _hover_edge_h or old_v != _hover_edge_v: panel_container.queue_redraw()

func _draw_resize_handles() -> void:
	if not panel_container.visible: return
	var panel_size = panel_container.size
	var draw_color = RESIZE_BORDER_COLOR
	var line_width = 2.0
	if _is_resizing or _hover_edge_h != "" or _hover_edge_v != "":
		if _is_resizing: draw_color = Color(0.8, 0.8, 0.8, 0.7)
		if _resize_edge_h == "left" or _hover_edge_h == "left": panel_container.draw_line(Vector2(0, 0), Vector2(0, panel_size.y), draw_color, line_width)
		if _resize_edge_h == "right" or _hover_edge_h == "right": panel_container.draw_line(Vector2(panel_size.x, 0), Vector2(panel_size.x, panel_size.y), draw_color, line_width)
		if _resize_edge_v == "top" or _hover_edge_v == "top": panel_container.draw_line(Vector2(0, 0), Vector2(panel_size.x, 0), draw_color, line_width)
		if _resize_edge_v == "bottom" or _hover_edge_v == "bottom": panel_container.draw_line(Vector2(0, panel_size.y), Vector2(panel_size.x, panel_size.y), draw_color, line_width)
		var handle_size = 6.0
		if (_resize_edge_h == "left" and _resize_edge_v == "top") or (_hover_edge_h == "left" and _hover_edge_v == "top"): panel_container.draw_rect(Rect2(0, 0, handle_size, handle_size), draw_color)
		if (_resize_edge_h == "right" and _resize_edge_v == "top") or (_hover_edge_h == "right" and _hover_edge_v == "top"): panel_container.draw_rect(Rect2(panel_size.x - handle_size, 0, handle_size, handle_size), draw_color)
		if (_resize_edge_h == "left" and _resize_edge_v == "bottom") or (_hover_edge_h == "left" and _hover_edge_v == "bottom"): panel_container.draw_rect(Rect2(0, panel_size.y - handle_size, handle_size, handle_size), draw_color)
		if (_resize_edge_h == "right" and _resize_edge_v == "bottom") or (_hover_edge_h == "right" and _hover_edge_v == "bottom"): panel_container.draw_rect(Rect2(panel_size.x - handle_size, panel_size.y - handle_size, handle_size, handle_size), draw_color)

func _on_panel_container_mouse_exited() -> void:
	if not _is_resizing:
		_hover_edge_h = ""
		_hover_edge_v = ""
		panel_container.mouse_default_cursor_shape = Control.CURSOR_ARROW
		panel_container.queue_redraw()

# endregion

# --- Extension Initialization (Restored/Refined) ---
func _initialize_extensions() -> void:
	# Called from the primary _ready but logic moved there
	self._console_log("Initializing Console Extensions...")
	pass 

# Scene search functionality (Restored) 
func _on_scene_search_text_changed(search_text: String) -> void:
	_filter_scenes(search_text)

func _on_scene_search_text_submitted(search_text: String) -> void:
	_filter_scenes(search_text)

func _filter_scenes(search_text: String) -> void:
	if not is_instance_valid(scene_list): return
	scene_list.clear()
	if search_text.strip_edges() == "":
		for item in _all_scene_items: 
			scene_list.add_item(item["display"], null, true)
			scene_list.set_item_tooltip(scene_list.item_count - 1, item["path"])
		return
	search_text = search_text.to_lower()
	var found = false
	for item in _all_scene_items:
		if item["display"].to_lower().contains(search_text) or item["path"].to_lower().contains(search_text):
			scene_list.add_item(item["display"], null, true)
			scene_list.set_item_tooltip(scene_list.item_count - 1, item["path"])
			found = true
	if not found: scene_list.add_item("No matching scenes found", null, false)


# --- Getter functions for Managers (Added) ---
# Removed type hints temporarily
func get_quick_actions_manager(): # -> DeveloperConsoleQuickActionsManager:
	return quick_actions_manager

func get_scene_manager(): # -> DeveloperConsoleSceneManager:
	return scene_manager

func get_log_manager(): # -> DeveloperConsoleLogManager:
	return log_manager

func get_search_manager(): # -> DeveloperConsoleSearchManager:
	return search_manager
