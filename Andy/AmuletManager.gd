# 文件: AmuletManager.gd
extends Node

# 用三个布尔值来标记碎片是否已收集
var shard_collected_1: bool = false
var shard_collected_2: bool = false
var shard_collected_3: bool = false

# 或者你也可以用一个 Array/Dictionary，但这里示例用单独变量
# var shard_collected := {
#   "shard1": false,
#   "shard2": false,
#   "shard3": false
# }

# 当成功收集碎片时会发射该信号，让 UI 更新
signal shard_collected_changed(shard_index: int, collected: bool)

func _ready():
	pass # 如果有初始化需求可写在这里

func collect_shard(shard_index: int) -> void:
	# 根据传入的索引更新收集状态
	match shard_index:
		1:
			shard_collected_1 = true
		2:
			shard_collected_2 = true
		3:
			shard_collected_3 = true
		_:
			push_warning("未知碎片索引: %d" % shard_index)
			return
	
	# 发射信号，通知所有监听者（例如 UI）
	emit_signal("shard_collected_changed", shard_index, true)

func has_shard(shard_index: int) -> bool:
	match shard_index:
		1:
			return shard_collected_1
		2:
			return shard_collected_2
		3:
			return shard_collected_3
		_:
			return false
