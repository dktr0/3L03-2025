# .----------------------------------------------------------------------------.
# |:::    :::     :::     :::        ::::::::  :::   :::  ::::::::  ::::    :::|
# |:+:    :+:   :+: :+:   :+:       :+:    :+: :+:   :+: :+:    :+: :+:+:   :+:|
# |+:+    +:+  +:+   +:+  +:+       +:+         +:+ +:+  +:+    +:+ :+:+:+  +:+|
# |+#++:++#++ +#++:++#++: +#+       +#+          +#++:   +#+    +:+ +#+ +:+ +#+|
# |+#+    +#+ +#+     +#+ +#+       +#+           +#+    +#+    +#+ +#+  +#+#+#|
# |#+#    #+# #+#     #+# #+#       #+#    #+#    #+#    #+#    #+# #+#   #+#+#|
# |###    ### ###     ### ########## ########     ###     ########  ###    ####|
# '----------------------------------------------------------------------------'
# Developer Console Logs Scene
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
	
	log_output = console.get_node_or_null("PanelContainer/VBoxContainer/TabContainer/Log/VBoxContainer/Output")
	if log_output == null:
		printerr("DeveloperConsoleLogManager: Could not find Log output")
		return
	
	search_bar = console.get_node_or_null("PanelContainer/VBoxContainer/TabContainer/Log/VBoxContainer/SearchBar")
	if search_bar == null:
		printerr("DeveloperConsoleLogManager: Could not find search bar")
		return
		
	# Connect search bar signals, disconnecting first to prevent duplicates on re-init
	if search_bar.text_changed.is_connected(_on_search_text_changed):
		search_bar.text_changed.disconnect(_on_search_text_changed)
	search_bar.text_changed.connect(_on_search_text_changed)
	
	if search_bar.text_submitted.is_connected(_on_search_submitted):
		search_bar.text_submitted.disconnect(_on_search_submitted)
	search_bar.text_submitted.connect(_on_search_submitted)
	
	add_log("Log Manager initialized. Search functionality ready.")

## Logs a message to the Log tab. Adds a timestamp.
## Can be called via console.log_manager.add_log("message")
func add_log(message: String) -> void:
	if not is_instance_valid(log_output): return # Avoid errors if called before ready or node deleted
	
	# Get timestamp with milliseconds for precise logging
	var timestamp = Time.get_datetime_string_from_system(false, true) # UTC=false, use_msec=true
	
	var log_entry = "\n[%s] %s" % [timestamp, message]
	
	# Add to the internal full log string for searching purposes
	full_log_content += log_entry
	
	# Append to the visible RichTextLabel, allowing BBCode
	log_output.append_text(log_entry)

## Clears the log output
func clear_log() -> void:
	if is_instance_valid(log_output):
		log_output.clear()
		# Also clear the internal log string
		full_log_content = ""
		add_log("Log cleared")

## Handles log commands from the console
func handle_log_command(args: Array) -> String:
	if args.is_empty():
		return "[color=yellow]Usage: log <message>[/color]"
	var message_to_log = " ".join(args) # Reconstruct the message from arguments
	add_log("From console command: %s" % message_to_log)
	return "Logged to Log tab: '%s'" % message_to_log

## Handle search text changes (live search)
func _on_search_text_changed(new_text: String) -> void:
	search_logs(new_text)

## Handle search submission (Enter key)
func _on_search_submitted(search_text: String) -> void:
	search_logs(search_text)
	
## Performs the search and updates the log display with highlighted results
func search_logs(search_text: String) -> void:
	if not is_instance_valid(log_output): return
	
	# If search is empty, restore the full log view
	if search_text.strip_edges() == "":
		log_output.clear()
		log_output.append_text(full_log_content)
		return
	
	# Perform case-insensitive search on the full log content
	var lines = full_log_content.split("\n", false) # Split into individual log entries
	var matching_lines = []
	var search_lower = search_text.to_lower()
	
	for line in lines:
		if line.to_lower().contains(search_lower):
			matching_lines.append(line)
	
	# Update the display with search results
	log_output.clear()
	
	if not matching_lines.is_empty():
		log_output.append_text("\n[color=cyan]Found " + str(matching_lines.size()) + " matching log entries for: '" + search_text + "'[/color]")
		
		for line in matching_lines:
			# Highlight the search term within each matching line using BBCode
			var position = line.to_lower().find(search_lower)
			if position != -1:
				var before = line.substr(0, position)
				var matched = line.substr(position, search_text.length())
				var after = line.substr(position + search_text.length())
				log_output.append_text("\n" + before + "[color=yellow][b]" + matched + "[/b][/color]" + after)
			else:
				# Fallback if exact position isn't found (shouldn't happen with .contains)
				log_output.append_text("\n" + line)
	else:
		log_output.append_text("\n[color=gray]No results found for: '" + search_text + "'[/color]") 