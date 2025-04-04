extends Control

# ---------------------------
# 碎片图标
# ---------------------------
@onready var shard1_icon: TextureRect = $Shard1Icon
@onready var shard2_icon: TextureRect = $Shard2Icon
@onready var shard3_icon: TextureRect = $Shard3Icon

@export var shard1_texture: Texture2D
@export var shard2_texture: Texture2D
@export var shard3_texture: Texture2D

@export var start_with_shard1: bool = false
@export var start_with_shard2: bool = false
@export var start_with_shard3: bool = false
# ---------------------------
# 最终护身符图标
# ---------------------------
@onready var final_amulet_icon: TextureRect = $FinalAmuletIcon
@export var final_amulet_texture: Texture2D

# ---------------------------
# 音效相关
# ---------------------------
@onready var audio_player: AudioStreamPlayer2D = $AudioPlayer  # 在场景里添加的AudioStreamPlayer节点
@export var pickup_sound: AudioStream                       # 收集碎片时的提示音
@export var final_amulet_sound: AudioStream                 # 最终合成时播放的音效
@onready var missing_shards_label: Label = $MissingShardsLabel
# ---------------------------
# 记录淡出计数、以检测3个碎片都淡出后再合成
# ---------------------------
var fade_out_done_count: int = 0

func _ready():
	# 初始化三个碎片图标
	_init_shard_icon(shard1_icon)
	_init_shard_icon(shard2_icon)
	_init_shard_icon(shard3_icon)
	
	# 初始化最终护身符图标
	final_amulet_icon.visible = false
	final_amulet_icon.self_modulate.a = 0.0

	# 连接收集碎片的信号
	AmuletManager.connect("shard_collected_changed", Callable(self, "_on_shard_collected_changed"))
	if start_with_shard1:
		AmuletManager.collect_shard(1)
	if start_with_shard2:
		AmuletManager.collect_shard(2)
	if start_with_shard3:
		AmuletManager.collect_shard(3)
	# 如果已经收集过某些碎片(读档等)，立刻更新
	_update_shard_icon(1, AmuletManager.has_shard(1))
	_update_shard_icon(2, AmuletManager.has_shard(2))
	_update_shard_icon(3, AmuletManager.has_shard(3))
	
	missing_shards_label.visible = false
# 当某个碎片收集时

func _on_shard_collected_changed(shard_index: int, collected: bool) -> void:
	# 先更新UI动画(淡入或淡出)
	_update_shard_icon(shard_index, collected)

	# 如果这次是"收集"(collected=true)，播放叮铃提示音
	if collected and pickup_sound:
		audio_player.stream = pickup_sound
		audio_player.play()

	# 检查是否全部收集完(3块齐)
	if AmuletManager.has_shard(1) and AmuletManager.has_shard(2) and AmuletManager.has_shard(3):
		# 先把最终护身符贴图设置好(保持alpha=0)
		final_amulet_icon.texture = final_amulet_texture
		final_amulet_icon.visible = true
		final_amulet_icon.self_modulate.a = 0.0

		# 启动“等待 -> 并行淡出碎片 -> 淡入护身符”的流程
		# (使用无 then/sequence 兼容做法:先等->并行淡出->计数->淡入)
		var wait_tween = get_tree().create_tween()
		wait_tween.tween_callback(Callable(self, "_start_fade_out_shards")).set_delay(1.0)

#
# 等1秒后再开始淡出3个碎片
#
func _start_fade_out_shards():
	fade_out_done_count = 0
	_fade_out_icon(shard1_icon, 0.5)
	_fade_out_icon(shard2_icon, 0.5)
	_fade_out_icon(shard3_icon, 0.5)

#
# 当某个碎片淡出动画完成时, 计数+1
# 如果3个全完成, 隐藏碎片, 再淡入护身符
#
func _on_shard_fade_out_finished():
	fade_out_done_count += 1
	if fade_out_done_count == 3:
		# 3块碎片都已淡出
		shard1_icon.visible = false
		shard2_icon.visible = false
		shard3_icon.visible = false

		
		if final_amulet_sound:
			audio_player.stream = final_amulet_sound
			audio_player.play()

		
		var fadein_tween = get_tree().create_tween()
		fadein_tween.tween_property(final_amulet_icon, "self_modulate:a", 1.0, 1.0).from(0.0)


#
# 根据 collected 状态，对应碎片做淡入/淡出
#
func _update_shard_icon(shard_index: int, collected: bool) -> void:
	var icon_node: TextureRect
	var icon_texture: Texture2D
	
	match shard_index:
		1:
			icon_node = shard1_icon
			icon_texture = shard1_texture
		2:
			icon_node = shard2_icon
			icon_texture = shard2_texture
		3:
			icon_node = shard3_icon
			icon_texture = shard3_texture
		_:
			return

	if collected:
		icon_node.texture = icon_texture
		_fade_in_icon(icon_node, 0.5)
	else:
		_fade_out_icon(icon_node, 0.5)

#
# 初始化图标：隐藏 + alpha=0
#
func _init_shard_icon(icon_node: TextureRect):
	icon_node.visible = false
	icon_node.self_modulate.a = 0.0

#
# 淡入图标(0->1)
#
func _fade_in_icon(icon_node: TextureRect, duration: float):
	if icon_node.self_modulate.a >= 1.0:
		return
	icon_node.visible = true
	icon_node.self_modulate.a = 0.0

	var tween = get_tree().create_tween()
	tween.tween_property(icon_node, "self_modulate:a", 1.0, duration).from(0.0)

#
# 淡出图标(->0)，动画完成后发信号
#
func _fade_out_icon(icon_node: TextureRect, duration: float):
	if icon_node.self_modulate.a <= 0.0:
		# 已经是全透明，直接+1
		_on_shard_fade_out_finished()
		return

	var tween = get_tree().create_tween()
	tween.tween_property(icon_node, "self_modulate:a", 0.0, duration).from(icon_node.self_modulate.a)
	tween.finished.connect(_on_shard_fade_out_finished)
func show_missing_shards(missing: int) -> void:
	missing_shards_label.text = "Still need " + str(missing) + " shards to use the portal"
	missing_shards_label.visible = true

	# 如果想在若干秒后自动隐藏，也可以加一个 Timer 或 Tween
	var timer_tween = get_tree().create_tween()
	timer_tween.tween_callback(Callable(self, "_hide_missing_shards")).set_delay(3.0)

func _hide_missing_shards():
	missing_shards_label.visible = false
