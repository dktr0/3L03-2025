extends Node3D
"""
场景内管理器: 
1) 存储本场景三种碎片 .tscn 路径;
2) 记录“已开箱次数” => 第一次 produce ring3, 第二次 produce ring, 第三次 ring2;
3) 当玩家进下一场景时(Portal/切换场景)，可以自动卸载本节点或重置  chest_open_count=0
"""

@export var shard_paths: Array[String] = [
	"res://Andy/amulet_ring3.tscn",
	"res://Andy/amulet_ring.tscn",
	"res://Andy/amulet_ring2.tscn"
]
var chest_open_count: int = 0

func _ready() -> void:
	print("[SceneChestsManager] Ready. chest_open_count=", chest_open_count)

func get_next_shard_scene_path() -> String:
	# 若chest_open_count<3 => 返回 shard_paths[chest_open_count]
	# 超过就返回空
	if chest_open_count < shard_paths.size():
		var path = shard_paths[chest_open_count]
		chest_open_count += 1
		return path
	else:
		push_warning("All 3 shards for this scene have been produced! No more shards.")
		return ""

func reset_chest_count():
	chest_open_count = 0
