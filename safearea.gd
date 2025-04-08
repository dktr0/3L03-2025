extends Area3D

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	# 确认进入的是 CharacterBody3D（玩家）
	if body is CharacterBody3D:
		var cb = body as CharacterBody3D
		# 把该玩家当前位置存进 meta 里，比如叫做 "last_safe_position"
		cb.set_meta("last_safe_position", cb.global_transform.origin)
		# 当然也可以在此给玩家加血等别的逻辑
