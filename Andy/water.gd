extends Area3D
class_name WaterArea

@export var is_water_area: bool = true
@export var call_set_in_water_on_player: bool = true
@export var sub_island_player_path: NodePath

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node):
	# 如果这是水区域
	if not is_water_area:
		return

	# 如果要自动调用 player.set_in_water(true)
	if call_set_in_water_on_player:
		if sub_island_player_path != null:
			var sub_player = get_node_or_null(sub_island_player_path)
			if body == sub_player:
				# 调用sub_player.set_in_water(true)
				if sub_player.has_method("set_in_water"):
					sub_player.set_in_water(true)

func _on_body_exited(body: Node):
	if not is_water_area:
		return

	if call_set_in_water_on_player:
		if sub_island_player_path != null:
			var sub_player = get_node_or_null(sub_island_player_path)
			if body == sub_player:
				# 调用sub_player.set_in_water(false)
				if sub_player.has_method("set_in_water"):
					sub_player.set_in_water(false)
