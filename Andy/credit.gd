extends Control

# 用于记录当前显示中的TextureRect
var current_shown_rect: TextureRect = null

# 在ready里获取按钮和TextureRect引用，并连接按钮信号
func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	#    （注意要确保名字和树里的节点匹配）
	var sections := {
		"3DART": $"3DART"/TextureRect,
		"LevelDesign": $LevelDesign/TextureRect,
		"Programming": $Programming/TextureRect,
		"Sound": $Sound/TextureRect,
		"2DUI": $"2D UI"/TextureRect
	}
	$Button.connect("pressed", Callable(self, "_on_back_to_menu_pressed"))
	# 2) 隐藏所有 TextureRect，避免一开始都显示的情况
	for key in sections:
		sections[key].visible = false
		# 也可以顺便把透明度设成 0，方便后面Tween淡入
		sections[key].self_modulate.a = 0.0

	# 3) 连接每个按钮的 "pressed" 信号，带上一个自定义参数
	$"3DART".connect("pressed", Callable(self, "_on_button_pressed").bind("3DART"))
	$LevelDesign.connect("pressed", Callable(self, "_on_button_pressed").bind("LevelDesign"))
	$Programming.connect("pressed", Callable(self, "_on_button_pressed").bind("Programming"))
	$Sound.connect("pressed", Callable(self, "_on_button_pressed").bind("Sound"))
	$"2D UI".connect("pressed", Callable(self, "_on_button_pressed").bind("2DUI"))

	# 4) 把这个字典存起来（方便在回调里用它找对应TextureRect）
	set_meta("sections_dict", sections)


# 按钮被按下时的回调函数
func _on_button_pressed(section_name: String) -> void:
	var sections = get_meta("sections_dict") as Dictionary
	if not sections.has(section_name):
		return  # 容错处理

	# 1) 隐藏上一个显示中的 TextureRect（如果有的话）
	if current_shown_rect:
		current_shown_rect.visible = false
		current_shown_rect.self_modulate.a = 0.0

	# 2) 取出本次要显示的 TextureRect
	var new_rect = sections[section_name] as TextureRect
	new_rect.visible = true

	# 3) 用一个 Tween 来做“从透明到不透明”的淡入
	var t = create_tween()
	# 先把透明度设为0（以防万一）
	new_rect.self_modulate.a = 0.0
	# 然后Tween到完全不透明，时间0.5秒可自行调整
	t.tween_property(new_rect, "self_modulate",
		Color(1, 1, 1, 1), 0.5)

	# 4) 记录当前显示的 rect
	current_shown_rect = new_rect
func _on_back_to_menu_pressed() -> void:
	
	Loadingmanager.change_scene_with_loading("res://Zhu/zhu_title_page_assests/playable/control.tscn")
	
