extends Control

func _ready():
	# 让这个暂停界面在暂停时仍可交互
	process_mode = Node.PROCESS_MODE_ALWAYS

	# 让鼠标可见
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# 连接按钮信号
	$Menu.connect("pressed", Callable(self, "_on_menu_pressed"))
	$Exit.connect("pressed", Callable(self, "_on_exit_pressed"))

func _on_menu_pressed():
	# 恢复游戏的逻辑
	get_tree().paused = false
	# 然后切换场景
	get_tree().change_scene_to_file("res://Zhu/zhu_title_page_assests/playable/control.tscn")

func _on_exit_pressed():
	get_tree().quit()
