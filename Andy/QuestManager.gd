extends Node

signal quest_completed
signal progress_updated(current: int, goal: int)

@export var collect_goal: int = 7    # 需要收集的总数
var collect_count: int = 0          # 当前收集了多少

func _ready():
	pass

func add_item():
	collect_count += 1
	emit_signal("progress_updated", collect_count, collect_goal)
	
	if collect_count >= collect_goal:
		emit_signal("quest_completed")

func get_progress() -> int:
	return collect_count

func get_goal() -> int:
	return collect_goal
