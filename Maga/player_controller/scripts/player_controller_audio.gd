# .----------------------------------------------------------------------------.
# |:::    :::     :::     :::        ::::::::  :::   :::  ::::::::  ::::    :::|
# |:+:    :+:   :+: :+:   :+:       :+:    :+: :+:   :+: :+:    :+: :+:+:   :+:|
# |+:+    +:+  +:+   +:+  +:+       +:+         +:+ +:+  +:+    +:+ :+:+:+  +:+|
# |+#++:++#++ +#++:++#++: +#+       +#+          +#++:   +#+    +:+ +#+ +:+ +#+|
# |+#+    +#+ +#+     +#+ +#+       +#+           +#+    +#+    +#+ +#+  +#+#+#|
# |#+#    #+# #+#     #+# #+#       #+#    #+#    #+#    #+#    #+# +#+   #+#+#|
# |###    ### ###     ### ########## ########     ###     ########  ###    ####|
# '----------------------------------------------------------------------------'
# Player Controller Audio
#
# Handles playing footstep sounds based on player movement.
# Assumes this node is a child of the main CharacterBody3D node.
# Requires two child nodes:
#   - AudioStreamPlayer named "FootstepPlayer"
#   - Timer named "StepTimer"
#
# Developed by:
# - Liam Maga
# - 
# - 
# .----------------------------------------------------------------------------.

extends Node

@export var step_interval: float = 0.4 # Time between steps when WALKING (increased slightly)
@export var sprint_step_interval: float = 0.3 # Time between steps when SPRINTING (kept the original faster rate)
@export var velocity_threshold: float = 0.1 # Minimum velocity magnitude squared to be considered moving

@onready var footstep_player: AudioStreamPlayer = $FootstepPlayer
@onready var step_timer: Timer = $StepTimer

# Reference to the parent CharacterBody3D
@onready var player_node: CharacterBody3D = get_parent() if get_parent() is CharacterBody3D else null

var footstep_sounds: Array[AudioStream] = []
# TODO: Consider making this path configurable via @export or using a resource
const FOOTSTEP_SOUND_DIR = "res://Spencer/General/FootstepDull/" # Example path, adjust if needed

# Track movement state
var was_moving_on_floor := false

func _ready() -> void:
	print("Audio Script: _ready() called.")
	if not _validate_nodes():
		print("Audio Script: Node validation FAILED.")
		set_process(false)
		return
	print("Audio Script: Node validation PASSED.")

	_load_footstep_sounds(FOOTSTEP_SOUND_DIR)

	if footstep_sounds.is_empty():
		push_warning("No footstep sounds loaded. Footsteps will be silent.")
		print("Audio Script: No footstep sounds loaded. Check path: %s" % FOOTSTEP_SOUND_DIR)
	else:
		print("Audio Script: %d footstep sounds loaded from %s." % [footstep_sounds.size(), FOOTSTEP_SOUND_DIR])

	# Configure the timer
	# step_timer.wait_time = step_interval # Initial setting removed, now set dynamically
	step_timer.one_shot = true
	if not footstep_sounds.is_empty() and step_timer:
		if not step_timer.is_connected("timeout", _on_step_timer_timeout):
			step_timer.timeout.connect(_on_step_timer_timeout)
			print("Audio Script: Timer timeout connected.")
		else:
			print("Audio Script: Timer timeout ALREADY connected.")
	elif step_timer:
		print("Audio Script: No sounds loaded, stopping timer.")
		step_timer.stop()
	else:
		print("Audio Script: Timer node invalid, cannot connect signal.")

	# Debug audio player settings
	print("Audio Script: FootstepPlayer volume_db=%f, autoplay=%s" % [footstep_player.volume_db, footstep_player.autoplay])

