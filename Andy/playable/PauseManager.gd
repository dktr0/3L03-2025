extends Node

@export var pausing_page_scene: PackedScene = preload("res://Zhu/zhu_title_page_assests/playable/pausing_page.tscn")

var pausing_page: Control
func _ready():
	# 关键：允许在暂停时依然处理输入
	process_mode = Node.PROCESS_MODE_ALWAYS
func _input(event):
	if Input.is_action_just_pressed("pause"):
		if get_tree().paused:
			resume_game()
		else:
			pause_game_with_fade_in()

func pause_game_with_fade_in():
	if get_tree().paused:
		return  # 已经暂停了，不重复执行

	if pausing_page_scene == null:
		push_warning("PauseManager: pausing_page_scene 未设置！")
		return

	# 实例化暂停页面，先让其 alpha=0
	pausing_page = pausing_page_scene.instantiate()
	pausing_page.modulate.a = 0.0

	# 加到当前活动场景子节点
	get_tree().current_scene.add_child(pausing_page)

	# 让鼠标可见 (如果之前是隐藏或捕获状态)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# 在游戏还没暂停时进行淡入动画
	var tween = create_tween()
	tween.tween_property(pausing_page, "modulate:a", 1.0, 0.5)
	# 动画结束后再暂停游戏
	tween.tween_callback(Callable(self, "_on_fade_in_done"))

func _on_fade_in_done():
	# 在淡入动画完毕后再暂停游戏
	get_tree().paused = true

func resume_game():
	# 恢复游戏逻辑
	if pausing_page:
		pausing_page.queue_free()
		pausing_page = null

	get_tree().paused = false

	# 如果需要重新捕获鼠标，可以写：
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
