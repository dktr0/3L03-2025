extends CanvasLayer

signal dialogue_finished

@onready var dialogue_panel = $DialoguePanel
@onready var dialogue_label = $DialoguePanel/DialogueLabel

@onready var quest_panel = $QuestPanel
@onready var quest_label = $QuestPanel/QuestLabel
@onready var quest_tracking_label = $QuestPanel/QuestTrackingLabel

@export var typing_speed: float = 0.04
@export var page_wait_time: float = 1.0

# 保存当前活跃任务的字典
var active_quests: Dictionary = {}

#
# ============= 对话相关变量 =============
#
var finish_callback = null         # 对话结束后的回调
var lines = []                     # 不再写 : Array[String]，改成动态数组
var current_line_index: int = 0
var current_char_index: int = 0

var typing_timer: Timer = null
var page_wait_timer: Timer = null

func _ready():
	dialogue_panel.visible = false
	quest_panel.visible = false

	# 连接到 QuestManager 信号
	QuestManager.connect("quest_started", self._on_quest_started)
	QuestManager.connect("quest_completed", self._on_quest_completed)
	QuestManager.connect("progress_updated", self._on_progress_updated)

	# 创建一个 Timer 用于“打字机”
	typing_timer = Timer.new()
	typing_timer.one_shot = false
	typing_timer.wait_time = typing_speed
	typing_timer.timeout.connect(_on_typing_timeout)
	add_child(typing_timer)

	# 创建另一个 Timer 用于“页面等待”
	page_wait_timer = Timer.new()
	page_wait_timer.one_shot = true
	page_wait_timer.wait_time = page_wait_time
	page_wait_timer.timeout.connect(_on_page_wait_timeout)
	add_child(page_wait_timer)

#
# =========== 对话：最多3页 + 打字机 + 自动翻页（无 yield/await） ===========
#
func show_dialogue_3page(pages, callback = null):
	"""
	不再写 `pages: Array[String]`，这样不会报“array of argument 1 does not match typed array”错误。
	任何类型都可以进来，我们在脚本内部把它转成字符串列表。
	"""
	finish_callback = callback

	var final_lines = []
	# 遍历传入的 pages 数组，把每个元素都转为字符串
	for item in pages:
		var text_version = str(item)            # 强制转字符串
		text_version = text_version.strip_edges()  # 去掉首尾空格
		if text_version != "":  # 如果不是空的，就保留
			final_lines.append(text_version)


	lines = final_lines
	current_line_index = 0
	dialogue_label.text = ""
	dialogue_panel.visible = true

	if lines.size() > 0:
		_start_typewriter_line(0)
	else:
		# 如果最终没有任何有效行，则直接结束
		_end_dialogue()

func _start_typewriter_line(line_index: int):
	current_line_index = line_index
	current_char_index = 0
	dialogue_label.text = ""
	typing_timer.wait_time = typing_speed
	typing_timer.start()

#
# 逐字显示：typing_timer.timeout 回调
#
func _on_typing_timeout():
	var line = lines[current_line_index]
	if current_char_index < line.length():
		dialogue_label.text += line[current_char_index]
		current_char_index += 1
	else:
		# 当前行已全部显示完
		typing_timer.stop()
		# 等待 page_wait_time 后继续下一行
		page_wait_timer.wait_time = page_wait_time
		page_wait_timer.start()

#
# 等 page_wait_time 后切下一行
#
func _on_page_wait_timeout():
	var next_line_index = current_line_index + 1
	if next_line_index < lines.size():
		_start_typewriter_line(next_line_index)
	else:
		_end_dialogue()

#
# 对话结束
#
func _end_dialogue():
	typing_timer.stop()
	page_wait_timer.stop()
	dialogue_panel.visible = false
	emit_signal("dialogue_finished")

	if finish_callback != null:
		finish_callback.call()

#
# ============= 任务UI相关 =============
#
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

func _refresh_quest_panel():
	if active_quests.size() == 0:
		quest_panel.visible = false
		return
	else:
		quest_panel.visible = true

	# 构建任务列表文本
	var text_lines = []
	for quest_id in active_quests.keys():
		var q = active_quests[quest_id]
		var desc = q["description"]
		var current = q["current"]
		var goal = q["goal"]
		var completed = q["completed"]

		var line = "%s:\n  %s\n  进度: %d / %d" % [quest_id, desc, current, goal]
		if completed:
			line += "\n  [已完成]"
		text_lines.append(line)

	# 更新左侧任务文本
	quest_label.text = text_lines.join("\n\n")

	# 显示更详细的追踪信息
	var tracker_info = []

	if active_quests.has("open_chest"):
		var chest_info = active_quests["open_chest"]
		if chest_info["completed"]:
			tracker_info.append("宝箱状态：已打开")
		else:
			tracker_info.append("宝箱状态：未打开")
	else:
		tracker_info.append("宝箱状态：无此任务")

	quest_tracking_label.text = tracker_info.join("\n")
