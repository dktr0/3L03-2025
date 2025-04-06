extends AudioStreamPlayer3D

@export var player: CharacterBody3D
@export var custom_max_distance: float = 500
@export var min_volume: float = 10
@export var max_volume: float = 20

func _ready():
	play()  # Always playing

func _process(_delta):
	if player == null:
		return
	
	var distance = global_position.distance_to(player.global_position)
	var volume_db = lerp(max_volume, min_volume, distance / custom_max_distance)
	volume_db = clamp(volume_db, min_volume, max_volume)

	volume_db = clamp(volume_db, min_volume, max_volume)
	self.volume_db = volume_db
