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
@export var pickup_sound: AudioStream                         # 收集碎片时的提示音
@export var final_amulet_sound: AudioStream                   # 最终合成时播放的音效

@onready var missing_shards_label: Label = $MissingShardsLabel

# ---------------------------
# 记录淡出计数、以检测3个碎片都淡出后再合成
# ---------------------------
var fade_out_done_count: int = 0

func _ready():
	# 初始化三个碎片图标：隐藏+alpha=0
	_init_shard_icon(shard1_icon)
	_init_shard_icon(shard2_icon)
	_init_shard_icon(shard3_icon)

	# 初始化最终护身符图标：隐藏+alpha=0
	final_amulet_icon.visible = false
	final_amulet_icon.self_modulate.a = 0.0

	# 连接收集碎片的信号
	AmuletManager.connect("shard_collected_changed", Callable(self, "_on_shard_collected_changed"))

	# 如果有“起始时就拥有碎片”的选项，则先让 Manager 标记收集状态
	if start_with_shard1:
		AmuletManager.collect_shard(1)
	if start_with_shard2:
		AmuletManager.collect_shard(2)
	if start_with_shard3:
		AmuletManager.collect_shard(3)

	# 初始化时，根据 Manager 是否已经收集过（比如读档），去更新碎片 UI
	_update_shard_icon(1, AmuletManager.has_shard(1), true)
	_update_shard_icon(2, AmuletManager.has_shard(2), true)
	_update_shard_icon(3, AmuletManager.has_shard(3), true)

	# 隐藏“缺少碎片”的 Label
	missing_shards_label.visible = false


#
# 当某个碎片收集状态发生变化时
#
func _on_shard_collected_changed(shard_index: int, collected: bool) -> void:
	# 先更新UI动画(淡入或淡出)
	# skip_if_initial = false，因为这是“真正的”收集事件
	_update_shard_icon(shard_index, collected, false)

	# 如果这次是"收集"且有pickup_sound，则播放提示音
	if collected and pickup_sound:
		audio_player.stream = pickup_sound
		audio_player.play()

	# 检查是否全部收集完(三块全齐)
	if AmuletManager.has_shard(1) and AmuletManager.has_shard(2) and AmuletManager.has_shard(3):
		# 先把最终护身符贴图设置好(保持alpha=0)
		final_amulet_icon.texture = final_amulet_texture
		final_amulet_icon.visible = true
		final_amulet_icon.self_modulate.a = 0.0

		# 等1秒后，再开始淡出3个碎片
		var wait_tween = get_tree().create_tween()
		wait_tween.tween_callback(Callable(self, "_start_fade_out_shards")).set_delay(1.0)


#
# 等1秒后，再并行淡出3个碎片
#
func _start_fade_out_shards():
	fade_out_done_count = 0
	# 这里是真正要执行淡出，所以 skip_if_initial = false
	_fade_out_icon(shard1_icon, 0.5, false)
	_fade_out_icon(shard2_icon, 0.5, false)
	_fade_out_icon(shard3_icon, 0.5, false)


#
# 每个碎片淡出动画完成后，会调用此函数
# 如果3个都淡出完毕，就播放合成音效并淡入最终护身符
#
func _on_shard_fade_out_finished():
	fade_out_done_count += 1
	if fade_out_done_count == 3:
		# 所有碎片都已淡出
		shard1_icon.visible = false
		shard2_icon.visible = false
		shard3_icon.visible = false

		# 播放最终护身符音效
		if final_amulet_sound:
			audio_player.stream = final_amulet_sound
			audio_player.play()

		# 淡入最终护身符
		var fadein_tween = get_tree().create_tween()
		fadein_tween.tween_property(final_amulet_icon, "self_modulate:a", 1.0, 1.0).from(0.0)


#
# 更新指定碎片图标的UI动画
#   skip_if_initial：是否在“初始化或读档时”跳过淡出计数的逻辑
#
func _update_shard_icon(shard_index: int, collected: bool, skip_if_initial: bool) -> void:
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
		# 如果没收集，要淡出
		_fade_out_icon(icon_node, 0.5, skip_if_initial)


#
# 初始化碎片图标（隐藏 + alpha=0）
#
func _init_shard_icon(icon_node: TextureRect) -> void:
	icon_node.visible = false
	icon_node.self_modulate.a = 0.0


#
# 淡入图标(从0->1)
#
func _fade_in_icon(icon_node: TextureRect, duration: float) -> void:
	if icon_node.self_modulate.a >= 1.0:
		return
	icon_node.visible = true
	icon_node.self_modulate.a = 0.0

	var tween = get_tree().create_tween()
	tween.tween_property(icon_node, "self_modulate:a", 1.0, duration).from(0.0)


#
# 淡出图标(从当前值->0)，动画完成后发信号
# skip_if_initial：如果为true，且alpha已是0，就跳过计数
#
func _fade_out_icon(icon_node: TextureRect, duration: float, skip_if_initial: bool):
	if icon_node.self_modulate.a <= 0.0:
		# 已经是全透明
		if skip_if_initial:
			# 若在初始化/读档这种场合，就不计入淡出完成数，直接return
			return
		else:
			# 真正淡出时，若本来就透明，就直接视为完成
			_on_shard_fade_out_finished()
			return

	var tween = get_tree().create_tween()
	tween.tween_property(icon_node, "self_modulate:a", 0.0, duration).from(icon_node.self_modulate.a)
	tween.finished.connect(_on_shard_fade_out_finished)


#
# 显示“缺少多少碎片”提示
#
func show_missing_shards(missing: int) -> void:
	missing_shards_label.text = "Still need " + str(missing) + " shards to use the portal"
	missing_shards_label.visible = true

	# 如果想在若干秒后自动隐藏，也可以加一个 Timer 或 Tween
	var timer_tween = get_tree().create_tween()
	timer_tween.tween_callback(Callable(self, "_hide_missing_shards")).set_delay(3.0)


#
# 隐藏“缺少碎片”提示
#
func _hide_missing_shards():
	missing_shards_label.visible = false
