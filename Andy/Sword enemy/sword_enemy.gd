extends CharacterBody3D

enum State {
	IDLE,
	PATROL,
	CHASE,
	ATTACK,
	RETURN
}

@export var is_patrol: bool = false
@export var detection_range: float = 10.0
@export var chase_speed: float = 2.0

@export var attack_cooldown: float = 2.0
@export var knockback_force: float = 5.0
@export var attack_anim_time: float = 1.0

@export var max_health: int = 5
var health: int

@export var gravity: float = 10.0
@export var can_auto_jump: bool = true
@export var auto_jump_speed: float = 4.0

@export var player_path: NodePath
@export var patrol_point_a: NodePath
@export var patrol_point_b: NodePath

var current_state: int = State.IDLE
var player_ref: Node3D
var original_position: Vector3
var patrol_target_index := 0
@export var turn_lerp_speed: float = 0.3

# ============== 与任务系统的互动 =============
@export var quest_on_death_id: String = "kill_monsters"
@export var quest_on_death_amount: int = 1

# ============== [删除] 玩家下方碰撞体 => 造成伤害 =============
# @export var player_collider_path: NodePath    # [删除]
# @export var collider_damage: int = 1          # [删除]
# var player_collider: Area3D                   # [删除]

# ---------- 攻击逻辑 -----------
var last_attack_time: float = -999.0
var is_in_attack_anim: bool = false
var is_in_attackholding: bool = false

# ---------- 死亡 ----------
var is_dead: bool = false

# ---------- 节点引用 ----------
@onready var anim_player: AnimationPlayer = $ice_monster/AnimationPlayer
@onready var attack_area: Area3D = $AttackArea

# ========== 音效节点 ==========
@onready var walk_sfx: AudioStreamPlayer3D = $WalkSFX
@onready var chase_sfx: AudioStreamPlayer3D = $ChaseSFX
@onready var attack_sfx: AudioStreamPlayer3D = $AttackSFX
@onready var die_sfx:   AudioStreamPlayer3D = $DieSFX

# ========== Chase音效定时器 ==========
var chase_timer: Timer = null

func _ready() -> void:
	add_to_group("Enemy")

	if anim_player:
		anim_player.animation_finished.connect(_on_animation_finished)

	if player_path:
		player_ref = get_node_or_null(player_path)

	original_position = global_transform.origin
	health = max_health

	if is_patrol:
		current_state = State.PATROL
		_play_walk_animation()
	else:
		current_state = State.IDLE
		_play_idle_animation()

	if attack_area:
		attack_area.body_entered.connect(_on_attack_area_body_entered)
		attack_area.body_exited.connect(_on_attack_area_body_exited)

	# =========== [删除] 原先玩家碰撞体监听 ===========
	# if player_collider_path != null:
	#     player_collider = get_node_or_null(player_collider_path)
	#     if player_collider:
	#         player_collider.body_entered.connect(_on_player_collider_body_entered)

	# =========== 新增：监听 "Sword" 组里的玩家剑Area3D ===========
	var swords = get_tree().get_nodes_in_group("Sword")
	if swords.size() > 0:
		for sword_area in swords:
			if sword_area is Area3D:
				sword_area.body_entered.connect(_on_sword_body_entered)
				# 可选：也可以连接 body_exited，看你是否需要

	# 创建chase_timer
	chase_timer = Timer.new()
	chase_timer.one_shot = false
	chase_timer.wait_time = 5.0
	chase_timer.timeout.connect(_on_chase_timer_timeout)
	add_child(chase_timer)

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if is_in_attack_anim or is_in_attackholding:
		_check_player_distance_scale(delta)
		_check_attack_holding_cooldown()
		_apply_gravity_and_auto_jump(delta)
		return

	match current_state:
		State.IDLE:
			_state_idle(delta)
		State.PATROL:
			_state_patrol(delta)
		State.CHASE:
			_state_chase(delta)
		State.ATTACK:
			_state_attack(delta)
		State.RETURN:
			_state_return(delta)

	if current_state not in [State.ATTACK, State.RETURN]:
		_check_player_distance_scale(delta)

	_apply_gravity_and_auto_jump(delta)

func _on_sword_body_entered(body: Node) -> void:
	# 如果是怪物自己进入了剑的碰撞，就让怪物掉血
	if body == self:
		take_damage(1)
		print("Monster got hit by sword!")
# =========== 状态逻辑 ===========
#
func _state_idle(_delta: float):
	velocity = Vector3.ZERO
	_play_idle_animation()

