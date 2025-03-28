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

class_name DeveloperConsoleLogManager

# Reference to the main developer console
var console: Node
# Reference to the Log output RichTextLabel
var log_output: RichTextLabel
# Reference to the search bar
var search_bar: LineEdit
# Store the full log content for searching
var full_log_content: String = ""

## Initialize the log manager with references to the main console
func initialize(developer_console: Node) -> void:
	console = developer_console
	
	# Get reference to log output
	log_output = console.get_node_or_null("PanelContainer/VBoxContainer/TabContainer/Log/VBoxContainer/Output")
	if log_output == null:
		printerr("DeveloperConsoleLogManager: Could not find Log output")
		return
	
	# Get reference to search bar
	search_bar = console.get_node_or_null("PanelContainer/VBoxContainer/TabContainer/Log/VBoxContainer/SearchBar")
	if search_bar == null:
		printerr("DeveloperConsoleLogManager: Could not find search bar")
		return
		
	# Connect search bar signals
	search_bar.text_changed.connect(_on_search_text_changed)
	search_bar.text_submitted.connect(_on_search_submitted)
		
	console.log("Log Manager initialized") # Call the parent console's log function to show initialization

## Logs a message to the Log tab. Adds a timestamp.
## Can be called via console.log_manager.add_log("message")
func add_log(message: String) -> void:
	if not is_instance_valid(log_output): return # Avoid errors if called before ready or node deleted
	var timestamp = Time.get_datetime_string_from_system(false, true) # UTC=false, use_msec=true
	
	# Format log entry with timestamp
	var log_entry = "\n[%s] %s" % [timestamp, message]
	
	# Add to full log content
	full_log_content += log_entry
	
	# Append with BBCode for potential formatting
	log_output.append_text(log_entry)

## Clears the log output
func clear_log() -> void:
	if is_instance_valid(log_output):
		log_output.clear()
		# Also clear the full log content
		full_log_content = ""
		add_log("Log cleared")

## Handles log commands from the console
func handle_log_command(args: Array) -> String:
	if args.is_empty():
		return "[color=yellow]Usage: log <message>[/color]"
	var message_to_log = " ".join(args) # Join args back into a string
	add_log("From console command: %s" % message_to_log)
	return "Logged to Log tab: '%s'" % message_to_log

## Handle search text changes
func _on_search_text_changed(new_text: String) -> void:
	search_logs(new_text)

## Handle search submission (Enter key)
func _on_search_submitted(search_text: String) -> void:
	search_logs(search_text)
	
## Perform the actual search
func search_logs(search_text: String) -> void:
	if not is_instance_valid(log_output): return
	
	# If search is empty, show all logs
	if search_text.strip_edges() == "":
		log_output.clear()
		log_output.append_text(full_log_content)
		return
	
	# Perform case-insensitive search
	var lines = full_log_content.split("\n", false)
	var matching_lines = []
	
	for line in lines:
		if line.to_lower().contains(search_text.to_lower()):
			matching_lines.append(line)
	
	# Display matching lines
	log_output.clear()
	
	if matching_lines.size() > 0:
		for line in matching_lines:
			# Highlight the search term with color
			var highlighted_line = line.replace(search_text, "[color=yellow]" + search_text + "[/color]")
			log_output.append_text("\n" + highlighted_line)
	else:
		log_output.append_text("\n[color=gray]No results found for: " + search_text + "[/color]")
