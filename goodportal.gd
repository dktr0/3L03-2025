extends Area3D

# 在 Godot 4.x 可以用 @export 声明可编辑字段（也支持 Godot 3.x 的 export var）
@export var player_path: NodePath

enum TeleportMethod {
	LOCAL_TELEPORT,
	CHANGE_SCENE
}
@export var teleport_method: TeleportMethod = TeleportMethod.LOCAL_TELEPORT

@export var target_position: Vector3 = Vector3.ZERO
@export var target_scene_path: String = "res://NextScene.tscn"

@export var amulet_ui_path: NodePath  # 拖拽UI节点
@export var character3d_path: NodePath  # 拖拽用来判断“是否消失”的角色节点

@export var good_ending_scene_path: String = "res://GoodEnding.tscn"
@export var bad_ending_scene_path: String = "res://BadEnding.tscn"

func _ready():
	# 当有刚体/角色进入这个 Area3D，自动调用 _on_body_entered
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	var player = get_node_or_null(player_path)
	if not player:
		push_error("Portal: Cannot find player node from player_path!")
		return

	# 如果进入区域的就是玩家
	if body == player:
		match teleport_method:
			TeleportMethod.LOCAL_TELEPORT:
				# 本地传送不需要碎片
				_teleport_player(player)
			TeleportMethod.CHANGE_SCENE:
				# 切换场景需要判断玩家是否拥有全部碎片
				if _player_has_all_shards():
					_teleport_player(player)

# ---------------------- 碎片判定相关函数 ----------------------

func _player_has_all_shards() -> bool:
	return AmuletManager.has_shard(1) \
		and AmuletManager.has_shard(2) \
		and AmuletManager.has_shard(3)

func _calculate_missing_shards() -> int:
	var missing = 3
	if AmuletManager.has_shard(1):
		missing -= 1
	if AmuletManager.has_shard(2):
		missing -= 1
	if AmuletManager.has_shard(3):
		missing -= 1
	return missing

# ---------------------- 真正的传送操作 ----------------------

func _teleport_player(player: Node):
	match teleport_method:
		TeleportMethod.LOCAL_TELEPORT:
			# 简单把玩家传送到 target_position
			var transform = player.global_transform
			transform.origin = target_position
			player.global_transform = transform

		TeleportMethod.CHANGE_SCENE:
			# 重置碎片收集进度（可选，看你游戏逻辑）
			AmuletManager.reset_shards()

			# 检测 character3D 是否已经消失
			var character_3d = get_node_or_null(character3d_path)

			if not is_instance_valid(character_3d):
				# 如果节点已不存在/被销毁 -> 说明条件达成，传送到好结局
				Loadingmanager.change_scene_with_loading(good_ending_scene_path)
			else:
				# 否则传送到坏结局
				Loadingmanager.change_scene_with_loading(bad_ending_scene_path)