func _state_patrol(delta: float):
	if not patrol_point_a or not patrol_point_b:
		_play_idle_animation()
		velocity = Vector3.ZERO
		return

	_play_walk_animation()

	var target_point: Node3D
	if patrol_target_index == 0:
		target_point = get_node_or_null(patrol_point_a)
	else:
		target_point = get_node_or_null(patrol_point_b)
	if not target_point:
		velocity = Vector3.ZERO
		return

	var dx = target_point.global_transform.origin.x - global_transform.origin.x
	var dz = target_point.global_transform.origin.z - global_transform.origin.z
	var dist_xz = sqrt(dx*dx + dz*dz)

	if dist_xz < 0.3:
		patrol_target_index = 1 - patrol_target_index
		velocity = Vector3.ZERO
	else:
		var angle = atan2(dx, dz)
		rotation.y = lerp_angle(rotation.y, angle, turn_lerp_speed)
		var dir = Vector3(dx, 0, dz).normalized()
		velocity.x = dir.x * chase_speed
		velocity.z = dir.z * chase_speed

func _state_chase(delta: float):
	if not player_ref:
		return
	_play_walk_animation()

	var dx = player_ref.global_transform.origin.x - global_transform.origin.x
	var dz = player_ref.global_transform.origin.z - global_transform.origin.z
	var dist_xz = sqrt(dx*dx + dz*dz)

	if dist_xz > 0.001:
		var angle = atan2(dx, dz)
		rotation.y = lerp_angle(rotation.y, angle, turn_lerp_speed)
		var dir = Vector3(dx, 0, dz).normalized()
		velocity.x = dir.x * chase_speed
		velocity.z = dir.z * chase_speed
	else:
		velocity = Vector3.ZERO

func _state_attack(delta: float):
	_play_attackholding_animation()
	velocity = Vector3.ZERO

func _state_return(delta: float):
	_play_walk_animation()

	var dx = original_position.x - global_transform.origin.x
	var dz = original_position.z - global_transform.origin.z
	var dist_xz = sqrt(dx*dx + dz*dz)

	if dist_xz < 0.3:
		if is_patrol:
			current_state = State.PATROL
			_play_walk_animation()
		else:
			current_state = State.IDLE
			_play_idle_animation()
		return

	var angle = atan2(dx, dz)
	rotation.y = lerp_angle(rotation.y, angle, turn_lerp_speed)
	var dir = Vector3(dx, 0, dz).normalized()
	velocity.x = dir.x * chase_speed
	velocity.z = dir.z * chase_speed

#
# =========== 检测玩家距离(放大) ===========
#
func _check_player_distance_scale(delta: float):
	if not player_ref:
		return

	var scale_factor = (global_transform.basis.get_scale().x + global_transform.basis.get_scale().y + global_transform.basis.get_scale().z) / 3.0
	var used_range = detection_range
	if scale_factor > 1.0:
		used_range *= scale_factor

	var dx = player_ref.global_transform.origin.x - global_transform.origin.x
	var dz = player_ref.global_transform.origin.z - global_transform.origin.z
	var dist_xz = sqrt(dx*dx + dz*dz)

	if dist_xz < used_range:
		if current_state in [State.IDLE, State.PATROL, State.CHASE]:
			if current_state != State.CHASE:
				_start_chase_sfx()
			current_state = State.CHASE
			_play_walk_animation()
	else:
		if current_state in [State.CHASE, State.ATTACK]:
			_stop_chase_sfx()
			current_state = State.RETURN
			_play_walk_animation()

#
# =========== AttackArea 信号 ===========
#
func _on_attack_area_body_entered(body: Node):
	if is_dead:
		return
	if body == player_ref:
		if current_state in [State.IDLE, State.PATROL, State.CHASE]:
			_stop_chase_sfx()
			current_state = State.ATTACK
			var now_time = Time.get_unix_time_from_system()
			if now_time >= last_attack_time + attack_cooldown:
				_start_attack_anim()
			else:
				is_in_attackholding = true
				_play_attackholding_animation()

func _on_attack_area_body_exited(body: Node):
	if is_dead:
		return
	if body == player_ref:
		is_in_attackholding = false
		is_in_attack_anim = false
		if not is_dead:
			_start_chase_sfx()
			current_state = State.CHASE
			_play_walk_animation()

#
# =========== 攻击动画 & holding 逻辑 ===========
#
func _start_attack_anim():
	is_in_attack_anim = true
	is_in_attackholding = false
	last_attack_time = Time.get_unix_time_from_system()

	# 攻击动画 => 1s后砸下 => knockback + attack sound
	anim_player.play("attack")

	var slam_timer = Timer.new()
	slam_timer.one_shot = true
	slam_timer.wait_time = 1.0
	slam_timer.timeout.connect(_on_attack_slam)
	add_child(slam_timer)
	slam_timer.start()

func _on_attack_slam():
	if not is_dead and is_in_attack_anim:
		attack_sfx.play()
		_do_knockback_if_player_in_range()

func _play_attackholding_animation():
	if not is_dead and not is_in_attack_anim:
		is_in_attackholding = true
		if anim_player and anim_player.has_animation("attackholding"):
			anim_player.play("attackholding")