func _validate_nodes() -> bool:
	# Check 1: Parent
	if not player_node:
		push_error("PlayerControllerAudio requires its parent to be a CharacterBody3D. Footsteps disabled.")
		return false

	# Check 2: FootstepPlayer
	if not footstep_player:
		push_error("FootstepPlayer node not found or is wrong type. Add an AudioStreamPlayer named 'FootstepPlayer' as a child.")
		return false

	# Check 3: StepTimer
	if not step_timer:
		push_error("StepTimer node not found or is wrong type. Add a Timer named 'StepTimer' as a child.")
		return false

	return true

func _load_footstep_sounds(directory_path: String) -> void:
	footstep_sounds.clear()
	var dir = DirAccess.open(directory_path)
	if not dir:
		push_error("Failed to open footstep sound directory: " + directory_path)
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			# Check for common audio extensions
			var ext = file_name.get_extension().to_lower()
			if ext == "mp3" or ext == "wav" or ext == "ogg":
				var file_path = directory_path.path_join(file_name)
				var stream = load(file_path) as AudioStream
				if stream:
					# Ensure the stream doesn't loop internally
					if stream is AudioStreamMP3: stream.loop = false
					elif stream is AudioStreamOggVorbis: stream.loop = false
					# Add other types if needed (e.g., AudioStreamWav)
					footstep_sounds.append(stream)
				else:
					push_warning("Failed to load footstep sound: " + file_path)
		file_name = dir.get_next()
	dir.list_dir_end()


func _process(_delta: float) -> void:
	if not is_instance_valid(player_node) or not is_instance_valid(footstep_player) or not is_instance_valid(step_timer):
		push_warning("PlayerControllerAudio: Critical node instance became invalid during process. Disabling.")
		set_process(false)
		return
		
	var is_on_floor = player_node.is_on_floor()
	var velocity_sq = player_node.velocity.length_squared()
	var is_moving_on_floor = is_on_floor and velocity_sq > velocity_threshold
	# print("Audio Script Process: is_on_floor=%s, vel_sq=%.2f, moving_on_floor=%s, was_moving=%s" % [is_on_floor, velocity_sq, is_moving_on_floor, was_moving_on_floor]) # DEBUG

	# Check state transitions
	if is_moving_on_floor and not was_moving_on_floor:
		# Just started moving on floor: play first step and start timer
		print("Audio Script Process: Started moving, playing first step.") # DEBUG
		_play_footstep_sound()
	elif not is_moving_on_floor and was_moving_on_floor:
		# Just stopped moving on floor: stop the timer
		if not step_timer.is_stopped():
			print("Audio Script Process: Stopped moving, stopping timer.") # DEBUG
			step_timer.stop()
	
	# Update state for next frame
	was_moving_on_floor = is_moving_on_floor

func _play_footstep_sound() -> void:
	print("Audio Script: _play_footstep_sound() called.") # DEBUG
	if footstep_sounds.is_empty() or not is_instance_valid(footstep_player):
		print("Audio Script: Aborting play (no sounds or invalid player).") # DEBUG
		return # Cannot play sound

	# Stop previous sound to prevent overlaps if it's still playing somehow
	if footstep_player.playing:
		print("Audio Script: Stopping previous sound.") # DEBUG
		footstep_player.stop()

	# Select and play a random footstep sound
	var sound_to_play = footstep_sounds.pick_random()
	footstep_player.stream = sound_to_play
	print("Audio Script: Playing sound: %s" % [sound_to_play.resource_path if sound_to_play else "null"]) # DEBUG
	footstep_player.play()

	# Start the timer for the *next* step. We always start it here now,
	# the timeout handler will decide if another step should play.
	# Set the wait time dynamically based on current sprint state
	var is_sprinting = player_node.is_currently_sprinting()
	if is_sprinting:
		step_timer.wait_time = sprint_step_interval
	else:
		step_timer.wait_time = step_interval
	step_timer.start()

# Called when the StepTimer finishes its wait time
func _on_step_timer_timeout() -> void:
	# When the timer times out, play another step IF the player is still moving.
	if is_instance_valid(player_node) and \
	   player_node.is_on_floor() and \
	   player_node.velocity.length_squared() > velocity_threshold:
		
		_play_footstep_sound()
