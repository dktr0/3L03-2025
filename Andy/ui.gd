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
# var angle: float = 0.0             # 不再需要手动控制角度，由鼠标决定
var rotate_speed: float = 0.7      # 左右方向键时，每秒多少弧度 (恢复使用)
var manual_angle: float = 0.0      # 用于键盘/手柄控制时的角度
var use_mouse_control: bool = true # 默认使用鼠标控制

# 用于记录当前撞到的节点，便于高亮和按下Enter触发事件
var current_collision_node_name: String = ""

# 防止"顿一下"动作尚未完成时又被重复调用
var is_bumping: bool = false

func _ready() -> void:
	collision_detector.body_entered.connect(_on_body_entered)
	collision_detector.body_exited.connect(_on_body_exited)

	# 初始化所有按钮暗淡
	_update_button_highlight("")
	_start_blinking_labels()

func _physics_process(delta: float) -> void:
	if use_mouse_control:
		# --- Mouse Control --- 
		var mouse_pos = get_global_mouse_position()
		var pivot_pos = collision_pivot.global_position
		var mouse_angle = (mouse_pos - pivot_pos).angle()
		
		# Apply rotation with offset
		collision_pivot.rotation = mouse_angle + PI/2
		pointer_pivot.rotation = mouse_angle + PI/2
		
		# Sync manual_angle for smooth transition away from mouse
		manual_angle = mouse_angle 
	else:
		# --- Keyboard/Gamepad Control --- 
		if Input.is_action_pressed("move_right"):
			manual_angle += rotate_speed * delta
		elif Input.is_action_pressed("move_left"):
			manual_angle -= rotate_speed * delta
		
		# Apply rotation with offset
		collision_pivot.rotation = manual_angle + PI/2
		pointer_pivot.rotation = manual_angle + PI/2

func _input(event: InputEvent) -> void: # Changed _event to event
	# --- Input Detection for Switching Control Mode --- 
	if event is InputEventMouseMotion:
		use_mouse_control = true
	# Check for keyboard/gamepad move actions to switch away from mouse
	elif event.is_action_pressed("move_right") or event.is_action_pressed("move_left"):
		use_mouse_control = false
	
	# --- Activation Logic --- 
	# Check for activation action
	if Input.is_action_just_pressed("activate") or Input.is_action_just_pressed("ui_accept"):
		_activate_current_selection()
		get_viewport().set_input_as_handled() # Prevent further processing
		return

	# Check for mouse button press (Left Click)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
			_activate_current_selection()
			get_viewport().set_input_as_handled()
			return

	# Check for Joypad button press (Button 0/A/Cross or Button 2/X/Square)
	if event is InputEventJoypadButton:
		if (event.button_index == JOY_BUTTON_A or event.button_index == JOY_BUTTON_X) and event.is_pressed():
			# Note: JOY_BUTTON_A is typically index 0, JOY_BUTTON_X is typically index 2
			_activate_current_selection()
			get_viewport().set_input_as_handled()
			return

# Helper function to handle activation logic
func _activate_current_selection() -> void:
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

		# 播放"咚"声 & 顿一下(1秒)
		sfx_dong.play()
		_bump_pointer(1.0)

		# 更新按钮(高亮) + 背景色
		_update_button_highlight(name)

	else:
		# 普通刻度点：播放"滴答"，顿0.2秒
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

	# 创建一个 Tween，让按钮和背景"同时"开始渐变，但时长不同
	var tween = create_tween()
	tween.parallel()
	# 如果有按钮要高亮，就让它在 0.2 秒内从"当前颜色(暗淡)"->"金色"
	if button_to_highlight != null:
		tween.tween_property(button_to_highlight, "modulate", gold_color, 0.2)

	# 让背景在 0.5 秒内渐变到 target_color
	tween.tween_property(background_sprite, "modulate", target_color, 0.5)


#
# "顿一下"的实现，传入要停顿的时长
#
func _bump_pointer(pause_time: float) -> void:
	if is_bumping:
		return

	is_bumping = true
	# Store current speed and pause manual rotation if active
	var old_speed = rotate_speed 
	rotate_speed = 0 

	var timer = Timer.new()
	timer.wait_time = pause_time
	timer.one_shot = true
	add_child(timer)
	timer.start()

	# Restore speed after timeout
	var cb = Callable(self, "_on_bump_timeout").bind(old_speed) 
	timer.timeout.connect(cb)


func _on_bump_timeout(original_speed: float) -> void: # Restore speed parameter
	# Restore the rotation speed for manual control
	rotate_speed = original_speed 
	is_bumping = false