func _check_attack_holding_cooldown():
	if is_in_attackholding:
		if not _is_player_in_attack_area():
			is_in_attackholding = false
			is_in_attack_anim = false
			if not is_dead:
				_start_chase_sfx()
				current_state = State.CHASE
				_play_walk_animation()
			return

		var now_time = Time.get_unix_time_from_system()
		if now_time >= (last_attack_time + attack_cooldown):
			_start_attack_anim()

#
# =========== [删除] 玩家碰撞体 => 怪物受伤 ===========
#
# func _on_player_collider_body_entered(body: Node):
#     if is_dead:
#         return
#     if body == self:
#         take_damage(collider_damage)
#

#
# =========== 受伤 & 死亡 ===========
#

func take_damage(dmg_amount: int, _attacker: Node = null):
	health -= dmg_amount
	print("Monster took damage:", dmg_amount, " => health:", health)
	if health <= 0:
		_die()

func _die():
	if is_dead:
		return
	is_dead = true

	# ========== 新增：击败怪物任务加进度 ==========
	if quest_on_death_id.strip_edges() != "":
		QuestManager.add_progress(quest_on_death_id, quest_on_death_amount)

	# 死亡音效
	die_sfx.play()

	_stop_chase_sfx()
	_stop_walk_sfx()

	if anim_player and anim_player.has_animation("die"):
		anim_player.play("die")
	else:
		queue_free()

func _on_animation_finished(anim_name: String):
	if anim_name == "die" and is_dead:
		queue_free()
	elif anim_name == "attack":
		if not is_dead:
			is_in_attack_anim = false
			if _is_player_in_attack_area():
				is_in_attackholding = true
				_play_attackholding_animation()
			else:
				_start_chase_sfx()
				current_state = State.CHASE
				_play_walk_animation()
	elif anim_name == "attackholding":
		if not is_dead and _is_player_in_attack_area():
			is_in_attackholding = true
			_play_attackholding_animation()
		else:
			is_in_attackholding = false
			_start_chase_sfx()
			current_state = State.CHASE
			_play_walk_animation()

#
# =========== Knockback(攻击动画“砸下去”时) ===========
#

func _do_knockback_if_player_in_range():
	if _is_player_in_attack_area():
		var knockback_dir = (player_ref.global_transform.origin - global_transform.origin).normalized() * knockback_force
		if player_ref.has_method("knockback"):
			player_ref.knockback(knockback_dir)
		else:
			if player_ref is CharacterBody3D:
				player_ref.velocity += knockback_dir

func _is_player_in_attack_area() -> bool:
	if not player_ref:
		return false
	var bodies = attack_area.get_overlapping_bodies()
	return player_ref in bodies

#
# =========== 重力 & 自动跳 ===========
#

func _apply_gravity_and_auto_jump(delta: float):
	velocity.y -= gravity * delta

	if can_auto_jump and is_on_floor():
		_try_auto_jump()

	move_and_slide()

func _try_auto_jump():
	var forward = Vector3(sin(rotation.y), 0, cos(rotation.y)).normalized()
	var test_distance = 0.3
	var start_pos = global_transform.origin
	var collision = move_and_collide(forward * test_distance)
	if collision:
		var col = collision.get_collider()
		if col != player_ref and is_on_floor():
			velocity.y = auto_jump_speed
	global_transform.origin = start_pos

#
# =========== 音效逻辑 ===========
#

func _start_chase_sfx():
	if chase_timer == null:
		chase_timer = Timer.new()
		chase_timer.one_shot = false
		chase_timer.wait_time = 5.0
		chase_timer.timeout.connect(_on_chase_timer_timeout)
		add_child(chase_timer)
	if not chase_timer.is_stopped():
		return
	chase_timer.start()

func _stop_chase_sfx():
	if chase_timer and chase_timer.is_stopped() == false:
		chase_timer.stop()

func _on_chase_timer_timeout():
	if current_state == State.CHASE and not is_dead and not is_in_attack_anim and not is_in_attackholding:
		chase_sfx.play()

func _play_walk_animation():
	_start_walk_sfx()
	if not is_dead and not is_in_attack_anim and not is_in_attackholding:
		if anim_player and anim_player.current_animation != "walk":
			anim_player.play("walk")

func _play_idle_animation():
	_stop_walk_sfx()
	if not is_dead and not is_in_attack_anim and not is_in_attackholding:
		if anim_player and anim_player.has_animation("idle"):
			if anim_player.current_animation != "idle":
				anim_player.play("idle")
		else:
			_stop_animation()

func _stop_animation():
	if anim_player:
		anim_player.stop()

func _start_walk_sfx():
	if walk_sfx and not walk_sfx.playing:
		walk_sfx.play()

func _stop_walk_sfx():
	if walk_sfx and walk_sfx.playing:
		walk_sfx.stop()
