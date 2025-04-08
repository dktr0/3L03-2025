extends Node

@onready var anim_player: AnimationPlayer = $"../AnimationPlayer2"

var is_attacking: bool = false
var is_jumping: bool = false

# 【Run动画】循环区间
const RUN_LOOP_START = 1.5
const RUN_LOOP_END   = 4.0

# 【Jump动画】只播一次的区间
const JUMP_START = 1.6
const JUMP_END   = 2.2


func _ready() -> void:
	anim_player.animation_finished.connect(_on_animation_finished)

func _process(delta: float) -> void:
	# 如果正在攻击，就不切到其他动画
	if is_attacking:
		return
	
	if is_jumping:
		_process_jump_once()
		return

	# 检测移动方向
	var moving_forward = Input.is_action_pressed("move_forward")
	var moving_backward = Input.is_action_pressed("move_backward")
	var moving_left = Input.is_action_pressed("move_left")
	var moving_right = Input.is_action_pressed("move_right")

	# 攻击
	if Input.is_action_just_pressed("attack"):
		is_attacking = true
		anim_player.play("Sword")
		return

	# 跳跃
	if Input.is_action_just_pressed("move_jump"):
		is_jumping = true
		anim_player.play("Jump")
		# 跳过开头(0 ~ 1.6s)
		if anim_player.current_animation_position < JUMP_START:
			anim_player.seek(JUMP_START, true)
		return

	# 移动/冲刺
	if moving_forward or moving_backward or moving_left or moving_right:
		var sprinting = Input.is_action_pressed("move_sprint")
		if sprinting:
			anim_player.play("Run")
			# 若起始点<1.5，跳到1.5。这样只播 [1.5,4)
			if anim_player.current_animation_position < RUN_LOOP_START:
				anim_player.seek(RUN_LOOP_START, true)
			_process_run_loop()
		else:
			anim_player.play("Walk")
	else:
		anim_player.play("Idle_001")


func _on_animation_finished(anim_name: String) -> void:
	if anim_name == "Sword":
		is_attacking = false
		_return_to_idle_walk_or_run()

func _return_to_idle_walk_or_run() -> void:
	var moving_forward = Input.is_action_pressed("move_forward")
	var moving_backward = Input.is_action_pressed("move_backward")
	var moving_left = Input.is_action_pressed("move_left")
	var moving_right = Input.is_action_pressed("move_right")

	if moving_forward or moving_backward or moving_left or moving_right:
		var sprinting = Input.is_action_pressed("move_sprint")
		if sprinting:
			anim_player.play("Run")
			_process_run_loop()
		else:
			anim_player.play("Walk")
	else:
		anim_player.play("Idle_001")



func _process_run_loop() -> void:
	if anim_player.current_animation == "Run":
		var pos = anim_player.current_animation_position
		if pos >= RUN_LOOP_END:
			anim_player.seek(RUN_LOOP_START, true)



func _process_jump_once() -> void:
	if anim_player.current_animation == "Jump":
		var pos = anim_player.current_animation_position
		if pos >= JUMP_END:
			# 强制停止动画(等效于播放结束)
			anim_player.stop()

			# 跳跃结束
			is_jumping = false
			_return_to_idle_walk_or_run()
