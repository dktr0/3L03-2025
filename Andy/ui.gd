extends Node2D

# 1) 获取需要的节点引用
@onready var collision_pivot: Node2D = $CollisionPivot
@onready var collision_detector: Area2D = $CollisionPivot/CollisionDetector

@onready var pointer_pivot: Node2D = $PointerPivot
@onready var pointer_sprite: Sprite2D = $PointerPivot/PointerSprite

@onready var start_label: CanvasItem = $StartLabel
@onready var credit_label: CanvasItem = $CreditLabel
@onready var intro_label: CanvasItem = $IntroLabel

# ★ 新增：引用背景 Sprite2D
@onready var background_sprite: Sprite2D = $Background

# 音频节点 (AudioStreamPlayer2D)
@onready var sfx_tick: AudioStreamPlayer2D = $SFX_Tick
@onready var sfx_dong: AudioStreamPlayer2D = $SFX_dong
@onready var label_press: Label = $"Press   and   to select"
@onready var label_press_enter: Label = $"Press enter"
# 2) 自定义属性
var angle: float = 0.0             # 当前旋转角度(弧度制)
var rotate_speed: float = 0.7      # 左右方向键时，每秒多少弧度

# 用于记录当前撞到的节点，便于高亮和按下Enter触发事件
var current_collision_node_name: String = ""

# 防止“顿一下”动作尚未完成时又被重复调用
var is_bumping: bool = false

func _ready() -> void:
	collision_detector.body_entered.connect(_on_body_entered)
	collision_detector.body_exited.connect(_on_body_exited)

	# 初始化所有按钮暗淡
	_update_button_highlight("")
	_start_blinking_labels()

func _physics_process(delta: float) -> void:
	if Input.is_action_pressed("move_right"):
		angle += rotate_speed * delta
	elif Input.is_action_pressed("move_left"):
		angle -= rotate_speed * delta

	collision_pivot.rotation = angle
	pointer_pivot.rotation = angle


func _input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("activate"):
		match current_collision_node_name:
			"PosStart":
				print("激活 START 按钮")
				Loadingmanager.change_scene_with_loading("res://Yunhan Liu2/beginning.tscn")
			"PosCredit":
				print("激活 CREDIT 按钮")
				Loadingmanager.change_scene_with_loading("res://Andy/credit.tscn")
			"PosIntro":
				print("激活 INTRO 按钮")
				get_tree().quit()
			_:
				pass
func _start_blinking_labels():
	var blink_tween = create_tween()
	blink_tween.set_loops(true)

	blink_tween.parallel()
	blink_tween.tween_property(label_press, "modulate", Color(1, 1, 0, 1), 1.0)
	blink_tween.tween_property(label_press_enter, "modulate", Color(1, 1, 0, 1), 1.0)

	blink_tween.chain().parallel()
	blink_tween.tween_property(label_press, "modulate", Color(1, 1, 1, 1), 1.0)
	blink_tween.tween_property(label_press_enter, "modulate", Color(1, 1, 1, 1), 1.0)
#
# 下面是碰撞信号回调
#
func _on_body_entered(body: Node) -> void:
	var name = body.name

	if name == "PosStart" or name == "PosCredit" or name == "PosIntro":
		current_collision_node_name = name

		# 播放“咚”声 & 顿一下(1秒)
		sfx_dong.play()
		_bump_pointer(1.0)

		# 更新按钮(高亮) + 背景色
		_update_button_highlight(name)

	else:
		# 普通刻度点：播放“滴答”，顿0.2秒
		sfx_tick.play()
		_bump_pointer(0.2)


func _on_body_exited(body: Node) -> void:
	# 如果离开的是当前记录的节点(特殊节点)，就恢复按钮暗淡。
	if body.name == current_collision_node_name:
		current_collision_node_name = ""

		# 这里只暗淡按钮，不改背景，让背景保持上一次的颜色
		_update_button_highlight("")


#
# 更新按钮的明暗（高亮 / 暗淡） & 调整背景
#
func _update_button_highlight(node_name: String) -> void:
	# 先让全部按钮暗淡
	start_label.modulate = Color(1,1,1,0.5)
	credit_label.modulate = Color(1,1,1,0.5)
	intro_label.modulate = Color(1,1,1,0.5)

	# 我们想要的金色
	var gold_color = Color(1.0, 0.85, 0.0, 1.0)
	# 背景的目标颜色，默认为当前颜色(表示不变)
	var target_color: Color = background_sprite.modulate

	# 用一个变量保存当前要高亮的按钮(如果有)
	var button_to_highlight: CanvasItem = null

	match node_name:
		"PosStart":
			button_to_highlight = start_label
			target_color = Color(0.3, 0.8, 1, 1)              # 示例：纯白
		"PosCredit":
			button_to_highlight = credit_label
			target_color = Color(0.25, 0.25, 0.25, 1)     # 示例：灰暗
		"PosIntro":
			button_to_highlight = intro_label
			target_color = Color(1.0, 0.2, 0.2, 1.0)         # 示例：蓝绿
		_:
			# 离开特殊节点，只暗淡按钮，不改变背景
			pass

	# 创建一个 Tween，让按钮和背景“同时”开始渐变，但时长不同
	var tween = create_tween()
	tween.parallel()
	# 如果有按钮要高亮，就让它在 0.2 秒内从“当前颜色(暗淡)”->“金色”
	if button_to_highlight != null:
		tween.tween_property(button_to_highlight, "modulate", gold_color, 0.2)

	# 让背景在 0.5 秒内渐变到 target_color
	tween.tween_property(background_sprite, "modulate", target_color, 0.5)


#
# “顿一下”的实现，传入要停顿的时长
#
func _bump_pointer(pause_time: float) -> void:
	if is_bumping:
		return
	
	is_bumping = true
	var old_speed = rotate_speed
	rotate_speed = 0

	var timer = Timer.new()
	timer.wait_time = pause_time
	timer.one_shot = true
	add_child(timer)
	timer.start()

	var cb = Callable(self, "_on_bump_timeout").bind(old_speed)
	timer.timeout.connect(cb)


func _on_bump_timeout(original_speed: float) -> void:
	rotate_speed = original_speed
	is_bumping = false
