extends Control

@onready var background = $Background
@onready var halcyon    = $"Halcyon-clickToStart"
@onready var press_label = $PressLabel

func _ready() -> void:
	# 设置初始可见度
	background.modulate = Color(1,1,1,1)  # 背景完全可见
	halcyon.modulate    = Color(1,1,1,0)  # Halcyon 透明
	press_label.modulate= Color(1,1,1,0)  # Label 透明

	# 用 call_deferred 确保场景加载后再启动协程
	call_deferred("fade_in_sequence")

func fade_in_sequence() -> void:
	# 先等 1 秒
	await get_tree().create_timer(1.0).timeout

	# 1) 淡入 halcyon (从当前 alpha=0 -> alpha=1，时长1秒)
	var color_from = halcyon.modulate              # 当前正是 alpha=0
	var color_to   = color_from
	color_to.a     = 1.0                           # 目标 alpha=1

	var tween1 = get_tree().create_tween()
	tween1.tween_property(halcyon, "modulate", color_to, 1.0)
	await tween1.finished

	# 2) 淡入 press_label (从 alpha=0 -> alpha=1)
	color_from = press_label.modulate
	color_to   = color_from
	color_to.a = 1.0

	var tween2 = get_tree().create_tween()
	tween2.tween_property(press_label, "modulate", color_to, 1.0)
	await tween2.finished
	# 到这里 halcyon & label 都淡入完成

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_accept"):
		fade_out_and_goto_menu()

func fade_out_and_goto_menu() -> void:
	# 同时淡出 background, halcyon, press_label
	var tween = get_tree().create_tween()

	# 背景淡出
	var bg_from = background.modulate
	var bg_to   = bg_from
	bg_to.a     = 0.0
	tween.tween_property(background, "modulate", bg_to, 1.0)

	# Halcyon 淡出
	var h_from = halcyon.modulate
	var h_to   = h_from
	h_to.a     = 0.0
	tween.tween_property(halcyon, "modulate", h_to, 1.0)

	# Label 淡出
	var lbl_from = press_label.modulate
	var lbl_to   = lbl_from
	lbl_to.a     = 0.0
	tween.tween_property(press_label, "modulate", lbl_to, 1.0)

	# 等待三条插值都完成
	await tween.finished
	get_tree().change_scene_to_file("res://Zhu/control.tscn")
