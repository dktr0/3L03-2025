extends Node3D

@export var shard_index: int = 1
@export var rotation_speed: float = 45.0  # 每秒旋转度数
@export var collect_on_pick: bool = true

@onready var mesh: MeshInstance3D = $Torus
@onready var area: Area3D = $Area3D
var picked_up: bool = false

func _ready():
	# 连接检测：当Player进入Area3D时，就说明碰到了碎片
	area.body_entered.connect(_on_area_body_entered)

func _process(delta: float):
	# 让碎片自己旋转，绕Y轴
	rotate_y(deg_to_rad(rotation_speed * delta))

func _on_area_body_entered(body: Node):
	# 如果还没被拾取，并且进入的body是Player
	if not picked_up and body.name == "Player":
		picked_up = true
		# 如果要在碰到时立即收集
		if collect_on_pick:
			AmuletManager.collect_shard(shard_index)
		# 拾取后直接销毁碎片
		queue_free()
