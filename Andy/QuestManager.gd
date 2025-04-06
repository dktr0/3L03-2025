extends Node

signal quest_started(quest_id: String)
signal quest_completed(quest_id: String)
signal progress_updated(quest_id: String, current: int, goal: int)

var quests_data: Dictionary = {}

func _ready():
	print("[QuestManager] Ready...")

func start_quest(quest_id: String, goal: int, description: String = ""):
	if not quests_data.has(quest_id):
		quests_data[quest_id] = {
			"description": description,
			"current": 0,
			"goal": goal,
			"completed": false
		}
		emit_signal("quest_started", quest_id)
		print("[QuestManager] 任务开始: %s (目标=%d, 描述=%s)" %
			[quest_id, goal, description])

func add_progress(quest_id: String, amount: int = 1):
	if quests_data.has(quest_id):
		var info = quests_data[quest_id]
		if info["completed"]:
			return
		info["current"] += amount
		emit_signal("progress_updated", quest_id, info["current"], info["goal"])
		print("[QuestManager] 进度: %s -> %d / %d" %
			[quest_id, info["current"], info["goal"]])

		if info["current"] >= info["goal"]:
			_complete_quest(quest_id)

func complete_quest(quest_id: String):
	if quests_data.has(quest_id):
		var info = quests_data[quest_id]
		if not info["completed"]:
			_complete_quest(quest_id)

func _complete_quest(quest_id: String):
	quests_data[quest_id]["completed"] = true
	emit_signal("quest_completed", quest_id)
	print("[QuestManager] 任务完成: %s" % quest_id)
