extends Node

@export var pausing_page_scene: PackedScene = preload("res://Zhu/zhu_title_page_assests/playable/pausing_page.tscn")

var pausing_page: Control
var tween: Tween

func _ready():
	# 允许在暂停时依然处理输入
	process_mode = Node.PROCESS_MODE_ALWAYS

func _input(event):
	if Input.is_action_just_pressed("pause"):
		# 如果当前还没暂停，就执行淡入暂停
		if not get_tree().paused:
			pause_game_with_fade_in()
		else:
			# 如果已经暂停，就执行淡出恢复
			unpause_game_with_fade_out()

func pause_game_with_fade_in():
	# 如果已经在暂停状态，直接返回
	if get_tree().paused:
		return
	# 如果没设置 pausing_page_scene，给个警告
	if pausing_page_scene == null:
		push_warning("PauseManager: pausing_page_scene 未设置！")
		return

	# 若已有残留界面，先清理
	if pausing_page:
		pausing_page.queue_free()
		pausing_page = null

	# 若已有残留 tween（比如上一次动画没结束就点了ESC），先停止
	if tween:
		tween.kill()
		tween = null

	# 实例化暂停页面，让它一开始是透明
	pausing_page = pausing_page_scene.instantiate()
	pausing_page.modulate.a = 0.0
	get_tree().current_scene.add_child(pausing_page)

	# 鼠标可见
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# 创建淡入动画
	tween = create_tween()
	tween.tween_property(pausing_page, "modulate:a", 1.0, 0.5)
	tween.tween_callback(Callable(self, "_on_fade_in_done"))

func _on_fade_in_done():
	# 动画结束后才正式暂停游戏
	get_tree().paused = true

func unpause_game_with_fade_out():
	# 如果本来就不是暂停状态，就不用做了
	if not get_tree().paused:
		return

	# 没有界面，直接恢复
	if not pausing_page:
		resume_game()
		return

	# 如果上一个 tween 还在跑，先杀掉
	if tween:
		tween.kill()
		tween = null

	# 淡出动画
	tween = create_tween()
	tween.tween_property(pausing_page, "modulate:a", 0.0, 0.5)
	tween.tween_callback(Callable(self, "_on_fade_out_done"))

func _on_fade_out_done():
	# 淡出结束后，再取消暂停
	resume_game()

func resume_game():
	# 把暂停 UI 删掉
	if pausing_page:
		pausing_page.queue_free()
		pausing_page = null

	get_tree().paused = false

	
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
