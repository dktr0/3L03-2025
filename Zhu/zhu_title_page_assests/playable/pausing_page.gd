extends Control

func _ready() -> void:
	# 让这个暂停界面在暂停时仍可交互
	process_mode = Node.PROCESS_MODE_ALWAYS
	# 让鼠标可见
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# 连接按钮信号
	$Menu.connect("pressed", Callable(self, "_on_menu_pressed"))
	$Exit.connect("pressed", Callable(self, "_on_exit_pressed"))
	$Unstuck.connect("pressed", Callable(self, "_on_unstuck_pressed"))

func _on_menu_pressed() -> void:
	# 恢复游戏的逻辑
	get_tree().paused = false
	# 然后切换场景
	get_tree().change_scene_to_file("res://Zhu/zhu_title_page_assests/playable/control.tscn")

func _on_exit_pressed() -> void:
	get_tree().quit()

func _on_unstuck_pressed() -> void:
	# 假设当前场景只有一个玩家节点，或者可通过唯一路径找到
	# 例如 "Player" 是玩家节点的名字
	var player_node = get_tree().get_current_scene().get_node("Player")

	if player_node is CharacterBody3D:
		# 如果玩家身上有元数据"last_safe_position"
		if player_node.has_meta("last_safe_position"):
			var safe_pos = player_node.get_meta("last_safe_position") as Vector3
			var transform = player_node.global_transform
			transform.origin = safe_pos
			player_node.global_transform = transform

			# 如果是 CharacterBody3D，可以把速度清零
			var cb3d = player_node as CharacterBody3D
			cb3d.velocity = Vector3.ZERO
		else:
			# 若玩家没有记录安全点，就像死亡区里的逻辑一样，重载场景
			get_tree().reload_current_scene()
