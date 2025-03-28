extends Area3D

enum TeleportMethod {
	LOCAL_TELEPORT,
	CHANGE_SCENE
}

@export var player_path: NodePath
@export var required_item_path: NodePath

@export var needs_required_item: bool = false
@export var teleport_method: TeleportMethod = TeleportMethod.LOCAL_TELEPORT


@export var target_position: Vector3 = Vector3.ZERO


@export var target_scene_path: String = "res://NextScene.tscn"

func _ready() -> void:

	self.body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	
	var player = get_node_or_null(player_path)
	if not player:
		print("Portal: Cannot find player node from player_path!")
		return

	if body == player:
		if not needs_required_item or _player_has_required_item(player):
			_teleport_player(player)
		else:
			print("Player does not have the required item!")

func _player_has_required_item(player: Node) -> bool:
	if required_item_path == null:
		print("Portal: required_item_path is null! No item referenced.")
		return false

	var required_item = get_node_or_null(required_item_path)
	if not required_item:
		print("Portal: Cannot find required item node from required_item_path!")
		return false

	if player.has_method("is_holding_item"):
		return player.is_holding_item(required_item)
	else:
		print("Player node does not have method is_holding_item()")
		return false

func _teleport_player(player: Node) -> void:
	match teleport_method:
		TeleportMethod.LOCAL_TELEPORT:
			var transform = player.global_transform
			transform.origin = target_position
			player.global_transform = transform

		TeleportMethod.CHANGE_SCENE:
			if get_tree():
				get_tree().change_scene_to_file(target_scene_path)
