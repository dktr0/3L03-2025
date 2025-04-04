extends Area3D

@export var forest_audio: AudioStreamPlayer3D
@export var forest_audio2: AudioStreamPlayer3D
@export var forest_audio3: AudioStreamPlayer3D
@export var forest_audio4: AudioStreamPlayer3D
@export var player: CharacterBody3D
@export var custom_max_distance: float = 500
@export var min_volume: float = 10
@export var max_volume: float = 70

var player_inside = false

func _process(_delta):
	if player == null: 
		return
	var distance = global_position.distance_to(player.global_position)
	
	if player_inside:
		var volume_db = lerp(max_volume, min_volume, distance / custom_max_distance)
		volume_db = clamp(volume_db, min_volume, max_volume) 
		if player_inside:
			forest_audio.volume_db = volume_db
		if not forest_audio.playing:
			forest_audio.play()
	else:
		if forest_audio.playing:
			forest_audio.stop()

func _ready():
	forest_audio = $Wind
	forest_audio2 = $Wind2
	forest_audio3 = $Wind3
	forest_audio4 = $Wind4
	player = $"../Player"

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_inside = true

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_inside = false
