extends Area3D

enum TriggerType {
	DIALOGUE,
	QUEST,
	BOTH
}

@export var trigger_type: TriggerType = TriggerType.DIALOGUE

# 把三行对话换成可变数组
@export var dialogue_lines: Array[String] = [
	"你好，冒险者！",
	"这是第二行对话，带有标点符号。",
]

# 任务相关
@export var quest_id: String = ""
@export var quest_goal: int = 1
@export var quest_description: String = ""

# 是否触发后就移除
@export var one_time_trigger: bool = true

var is_triggered = false

func _ready():
	body_entered.connect(_on_body_entered)
	QuestManager.connect("quest_completed", self._on_quest_completed)

func _on_body_entered(body: Node):
	if body.name == "Player" and not is_triggered:
		is_triggered = true
		_trigger_action()

func _trigger_action():
	match trigger_type:
		TriggerType.DIALOGUE:
			_start_dialogue()
		TriggerType.QUEST:
			_start_quest()
		TriggerType.BOTH:
			_start_dialogue()
			_start_quest()

func _start_dialogue():
	# 如果你希望自动排除空行,可以这样:
	var valid_lines = []
	for line in dialogue_lines:
		var trimmed = line.strip_edges()
		if trimmed != "":
			valid_lines.append(trimmed)

	# 只当 valid_lines 非空时才调用对话
	if valid_lines.size() > 0:
		DialogueUIManager.show_dialogue_3page(valid_lines, Callable(self, "_on_dialogue_finished"))
	else:
		# 如果对话内容为空，就直接结束
		_on_dialogue_finished()

func _on_dialogue_finished():
	# 对话结束后，如果只有对话，就移除
	if one_time_trigger and trigger_type == TriggerType.DIALOGUE:
		queue_free()
	# 如果是 BOTH，我们也可以等任务完成后再 free

func _start_quest():
	if quest_id != "":
		QuestManager.start_quest(quest_id, quest_goal, quest_description)

func _on_quest_completed(completed_quest_id: String):
	if completed_quest_id == quest_id:
		if one_time_trigger and trigger_type in [TriggerType.QUEST, TriggerType.BOTH]:
			queue_free()
