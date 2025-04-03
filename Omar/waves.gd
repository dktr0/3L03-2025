extends AudioStreamPlayer3D

@export var player: CharacterBody3D
@export var custom_max_distance: float = 50
@export var min_volume: float = -40
@export var max_volume: float = 0
@export var sound: AudioStream

var distance: float = 0

func _ready() -> void:
	if sound == null:
		print ("sound not assigned")
		return
	stream = sound
	play()
	print("Sound started successfully")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if player == null:
		return
	distance = global_position.distance_to(player.global_position)
	
	var volume_db = lerp(max_volume, min_volume, distance / custom_max_distance)
	
	volume_db = clamp(volume_db, min_volume, max_volume)
	
	self.volume_db = volume_db
