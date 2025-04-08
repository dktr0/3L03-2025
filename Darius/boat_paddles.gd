extends Node3D

@export var point_a: Vector3
@export var point_b: Vector3
@export var speed: float = 7.0
@export var interact_action := "activate"  # 交互键，可在 Input Map 中绑定 F 键
@export var distance_threshold := 0.5      # 船到达目标点的距离阈值

@export var player_path: NodePath          #

var boat_is_moving = false      # 船是否在 A-B 往返
var moving_to_b = true          # 当前船移动方向：true=向B, false=向A

var player_ref: Node3D = null         
var original_parent: Node = null      # 记住玩家原先的父节点
var original_transform: Transform3D   # 记住玩家的全局transform (下船时用)
var on_boat = false                   # 玩家是否真正"在船上"（已经 reparent）

func _ready():
	# 让船初始位于 point_a
	global_position = point_a

	# 如果在 Inspector 里已经拖拽了玩家节点到 player_path
	if player_path:
		player_ref = get_node_or_null(player_path)
	else:
		push_warning("No player assigned to 'player_path'. Please set it in the Inspector.")

func _process(delta: float) -> void:
	if boat_is_moving:
		var target: Vector3
		if moving_to_b:
			target = point_b
		else:
			target = point_a

		global_position = global_position.move_toward(target, speed * delta)

		if global_position.distance_to(target) < distance_threshold:
			moving_to_b = not moving_to_b

func _input(event: InputEvent) -> void:
	# 当玩家按下交互键
	if event.is_action_pressed(interact_action):
		# player_ref必须存在才行
		if player_ref != null:
			if not on_boat:
				# 第一次按键 => 上船
				_reparent_player_to_boat()
				on_boat = true
				boat_is_moving = not boat_is_moving 
			else:
				# 玩家已经在船上 => 第二次按键 => 下船
				_unparent_player_from_boat()
				on_boat = false
				boat_is_moving = false

#
# 当玩家进入 Area3D
#
func _on_area_3d_body_entered(body: Node3D) -> void:
	if body == player_ref:
		print("Player has stepped into the boat area.")

#
# 当玩家离开 Area3D
#
func _on_area_3d_body_exited(body: Node3D) -> void:
	if body == player_ref:
		print("Player left the boat area.")


#
# 把玩家挂到船节点
#
func _reparent_player_to_boat() -> void:
	if player_ref == null:
		return
	original_parent = player_ref.get_parent()
	original_transform = player_ref.global_transform

	original_parent.remove_child(player_ref)
	add_child(player_ref)

	# 调整玩家坐标, 示例将其移到船上方1米
	player_ref.global_transform = global_transform.translated(Vector3(0, 1.0, 0))

#
# 让玩家下船, 还原父节点和坐标
#
func _unparent_player_from_boat():
	if player_ref:
		remove_child(player_ref)
		original_parent.add_child(player_ref)
		player_ref.global_transform = original_transform

	original_parent = null
	original_transform = Transform3D()
