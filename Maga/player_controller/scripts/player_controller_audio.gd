# .----------------------------------------------------------------------------.
# |:::    :::     :::     :::        ::::::::  :::   :::  ::::::::  ::::    :::|
# |:+:    :+:   :+: :+:   :+:       :+:    :+: :+:   :+: :+:    :+: :+:+:   :+:|
# |+:+    +:+  +:+   +:+  +:+       +:+         +:+ +:+  +:+    +:+ :+:+:+  +:+|
# |+#++:++#++ +#++:++#++: +#+       +#+          +#++:   +#+    +:+ +#+ +:+ +#+|
# |+#+    +#+ +#+     +#+ +#+       +#+           +#+    +#+    +#+ +#+  +#+#+#|
# |#+#    #+# #+#     #+# #+#       #+#    #+#    #+#    #+#    #+# #+#   #+#+#|
# |###    ### ###     ### ########## ########     ###     ########  ###    ####|
# '----------------------------------------------------------------------------'
# Player Controller Audio
#
# Developed by:
# - Liam Maga
# - 
# - 
# .----------------------------------------------------------------------------.

extends Node

# Assuming this script is a child of the main PlayerController node
# (CharacterBody3D/2D) which has velocity and is_on_floor properties/methods.
# Ensure this node has two children:
# 1. An AudioStreamPlayer node named "FootstepPlayer"
# 2. A Timer node named "StepTimer"

@export var step_interval: float = 0.4 # Time between steps when moving

# NOTE: You need to add an AudioStreamPlayer child node named "FootstepPlayer" in the scene tree.
@onready var footstep_player: AudioStreamPlayer = $FootstepPlayer
# NOTE: You need to add a Timer child node named "StepTimer" in the scene tree.
@onready var step_timer: Timer = $StepTimer

var grass_footstep_sounds: Array[AudioStream] = []
const GRASS_SOUND_PATHS = [
	"res://Tram/sound effects/grass-step-1.mp3",
	"res://Tram/sound effects/grass-step-2.mp3",
	"res://Tram/sound effects/grass-step-3.mp3",
	"res://Tram/sound effects/grass-step-4.mp3",
	"res://Tram/sound effects/grass-step-5.mp3"
]

# This assumes the parent node is a CharacterBody3D or CharacterBody2D.
# Adjust if your player controller node type is different.
@onready var player_node = get_parent() if get_parent() is CharacterBody3D or get_parent() is CharacterBody2D else null


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if not player_node:
		push_warning("PlayerControllerAudio requires its parent to be a CharacterBody3D or CharacterBody2D. Footsteps disabled.")
		set_process(false)
		return
	
	if not footstep_player:
		push_error("FootstepPlayer node not found. Add an AudioStreamPlayer named FootstepPlayer as a child.")
		set_process(false)
		return

	if not step_timer:
		push_error("StepTimer node not found. Add a Timer named StepTimer as a child.")
		set_process(false)
		return

	# Load sounds
	for path in GRASS_SOUND_PATHS:
		var stream = load(path) as AudioStream
		if stream:
			grass_footstep_sounds.append(stream)
		else:
			push_warning("Failed to load footstep sound: " + path)

	if grass_footstep_sounds.is_empty():
		push_warning("No grass footstep sounds loaded. Footsteps will be silent.")
		# Keep processing in case other sounds are added later, but log the warning.

	# Configure timer
	step_timer.wait_time = step_interval
	step_timer.one_shot = true # Timer should stop after triggering once


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if not player_node or grass_footstep_sounds.is_empty():
		return # Nothing to do if no player reference or no sounds loaded

	# Check movement conditions (using is_on_floor() and velocity magnitude)
	# Adjust the velocity threshold (0.1 * 0.1 = 0.01) if needed.
	var is_moving_on_floor = player_node.is_on_floor() and player_node.velocity.length_squared() > 0.01

	if is_moving_on_floor and step_timer.is_stopped():
		play_footstep_sound()
		step_timer.start()

func play_footstep_sound() -> void:
	if grass_footstep_sounds.is_empty() or not footstep_player:
		return

	# Prevent sound overlap by checking if already playing
	if not footstep_player.playing:
		var random_index = randi() % grass_footstep_sounds.size()
		footstep_player.stream = grass_footstep_sounds[random_index]
		footstep_player.play()
