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
@export var attack_active_time: float = 0.4
@export var knockback_force: float = 5.0

@export var max_health: int = 5
var health: int

@onready var anim_player: AnimationPlayer = $ice_monster/AnimationPlayer
@onready var attack_area: Area3D = $AttackArea
@onready var attack_collision_area: Area3D = $AttackCollisionArea

# 在 AttackCollisionArea 下添加一个子节点 "AttackDebugMesh" (MeshInstance3D)，并默认隐藏
@onready var debug_mesh: MeshInstance3D = $AttackCollisionArea/AttackDebugMesh

@export var player_path: NodePath

# 拖拽两个物体，用于巡逻点 A / B
@export var patrol_point_a: NodePath
@export var patrol_point_b: NodePath

var current_state: int = State.IDLE
var attack_timer: float = 0.0
var attack_active_timer: float = 0.0
var attacking: bool = false

var player_ref: Node3D
var original_position: Vector3

var patrol_target_index := 0  # 0=A点, 1=B点

@export var turn_lerp_speed: float = 0.3

func _ready() -> void:
	add_to_group("Enemy")

	if player_path:
		player_ref = get_node_or_null(player_path)
	else:
		push_warning("No player_path assigned in Inspector! Please specify the player NodePath.")

	original_position = global_transform.origin
	health = max_health

	if is_patrol:
		current_state = State.PATROL
		_play_walk_animation()
	else:
		current_state = State.IDLE
		_stop_animation()

	# 设置攻击范围 (始终开启监测)
	attack_area.monitoring = true
	attack_area.monitorable = true
	attack_area.body_entered.connect(_on_attack_area_body_entered)
	attack_area.body_exited.connect(_on_attack_area_body_exited)

	# 攻击碰撞箱：初始关闭
	attack_collision_area.monitoring = false
	attack_collision_area.monitorable = false
	attack_collision_area.body_entered.connect(_on_attack_collision_body_entered)

	# 可视化网格：初始隐藏
	if debug_mesh:
		debug_mesh.visible = false

func _physics_process(delta: float) -> void:
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
		_check_player_distance()

# ========================= 各状态逻辑 =========================

func _state_idle(_delta: float) -> void:
	velocity = Vector3.ZERO
	move_and_slide()

func _state_patrol(delta: float) -> void:
	if not patrol_point_a or not patrol_point_b:
		_stop_animation()
		velocity = Vector3.ZERO
		move_and_slide()
		return

	_play_walk_animation()

	var target_point: Node3D
	if patrol_target_index == 0:
		target_point = get_node_or_null(patrol_point_a)
	else:
		target_point = get_node_or_null(patrol_point_b)

	if not target_point:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	var my_pos = global_transform.origin
	var tgt_pos = target_point.global_transform.origin

	# 只算水平方向的距离 dxz：忽略 Y 差
	var dx = tgt_pos.x - my_pos.x
	var dz = tgt_pos.z - my_pos.z
	var dxz = sqrt(dx*dx + dz*dz)

	# 如果离目标在水平面够近，就认为到达
	if dxz < 0.3:
		patrol_target_index = 1 - patrol_target_index
		velocity = Vector3.ZERO
		move_and_slide()
	else:
		var angle = atan2(dx, dz)
		angle = wrapf(angle, -PI, PI)
		rotation.y = wrapf(rotation.y, -PI, PI)
		rotation.y = lerp_angle(rotation.y, angle, turn_lerp_speed)
		rotation.y = wrapf(rotation.y, -PI, PI)

		var dir = Vector3(dx, 0, dz).normalized()
		velocity.x = dir.x * chase_speed
		velocity.z = dir.z * chase_speed
		move_and_slide()

func _state_chase(delta: float) -> void:
	if not player_ref:
		return
	_play_walk_animation()

	var my_pos = global_transform.origin
	var player_pos = player_ref.global_transform.origin

	# 一样忽略 Y，或你可以改用 3D 逻辑
	var dx = player_pos.x - my_pos.x
	var dz = player_pos.z - my_pos.z

	var dist_xz = sqrt(dx*dx + dz*dz)
	if dist_xz > 0.001:
		var angle = atan2(dx, dz)
		angle = wrapf(angle, -PI, PI)
		rotation.y = wrapf(rotation.y, -PI, PI)
		rotation.y = lerp_angle(rotation.y, angle, turn_lerp_speed)
		rotation.y = wrapf(rotation.y, -PI, PI)

		var dir = Vector3(dx, 0, dz).normalized()
		velocity.x = dir.x * chase_speed
		velocity.z = dir.z * chase_speed
	else:
		velocity = Vector3.ZERO

	move_and_slide()

