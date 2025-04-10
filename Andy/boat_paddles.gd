extends Node3D

@export var point_a: NodePath
@export var point_b: NodePath
@export var drop_off_a: NodePath
@export var drop_off_b: NodePath

@export var travel_speed: float = 2.0
@export var stop_threshold: float = 0.2

@onready var area: Area3D = $Area3D  # 船上检测用的 Area3D

var heading_to_b = true
var player_onboard = false
var player_ref: CharacterBody3D = null   

var pa: Node3D
var pb: Node3D
var da: Node3D
var db: Node3D

@export var method_b_follow_position = false

func _ready() -> void:
	pa = get_node_or_null(point_a) as Node3D
	pb = get_node_or_null(point_b) as Node3D
	da = get_node_or_null(drop_off_a) as Node3D
	db = get_node_or_null(drop_off_b) as Node3D

	
	if pa:
		global_transform.origin = pa.global_transform.origin

	# 连接碰撞信号（检测玩家上船）
	area.body_entered.connect(_on_area_body_entered)
	area.body_exited.connect(_on_area_body_exited)

func _physics_process(delta: float) -> void:
	if player_onboard:
		_move_ship(delta)

		
		if method_b_follow_position and player_ref:
			
			
			var offset = Vector3(0, 1.0, 0)
			player_ref.global_transform.origin = global_transform.origin + offset



func _move_ship(delta: float) -> void:
	if not pa or not pb:
		return

	var target_pos: Vector3
	if heading_to_b:
		target_pos = pb.global_transform.origin
	else:
		target_pos = pa.global_transform.origin
	var current_pos = global_transform.origin

	var dir = target_pos - current_pos
	var dist = dir.length()

	if dist > stop_threshold:
		# 继续行驶
		var step = travel_speed * delta
		dir = dir.normalized()
		global_transform.origin += dir * step
	else:
		# 抵达终点 => 把玩家挪到对应的 drop_off 点并解冻
		_drop_off_player()
		heading_to_b = not heading_to_b  # 往返

#
# 玩家进出船的检测
#
func _on_area_body_entered(body: Node) -> void:
	
	if not player_onboard and body is CharacterBody3D:
		player_ref = body as CharacterBody3D
		player_onboard = true

		
		player_ref.set_physics_process(false)

		# ================
		# Method A：重新挂载到船
		# ================
		if not method_b_follow_position:
			_reparent_player_to_boat(player_ref)
			print("玩家登船（re-parent方式），船启动！")

		# ================
		# Method B：仅用坐标跟随，不改父节点
		# ================
		else:
			print("玩家登船（position跟随方式），船启动！")


func _on_area_body_exited(body: Node) -> void:
	# 如果你想允许中途下船，可以在这里做逻辑
	# 否则保持空即可
	pass

#
# 抵达终点后，把玩家放到岸上
#
func _drop_off_player() -> void:
	if not player_ref:
		return

	# 判断当前是到B岸还是A岸
	if heading_to_b:
		if db:
			player_ref.global_transform.origin = db.global_transform.origin
	else:
		if da:
			player_ref.global_transform.origin = da.global_transform.origin

	# 恢复玩家到 SceneTree 下(脱离船父节点) - Method A需要
	if not method_b_follow_position:
		get_tree().get_root().add_child(player_ref)

	# 重新启用玩家脚本
	player_ref.set_physics_process(true)

	player_onboard = false
	player_ref = null

	print("船靠岸，把玩家放下。")


func _reparent_player_to_boat(player: Node) -> void:
	
	
	var old_parent = player.get_parent()
	if old_parent != null:
		old_parent.remove_child(player)
	# 然后再添加为船的子节点
	add_child(player)
