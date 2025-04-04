extends Area3D

@export var player_path: NodePath

enum TeleportMethod {
	LOCAL_TELEPORT,
	CHANGE_SCENE
}

@export var teleport_method: TeleportMethod = TeleportMethod.LOCAL_TELEPORT
@export var target_position: Vector3 = Vector3.ZERO
@export var target_scene_path: String = "res://NextScene.tscn"

@export var amulet_ui_path: NodePath  # 在编辑器里把 AmuletUI 的路径 drag 到这里
									  # 例如 MainScene/UI/AmuletUI

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	var player = get_node_or_null(player_path)
	if not player:
		print("Portal: Cannot find player node from player_path!")
		return

	if body == player:
		if _player_has_all_shards():
			_teleport_player(player)
		else:
			var missing = _calculate_missing_shards()
			_show_missing_shards_on_ui(missing)

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

func _show_missing_shards_on_ui(missing: int):
	var ui = get_node_or_null("res://Andy/ui Amulet.tscn")
	if ui:
		# 调用前面UI脚本写的 show_missing_shards(missing)
		ui.show_missing_shards(missing)
	else:
		print("Portal: Cannot find UI node from amulet_ui_path")

func _teleport_player(player: Node):
	match teleport_method:
		TeleportMethod.LOCAL_TELEPORT:
			var transform = player.global_transform
			transform.origin = target_position
			player.global_transform = transform

		TeleportMethod.CHANGE_SCENE:
			AmuletManager.reset_shards()
			Loadingmanager.change_scene_with_loading(target_scene_path)
