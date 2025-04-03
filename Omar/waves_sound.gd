extends Area3D

@export var wave_audio: AudioStreamPlayer3D
@export var player: CharacterBody3D
@export var custom_max_distance: float = 500
@export var min_volume: float = -40
@export var max_volume: float = 4

var player_inside = false

func _process(_delta):
	if player == null: 
		return
	var distance = global_position.distance_to(player.global_position)
	
	if player_inside:
		var volume_db = lerp(max_volume, min_volume, distance / custom_max_distance)
		volume_db = clamp(volume_db, min_volume, max_volume) 
		if player_inside:
			wave_audio.volume_db = volume_db
		if not wave_audio.playing:
			wave_audio.play()
	else:
		if wave_audio.playing:
			wave_audio.stop()

func _ready():
	wave_audio = $Waves
	player = $"../Player"

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_inside = true

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_inside = false
