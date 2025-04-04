extends Node3D

@onready var area: Area3D = $Area3D
var collected: bool = false

func _ready():
	area.body_entered.connect(_on_area_body_entered)

func _on_area_body_entered(body: Node):
	if collected:
		return
	if body.name == "Player":
		collected = true
		# 通知QuestManager进度+1
		QuestManager.add_item()
		queue_free()  # 物品消失
