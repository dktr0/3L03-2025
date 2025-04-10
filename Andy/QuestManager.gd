extends Node

signal quest_started(quest_id: String)
signal quest_completed(quest_id: String)
signal progress_updated(quest_id: String, current: int, goal: int)

var quests_data: Dictionary = {}

func _ready():
	print("[QuestManager] Ready...")

# ------------------- 启动任务 -------------------
func start_quest(quest_id: String, goal: int, description: String = ""):
	if not quests_data.has(quest_id):
		quests_data[quest_id] = {
			"description": description,
			"current": 0,
			"goal": goal,
			"completed": false
		}
		emit_signal("quest_started", quest_id)
		print("[QuestManager] 任务开始: %s (目标=%d, 描述=%s)"
			  % [quest_id, goal, description])

# ------------------- 进度 +1 -------------------
func add_progress(quest_id: String, amount: int = 1):
	if quests_data.has(quest_id):
		var info = quests_data[quest_id]
		if info["completed"]:
			return

		info["current"] += amount
		emit_signal("progress_updated", quest_id, info["current"], info["goal"])
		print("[QuestManager] 进度: %s -> %d / %d"
			  % [quest_id, info["current"], info["goal"]])

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

# ------------------- 追踪可收集物品 -------------------
func track_collectibles_for_quest(quest_id: String, goal: int, description: String = "收集物品"):
	# 1) 启动收集类任务
	start_quest(quest_id, goal, description)
	# 2) 在场景树中找所有 “collectibles” 分组的节点
	var collectibles = get_tree().get_nodes_in_group("collectibles")
	for c in collectibles:
		if c.has_signal("body_entered"):
			c.body_entered.connect(Callable(self, "_on_collectible_body_entered").bind(c, quest_id))
		else:
			push_warning("Node %s in group 'collectibles' is not an Area3D or lacks 'body_entered' signal" % c.name)

func _on_collectible_body_entered(body: Node, collectible: Node, quest_id: String):
	if body.name == "Player":
		add_progress(quest_id, 1)
		collectible.queue_free()

# ------------------- 新增：重置任务 -------------------
func reset_quest(quest_id: String):
	if quests_data.has(quest_id):
		var info = quests_data[quest_id]
		info["current"] = 0
		info["completed"] = false
		print("[QuestManager] 任务重置: %s" % quest_id)

func reset_all_quests():
	quests_data.clear()
	print("[QuestManager] 所有任务已彻底删除")
