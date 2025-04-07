extends Area3D

enum TriggerType {
	DIALOGUE,
	QUEST,
	BOTH
}

@export var trigger_type: TriggerType = TriggerType.DIALOGUE

@export var dialogue_lines: Array[String] = [
	"你好，冒险者！",
	"这是第二行对话。",
	"这是第三行。"
]

@export_enum("dialogue_only", "kill_monsters", "collect_items", "climb_quest", "open_chest")
var quest_id: String = "kill_monsters"

@export var quest_goal: int = 1
@export var quest_description: String = ""
@export var one_time_trigger: bool = true

# 如果是 climb_quest，需要玩家进入哪个Area才判定成功
@export var climb_area_path: NodePath

# 完成后要显的宝箱 (可选)
@export var chest_to_reveal_path: NodePath

# 当此前置任务完成后，要启动哪个宝箱任务ID?
# 例如 "open_chest_1", "open_chest_2"
@export var chest_quest_id_on_appear: String = "open_chest_1"

var is_triggered = false

# =========== 对话暂停/恢复 ===========
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
			if is_dialogue_paused:
				_resume_dialogue()

func _on_body_exited(body: Node):
	if body.name == "Player":
		if is_dialogue_active and not is_dialogue_paused:
			_pause_dialogue()

#
# =========== 核心触发逻辑 ===========
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
# =========== 对话部分 ===========
#
func _start_dialogue():
	if dialogue_lines.size() == 0:
		_on_dialogue_finished()
		return

	DialogueUIManager.show_dialogue_no_limit(dialogue_lines, Callable(self, "_on_dialogue_finished"))
	is_dialogue_active = true
	is_dialogue_paused = false

func _on_dialogue_finished():
	is_dialogue_active = false
	is_dialogue_paused = false

	if one_time_trigger and trigger_type == TriggerType.DIALOGUE:
		queue_free()

func _pause_dialogue():
	is_dialogue_paused = true
	paused_line_index = DialogueUIManager.get_current_line_index()
	paused_char_index = DialogueUIManager.get_current_char_index()
	paused_text = DialogueUIManager.get_current_display_text()

	DialogueUIManager.pause_dialogue()

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
# =========== 任务部分 ===========
#
func _start_quest():
	if quest_id == "dialogue_only":
		return

	if quest_id == "collect_items":
		QuestManager.track_collectibles_for_quest(quest_id, quest_goal, quest_description)
	elif quest_id == "climb_quest":
		if climb_area_path != null and climb_area_path != NodePath(""):
			var climb_area = get_node(climb_area_path)
			if climb_area:
				# Godot 4: 旧式4参 or Callable
				climb_area.body_entered.connect(
	Callable(self, "_on_climb_area_body_entered").bind(quest_id)
)
			else:
				push_warning("Climb area not found at path: %s" % climb_area_path)
		QuestManager.start_quest(quest_id, quest_goal, quest_description)
	else:
		# kill_monsters / open_chest => normal
		QuestManager.start_quest(quest_id, quest_goal, quest_description)

func _on_climb_area_body_entered(body: Node, quest_id: String):
	if body.name == "Player":
		QuestManager.add_progress(quest_id, 1)

#
# 前置任务完成 => 显示宝箱 => start chest_quest_id_on_appear
#
func _on_quest_completed(completed_quest_id: String):
	if quest_id == "dialogue_only":
		return

	if completed_quest_id == quest_id:
		# kill_monsters / collect_items / climb_quest => 显示宝箱 (可选) & start "chest_quest_id_on_appear"
		if quest_id in ["kill_monsters", "collect_items", "climb_quest"]:
			if chest_to_reveal_path != null and chest_to_reveal_path != NodePath(""):
				var chest = get_node(chest_to_reveal_path)
				if chest:
					# 显示宝箱 + 让其Area可交互
					chest.visible = true
					var area = chest.get_node("Area3D")
					if area:
						area.monitoring = true

					# 启动 "open_chest_2" or whatever you set in chest_quest_id_on_appear
					if chest_quest_id_on_appear.strip_edges() != "":
						QuestManager.start_quest(chest_quest_id_on_appear, 1, "Open chest => " + chest_quest_id_on_appear)
				else:
					push_warning("No chest found at path %s" % str(chest_to_reveal_path))

		if one_time_trigger and trigger_type in [TriggerType.QUEST, TriggerType.BOTH]:
			queue_free()

#
# 本脚本不监听 "chest_opened" 信号, 
# 由 chest.gd 脚本在 open_chest() 完成后 => QuestManager.add_progress(chest_quest_id).
# 这样每个宝箱有自己ID, 不冲突.
#
