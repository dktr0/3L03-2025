extends Control


@onready var shard1_node: TextureRect = $TextureRect6
@onready var shard2_node: TextureRect = $TextureRect5
@onready var shard3_node: TextureRect = $TextureRect2

@onready var shard12_node: TextureRect = $TextureRect7
@onready var shard23_node: TextureRect = $TextureRect3
@onready var shard13_node: TextureRect = $TextureRect4

@onready var shard123_node: TextureRect = $TextureRect

func _ready():
	# 1) 先隐藏所有节点
	_hide_all()

	# 2) 连接 Manager 的 “shards_updated” 信号
	#    当有碎片变化时，自动 `_on_shards_updated()`
	AmuletManager.connect("shards_updated", Callable(self, "_on_shards_updated"))

	# 3) 刚加载场景时，也检查一次
	_on_shards_updated()


# 当 Manager 的碎片状态有任何改变，就会触发这个回调
func _on_shards_updated():
	var has1 = AmuletManager.has_shard(1)
	var has2 = AmuletManager.has_shard(2)
	var has3 = AmuletManager.has_shard(3)
	show_for_shards(has1, has2, has3)


#

#
func show_for_shards(has_shard1: bool, has_shard2: bool, has_shard3: bool):
	_hide_all()
	var count = int(has_shard1) + int(has_shard2) + int(has_shard3)

	match count:
		1:
			if has_shard1:
				_fade_in(shard1_node, 0.5)
			elif has_shard2:
				_fade_in(shard2_node, 0.5)
			else:
				_fade_in(shard3_node, 0.5)

		2:
			if has_shard1 and has_shard2:
				_fade_in(shard12_node, 0.5)
			elif has_shard2 and has_shard3:
				_fade_in(shard23_node, 0.5)
			elif has_shard1 and has_shard3:
				_fade_in(shard13_node, 0.5)

		3:
			_fade_in(shard123_node, 0.5)

		_:
			# 0块 -> 不显示任何
			pass

func show_final_amulet(duration := 1.0):
	_hide_all()
	_fade_in(shard123_node, duration)

func fade_in_shard(index: int, duration := 0.5):
	var node = _get_shard_node(index)
	if node:
		_fade_in(node, duration)

func fade_out_shard(index: int, duration := 0.5):
	var node = _get_shard_node(index)
	if node:
		_fade_out(node, duration)

func _get_shard_node(index: int) -> TextureRect:
	match index:
		1:   return shard1_node
		2:   return shard2_node
		3:   return shard3_node
		12:  return shard12_node
		23:  return shard23_node
		13:  return shard13_node
		123: return shard123_node
	return null

func _fade_in(node: TextureRect, duration: float):
	if node.self_modulate.a >= 1.0:
		return
	node.visible = true
	node.self_modulate.a = 0.0
	var tw = create_tween()
	tw.tween_property(node, "self_modulate:a", 1.0, duration)

func _fade_out(node: TextureRect, duration: float):
	if node.self_modulate.a <= 0.0:
		node.visible = false
		return
	var tw = create_tween()
	tw.tween_property(node, "self_modulate:a", 0.0, duration)
	tw.finished.connect(
		func():
			node.visible = false
	)

func _hide_all():
	for child in get_children():
		if child is TextureRect:
			child.visible = false
			child.self_modulate.a = 0.0
