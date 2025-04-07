extends CanvasLayer

signal dialogue_finished

@onready var dialogue_panel = $DialoguePanel
@onready var dialogue_label = $DialoguePanel/DialogueLabel

@onready var quest_panel = $QuestPanel
@onready var quest_label = $QuestPanel/QuestLabel
@onready var quest_tracking_label = $QuestPanel/QuestTrackingLabel

@export var typing_speed: float = 0.04
@export var page_wait_time: float = 1.0

# 保存所有活跃任务信息
var active_quests: Dictionary = {}

# ============= 对话相关 =============
var finish_callback = null
var lines = []
var current_line_index: int = 0
var current_char_index: int = 0

var typing_timer: Timer
var page_wait_timer: Timer

# 当对话被“暂停”时，用于resume
var is_paused: bool = false

func _ready():
	dialogue_panel.visible = false
	quest_panel.visible = false

	QuestManager.connect("quest_started", self._on_quest_started)
	QuestManager.connect("quest_completed", self._on_quest_completed)
	QuestManager.connect("progress_updated", self._on_progress_updated)

	# 打字机计时器
	typing_timer = Timer.new()
	typing_timer.one_shot = false
	typing_timer.wait_time = typing_speed
	typing_timer.timeout.connect(_on_typing_timeout)
	add_child(typing_timer)

	# 自动翻页计时器
	page_wait_timer = Timer.new()
	page_wait_timer.one_shot = true
	page_wait_timer.wait_time = page_wait_time
	page_wait_timer.timeout.connect(_on_page_wait_timeout)
	add_child(page_wait_timer)


# ==================== 对话相关 ====================

func show_dialogue_no_limit(pages, callback = null):
	finish_callback = callback
	is_paused = false

	var final_lines = []
	for item in pages:
		var txt = str(item).strip_edges()
		if txt != "":
			final_lines.append(txt)

	lines = final_lines
	current_line_index = 0
	current_char_index = 0
	dialogue_label.text = ""
	dialogue_panel.visible = true

	if lines.size() > 0:
		_start_typewriter_line(0)
	else:
		_end_dialogue()

func _start_typewriter_line(line_idx: int):
	current_line_index = line_idx
	current_char_index = 0
	dialogue_label.text = ""
	typing_timer.wait_time = typing_speed
	typing_timer.start()

func _on_typing_timeout():
	if is_paused:
		return

	var line = lines[current_line_index]
	if current_char_index < line.length():
		dialogue_label.text += line[current_char_index]
		current_char_index += 1
	else:
		typing_timer.stop()
		page_wait_timer.wait_time = page_wait_time
		page_wait_timer.start()

func _on_page_wait_timeout():
	if is_paused:
		return

	var next_line = current_line_index + 1
	if next_line < lines.size():
		_start_typewriter_line(next_line)
	else:
		_end_dialogue()

func _end_dialogue():
	typing_timer.stop()
	page_wait_timer.stop()
	dialogue_panel.visible = false
	is_paused = false

	emit_signal("dialogue_finished")
	if finish_callback != null:
		finish_callback.call()

# -------------- 暂停与恢复 --------------

func pause_dialogue():
	is_paused = true
	typing_timer.stop()
	page_wait_timer.stop()
	dialogue_panel.visible = false

func resume_dialogue(pages, line_idx: int, char_idx: int, partial_text: String, callback = null):
	is_paused = false
	finish_callback = callback

	var final_lines = []
	for item in pages:
		var txt = str(item).strip_edges()
		if txt != "":
			final_lines.append(txt)
	lines = final_lines

	current_line_index = line_idx
	if current_line_index >= lines.size():
		_end_dialogue()
		return

	var line = lines[current_line_index]
	current_char_index = char_idx
	if current_char_index > line.length():
		current_char_index = line.length()

	dialogue_panel.visible = true
	dialogue_label.text = partial_text

	typing_timer.wait_time = typing_speed
	typing_timer.start()

func get_current_line_index() -> int:
	return current_line_index

func get_current_char_index() -> int:
	return current_char_index

func get_current_display_text() -> String:
	return dialogue_label.text


# ==================== 任务UI相关 ====================

func _on_quest_started(quest_id: String):
	if QuestManager.quests_data.has(quest_id):
		active_quests[quest_id] = QuestManager.quests_data[quest_id]
	_refresh_quest_panel()

func _on_progress_updated(quest_id: String, current: int, goal: int):
	if active_quests.has(quest_id):
		active_quests[quest_id]["current"] = current
		active_quests[quest_id]["goal"] = goal
	_refresh_quest_panel()

func _on_quest_completed(quest_id: String):
	if active_quests.has(quest_id):
		active_quests.erase(quest_id)
	_refresh_quest_panel()

#
# 在这里把 “open_chest_x” 之类任务ID 强行显示成 "Quest: Open the chest"
# kill_monsters / collect_items => "current / goal"
# climb_quest / open_chest => complete/incomplete
#
func _refresh_quest_panel():
	if active_quests.size() == 0:
		quest_panel.visible = false
		return
	else:
		quest_panel.visible = true

	var text_lines = []   # 左侧：Quest: <desc> ...
	var tracker_info = [] # 右侧: Progress: ...

	for quest_id in active_quests.keys():
		var q = active_quests[quest_id]
		var desc = q["description"]
		var current = q["current"]
		var goal = q["goal"]
		var completed = q["completed"]

		# 如果任务ID是 "open_chest" / "open_chest_1" / "open_chest_2"...
		# 强制让 desc = "Open the chest"
		if quest_id.begins_with("open_chest"):
			desc = "Open the chest"

		# 左侧: "Quest: <desc>"
		var line = "Quest: %s" % desc
		if completed:
			line += " [已完成]"
		text_lines.append(line)

		# 右侧: kill_monsters/collect_items => x / y ; climb_quest/open_chest => complete/incomplete
		var info_line = ""
		if quest_id == "kill_monsters" or quest_id == "collect_items":
			info_line = "Progress: %d / %d" % [current, goal]
		elif quest_id == "climb_quest" or quest_id.begins_with("open_chest"):
			if completed:
				info_line = "Progress: complete"
			else:
				info_line = "Progress: incomplete"

		if info_line != "":
			tracker_info.append(info_line)

	# 拼接
	quest_label.text = array_to_string(text_lines, "\n\n")

	if tracker_info.size() == 0:
		quest_tracking_label.text = "No detailed quest info"
	else:
		quest_tracking_label.text = array_to_string(tracker_info, "\n")


#
# 用于拼接数组 => 字符串, 避免 Godot 4.3 "joined()" 警告
#
func array_to_string(arr: Array, sep: String) -> String:
	var result = ""
	for i in range(arr.size()):
		if i > 0:
			result += sep
		result += str(arr[i])
	return result
