extends Node

var shard_collected_1: bool = false
var shard_collected_2: bool = false
var shard_collected_3: bool = false

signal shard_collected_changed(shard_index: int, collected: bool)

func _ready():
	pass

func collect_shard(shard_index: int) -> void:
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

	emit_signal("shard_collected_changed", shard_index, true)
	print_debug("Collected shard %d" % shard_index)

func has_shard(shard_index: int) -> bool:
	match shard_index:
		1: return shard_collected_1
		2: return shard_collected_2
		3: return shard_collected_3
		_: return false

func reset_shards():
	shard_collected_1 = false
	shard_collected_2 = false
	shard_collected_3 = false
	print_debug("All shards reset.")