func _state_attack(delta: float) -> void:
	attack_timer += delta
	_stop_animation()

	velocity = Vector3.ZERO
	move_and_slide()

	if attacking:
		attack_active_timer += delta
		if attack_active_timer >= attack_active_time:
			_disable_attack_collision()
			current_state = State.CHASE
	else:
		if attack_timer >= attack_cooldown:
			attack_timer = 0.0
			_enable_attack_collision()

func _state_return(delta: float) -> void:
	_play_walk_animation()

	var my_pos = global_transform.origin
	var dx = original_position.x - my_pos.x
	var dz = original_position.z - my_pos.z
	var dist_xz = sqrt(dx*dx + dz*dz)

	if dist_xz < 0.3:
		if is_patrol:
			current_state = State.PATROL
			_play_walk_animation()
		else:
			current_state = State.IDLE
			_stop_animation()
		return

	var angle = atan2(dx, dz)
	angle = wrapf(angle, -PI, PI)
	rotation.y = wrapf(rotation.y, -PI, PI)
	rotation.y = lerp_angle(rotation.y, angle, turn_lerp_speed)
	rotation.y = wrapf(rotation.y, -PI, PI)

	var dir = Vector3(dx, 0, dz).normalized()
	velocity.x = dir.x * chase_speed
	velocity.z = dir.z * chase_speed

	move_and_slide()

# ========================= 攻击碰撞箱(含调试网格) =========================

func _enable_attack_collision():
	attack_active_timer = 0.0
	attacking = true
	attack_collision_area.set_deferred("monitoring", true)
	attack_collision_area.set_deferred("monitorable", true)

	# 显示调试网格
	if debug_mesh:
		debug_mesh.visible = true

func _disable_attack_collision():
	attacking = false
	attack_collision_area.set_deferred("monitoring", false)
	attack_collision_area.set_deferred("monitorable", false)

	# 隐藏调试网格
	if debug_mesh:
		debug_mesh.visible = false

# ========================= 检测玩家 =========================

func _check_player_distance() -> void:
	if not player_ref:
		return
	var my_pos = global_transform.origin
	var player_pos = player_ref.global_transform.origin

	var dx = player_pos.x - my_pos.x
	var dz = player_pos.z - my_pos.z
	var dist_xz = sqrt(dx*dx + dz*dz)

	if dist_xz < detection_range:
		if current_state in [State.IDLE, State.PATROL, State.CHASE]:
			current_state = State.CHASE
			_play_walk_animation()
	else:
		if current_state in [State.CHASE, State.ATTACK]:
			_disable_attack_collision()
			current_state = State.RETURN
			_play_walk_animation()

func _is_player_in_attack_area() -> bool:
	if not player_ref:
		return false
	var bodies = attack_area.get_overlapping_bodies()
	return player_ref in bodies

# ========================= 信号回调 =========================

func _on_attack_area_body_entered(body: Node) -> void:
	if body == player_ref:
		if current_state in [State.CHASE, State.IDLE, State.PATROL]:
			current_state = State.ATTACK
			attack_timer = 0.0
			_disable_attack_collision()

func _on_attack_area_body_exited(body: Node) -> void:
	if body == player_ref:
		pass

func _on_attack_collision_body_entered(body: Node) -> void:
	if body == player_ref:
		_apply_knockback_to_player(body)

func _apply_knockback_to_player(target: Node):
	var knockback_dir = (target.global_transform.origin - global_transform.origin).normalized()
	if target.has_method("knockback"):
		target.knockback(knockback_dir * knockback_force)
	else:
		if target is CharacterBody3D:
			target.velocity += knockback_dir * knockback_force

# ========================= 受伤及死亡 =========================

func take_damage(dmg_amount: int, _attacker: Node = null):
	health -= dmg_amount
	if health <= 0:
		_die()

func _die():
	queue_free()

# ========================= 动画辅助 =========================

func _play_walk_animation():
	if anim_player and anim_player.current_animation != "walk":
		anim_player.play("walk")

func _stop_animation():
	if anim_player:
		anim_player.stop()
