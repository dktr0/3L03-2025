extends Control

@onready var label: Label = $Label

func _ready():
	QuestManager.connect("progress_updated", Callable(self, "_on_progress_updated"))
	QuestManager.connect("quest_completed", Callable(self, "_on_quest_completed"))

	_update_label(QuestManager.get_progress(), QuestManager.get_goal())

func _on_progress_updated(current: int, goal: int):
	_update_label(current, goal)

func _on_quest_completed():
	_update_label(QuestManager.get_goal(), QuestManager.get_goal())

func _update_label(current: int, goal: int):
	label.text = "Collected %d / %d" % [current, goal]
