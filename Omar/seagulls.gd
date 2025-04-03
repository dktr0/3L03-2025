extends Area3D

@export var seagulls_audio: AudioStreamPlayer3D
@export var player: CharacterBody3D
@export var custom_max_distance: float = 500
@export var min_volume: float = 10
@export var max_volume: float = 200

var player_inside = false

func _process(delta):
	if player == null: 
		return
	var distance = global_position.distance_to(player.global_position)
	
	if player_inside:
		var volume_db = lerp(max_volume, min_volume, distance / custom_max_distance)
		volume_db = clamp(volume_db, min_volume, max_volume) 
		if player_inside:
			seagulls_audio.volume_db = volume_db
		if not seagulls_audio.playing:
			seagulls_audio.play()
	else:
		if seagulls_audio.playing:
			seagulls_audio.stop()

func _ready():
	seagulls_audio = $Seagulls
	player = $"../Player2"

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_inside = true


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_inside = false
