extends Node3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var lighthouse = $Present_light_house # 确保路径正确
	if lighthouse:
		lighthouse.visible = false
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
