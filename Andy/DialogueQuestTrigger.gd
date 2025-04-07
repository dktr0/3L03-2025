extends Area3D

enum TriggerType {
	DIALOGUE,
	QUEST,
	BOTH
}

@export var trigger_type: TriggerType = TriggerType.DIALOGUE

# 对话数据
@export var dialogue_lines: Array[String] = [
	"你好，冒险者！",
	"这是第二行对话，带有标点符号。",
	"这是第三行，还有更多行也不会被截断。"
]
@export_enum("kill_monsters", "collect_items", "climb_quest", "open_chest")
var quest_id: String = "kill_monsters"

@export var quest_goal: int = 1
@export var quest_description: String = ""
@export var one_time_trigger: bool = true

var is_triggered = false

# =========== 新增: 对话暂停/恢复相关变量 ===========
var is_dialogue_active: bool = false
var is_dialogue_paused: bool = false

var paused_line_index: int = 0
var paused_char_index: int = 0
var paused_text: String = ""

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	QuestManager.connect("quest_completed", self._on_quest_completed)

func _on_body_entered(body: Node):
	if body.name == "Player":
		if not is_triggered:
			is_triggered = true
			_trigger_action()
		else:
			# 如果对话之前被暂停，则重新进入时恢复对话
			if is_dialogue_paused:
				_resume_dialogue()

func _on_body_exited(body: Node):
	if body.name == "Player":
		# 如果当前在对话中 -> 暂停对话
		if is_dialogue_active and not is_dialogue_paused:
			_pause_dialogue()

#
# =========== 主触发逻辑 ===========
#
func _trigger_action():
	match trigger_type:
		TriggerType.DIALOGUE:
			_start_dialogue()
		TriggerType.QUEST:
			_start_quest()
		TriggerType.BOTH:
			_start_dialogue()
			_start_quest()

#
# =========== 对话启动 & 结束 ===========
#
func _start_dialogue():
	# 如果对话列表为空, 当作无对话
	if dialogue_lines.size() == 0:
		_on_dialogue_finished()
		return

	# 调用 DialogueUIManager 来显示对话
	# 并注册对话结束回调 _on_dialogue_finished
	DialogueUIManager.show_dialogue_no_limit(dialogue_lines, Callable(self, "_on_dialogue_finished"))
	is_dialogue_active = true
	is_dialogue_paused = false

func _on_dialogue_finished():
	is_dialogue_active = false
	is_dialogue_paused = false

	if one_time_trigger and trigger_type == TriggerType.DIALOGUE:
		queue_free()
	# 如果是 BOTH, 或 QUEST, 就等任务完成后再 queue_free

#
# =========== 对话暂停/恢复 ===========
#
func _pause_dialogue():
	is_dialogue_paused = true
	# 从 DialogueUIManager 获取当前对话进度
	paused_line_index = DialogueUIManager.get_current_line_index()
	paused_char_index = DialogueUIManager.get_current_char_index()
	paused_text = DialogueUIManager.get_current_display_text()

	DialogueUIManager.pause_dialogue()  # 你需在UI里实现pause逻辑

func _resume_dialogue():
	is_dialogue_paused = false
	is_dialogue_active = true
	DialogueUIManager.resume_dialogue(
		dialogue_lines,
		paused_line_index,
		paused_char_index,
		paused_text,
		Callable(self, "_on_dialogue_finished")
	)

#
# =========== 任务启动 & 完成 ===========
#
func _start_quest():
	if quest_id != "":
		QuestManager.start_quest(quest_id, quest_goal, quest_description)

func _on_quest_completed(completed_quest_id: String):
	if completed_quest_id == quest_id:
		if one_time_trigger and trigger_type in [TriggerType.QUEST, TriggerType.BOTH]:
			queue_free()
