extends Area3D

@export var player: CharacterBody3D
@export var custom_max_distance: float = 500
@export var min_volume: float = -40
@export var max_volume: float = 4

var wave_audios: Dictionary = {}
var player_inside = false

func _ready():
	player = $"../Player"
	for child in get_children():
		if child is AudioStreamPlayer3D:
			wave_audios ["Waves", "Waves8", "Waves9", "Waves3", "Waves4", "Waves5", "Waves6", "w"]
		print("Found wave sounds:", wave_audios.size())

func _process(_delta):
	if player == null or wave_audios.is_empty(): 
		return
	var distance = global_position.distance_to(player.global_position)
	var volume_db = lerp(max_volume, min_volume, distance / custom_max_distance)
	volume_db = clamp(volume_db, min_volume, max_volume) 

	if player_inside:
		for wave_audio in wave_audios:
			wave_audio.volume_db = volume_db
		if not wave_audio.playing:
			wave_audio.play()
	else:
		for wave_audio in wave_audios:
			if wave_audio.playing:
				wave_audio.stop()


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_inside = true
		print("Player entered wave area")

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_inside = false
		print("Player exited wave area")
