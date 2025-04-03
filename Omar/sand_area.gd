extends Area3D

@export var sand_audio: AudioStreamPlayer3D
@export var player: CharacterBody3D
@export var fade_speed: float = 2.0

var player_inside = false
var target_volume = -10.0
var fade_out_volume = -40

func _process(delta):
	if player_inside and player.velocity.length() > 0.1:
		if not sand_audio.playing:
			sand_audio.volume_db = target_volume
			sand_audio.play()
		target_volume = -10
	else:
		target_volume = fade_out_volume
	
		sand_audio.volume_db = lerp(float(sand_audio.volume_db), float(target_volume), float(fade_speed * delta))

	if sand_audio.volume_db <= fade_out_volume + 1 and sand_audio.playing:
		sand_audio.stop() 

func _ready():
	sand_audio = $AudioStreamPlayer3D
	player = $"../Player"

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("Player"):
		player_inside = true


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("Player"):
		player_inside = false
		target_volume = fade_out_volume
