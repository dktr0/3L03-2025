extends Node3D
@onready var animation_player = $penguinanimation

# Animation 
func _ready():
	animation_player.play("Idle")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
