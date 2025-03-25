extends CharacterBody3D

enum AbilityType { NONE, SWORD, MAGIC }
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

@export var damage_amount: int = 1  

@export var max_health: int = 5
var health: int = 5

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var sword_area: Area3D = $Sword/Sword/SwordArea
@onready var attack_area: Area3D = $AttackArea

var ability_type: int = AbilityType.SWORD
var current_state: int = State.IDLE

var attack_timer: float = 0.0
var player_ref: Node3D
var original_position: Vector3

func _ready() -> void:
	add_to_group("Enemy")
	player_ref = get_tree().get_root().get_node("Game/Player")

	original_position = global_transform.origin
	health = max_health

	if is_patrol:
		current_state = State.PATROL
	else:
		current_state = State.IDLE

	sword_area.monitoring = false
	sword_area.monitorable = false
	sword_area.body_entered.connect(_on_sword_area_body_entered)

	attack_area.monitoring = true
	attack_area.monitorable = true
	attack_area.body_entered.connect(_on_attack_area_body_entered)
	attack_area.body_exited.connect(_on_attack_area_body_exited)

	match current_state:
		State.PATROL:
			if anim_player:
				anim_player.play("Patrol")
		State.IDLE:
			if anim_player:
				anim_player.play("idle")

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

# ========== AI状态函数 ==========

func _state_idle(_delta: float) -> void:
	velocity = Vector3.ZERO
	move_and_slide()

func _state_patrol(_delta: float) -> void:
	velocity = Vector3.ZERO
	move_and_slide()

func _state_chase(_delta: float) -> void:
	if not player_ref:
		return
	if anim_player and anim_player.current_animation == "Patrol":
		anim_player.stop()
	if anim_player and anim_player.current_animation != "walk":
		anim_player.play("walk")

	var my_pos = global_transform.origin
	var player_pos = player_ref.global_transform.origin
	var dir = (player_pos - my_pos)
	dir.y = 0
	dir = dir.normalized()

	var angle = atan2(dir.x, dir.z)
	rotation.y = lerp_angle(rotation.y, angle, 0.1)

	velocity.x = dir.x * chase_speed
	velocity.z = dir.z * chase_speed
	move_and_slide()

func _state_attack(delta: float) -> void:
	attack_timer += delta
	if attack_timer >= attack_cooldown:
		sword_area.set_deferred("monitoring", false)
		sword_area.set_deferred("monitorable", false)

		if _is_player_in_attack_area():
			attack_timer = 0.0
			if anim_player:
				anim_player.play("attack")
			sword_area.set_deferred("monitoring", true)
			sword_area.set_deferred("monitorable", true)
		else:
			current_state = State.CHASE
			if anim_player and anim_player.current_animation != "walk":
				anim_player.play("walk")

	velocity = Vector3.ZERO
	move_and_slide()

func _state_return(_delta: float) -> void:
	if anim_player and anim_player.current_animation == "Patrol":
		anim_player.stop()
	if anim_player and anim_player.current_animation != "walk":
		anim_player.play("walk")

	var my_pos = global_transform.origin
	var dir = (original_position - my_pos)
	dir.y = 0
	var dist = dir.length()

	if dist < 0.3:
		if is_patrol:
			current_state = State.PATROL
			if anim_player:
				anim_player.play("Patrol")
		else:
			current_state = State.IDLE
			if anim_player:
				anim_player.play("idle")
		return

	dir = dir.normalized()
	var angle = atan2(dir.x, dir.z)
	rotation.y = lerp_angle(rotation.y, angle, 0.1)

	velocity.x = dir.x * chase_speed
	velocity.z = dir.z * chase_speed
	move_and_slide()

func _check_player_distance() -> void:
	if not player_ref:
		return
	var dist = global_transform.origin.distance_to(player_ref.global_transform.origin)
	if dist < detection_range:
		if current_state in [State.IDLE, State.PATROL, State.CHASE]:
			current_state = State.CHASE
			if anim_player and anim_player.current_animation == "Patrol":
				anim_player.stop()
			if anim_player:
				anim_player.play("walk")
	else:
		if current_state in [State.CHASE, State.ATTACK]:
			sword_area.set_deferred("monitoring", false)
			sword_area.set_deferred("monitorable", false)
			current_state = State.RETURN
			if anim_player:
				anim_player.play("walk")



func _on_attack_area_body_entered(body: Node) -> void:
	if body.name == "Player": 
		if current_state in [State.CHASE, State.IDLE, State.PATROL]:
			current_state = State.ATTACK
			attack_timer = 0.0
			if anim_player:
				anim_player.play("attack")
			sword_area.set_deferred("monitoring", true)
			sword_area.set_deferred("monitorable", true)

func _on_attack_area_body_exited(_body: Node) -> void:

	pass

func _is_player_in_attack_area() -> bool:
	if not player_ref:
		return false
	var bodies = attack_area.get_overlapping_bodies()
	return player_ref in bodies



func _on_sword_area_body_entered(body: Node) -> void:
	if body.name == "Player": # or body.is_in_group("Player")
		if body.has_method("take_damage"):
			body.take_damage(damage_amount, self)


func take_damage(dmg_amount: int, _attacker: Node=null) -> void:
	health -= dmg_amount
	print("Enemy HP:", health)
	if health <= 0:
		_die()

func _die() -> void:
	print("Enemy died!")
	queue_free()
