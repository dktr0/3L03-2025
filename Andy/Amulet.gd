extends Control

@export var overlays_path: NodePath

@onready var audio_player: AudioStreamPlayer2D = $AudioPlayer

# 拾取碎片时的提示音
@export var pickup_sound: AudioStream
# 合成护身符时的音效
@export var final_amulet_sound: AudioStream

# 可选：调试用，进入场景时就自动拥有指定碎片
@export var start_with_shard1: bool = false
@export var start_with_shard2: bool = false
@export var start_with_shard3: bool = false

func _ready():
	# 1) 连接碎片收集信号，只处理声音&最终护身符合成
	AmuletManager.connect("shard_collected_changed", Callable(self, "_on_shard_collected_changed"))

	# 2) 如果测试时想一进场就拥有碎片，可在Inspector里勾选
	if start_with_shard1:
		AmuletManager.collect_shard(1)
	if start_with_shard2:
		AmuletManager.collect_shard(2)
	if start_with_shard3:
		AmuletManager.collect_shard(3)

#
# 当玩家收集到某个碎片时
#
func _on_shard_collected_changed(shard_index: int, collected: bool):
	# 如果是刚收集到，就播放拾取音效
	if collected and pickup_sound:
		audio_player.stream = pickup_sound
		audio_player.play()

	# 若 1/2/3 全齐 -> 延时1秒后，再播放最终音效+展示三合一
	if AmuletManager.has_shard(1) and AmuletManager.has_shard(2) and AmuletManager.has_shard(3):
		var tw = create_tween()
		tw.tween_callback(Callable(self, "_on_all_shards_collected")).set_delay(1.0)

#
# 等1秒后，播放合成音效 + Overlays显示最终护身符
#
func _on_all_shards_collected():
	if final_amulet_sound:
		audio_player.stream = final_amulet_sound
		audio_player.play()

	var overlays = get_node(overlays_path)
	if overlays and overlays.has_method("show_final_amulet"):
		overlays.show_final_amulet(1.0)
