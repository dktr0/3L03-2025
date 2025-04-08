extends Node3D

@export var chest_quest_id: String = "open_chest_1"
"""
每只宝箱有独立任务ID, 如 "open_chest_1", "open_chest_2", ...
当玩家打开该宝箱时, add_progress(chest_quest_id,1).
"""

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var area: Area3D               = $Area3D
@onready var open_sfx: AudioStreamPlayer3D = $OpenSFX

var is_opened: bool = false
var can_open: bool = false

func _ready():
	
	
	

	area.body_entered.connect(_on_area_body_entered)
	area.body_exited.connect(_on_area_body_exited)
	anim_player.animation_finished.connect(_on_animation_finished)

func _on_area_body_entered(body: Node):
	if body.name == "Player" and not is_opened:
		can_open = true

func _on_area_body_exited(body: Node):
	if body.name == "Player":
		can_open = false

func _input(event):
	if event.is_action_pressed("activate"):
		if can_open and not is_opened:
			open_chest()

func open_chest():
	if is_opened:
		return
	is_opened = true

	if open_sfx:
		open_sfx.play()

	if anim_player.has_animation("open"):
		anim_player.play("open")
	else:
		_on_open_animation_finished()

func _on_animation_finished(anim_name: String):
	if anim_name == "open":
		_on_open_animation_finished()

func _on_open_animation_finished():
	var scene_manager_path = "../SceneChestsManager"  # 依你节点层级
	var scene_manager = get_node(scene_manager_path)
	if scene_manager == null:
		push_warning("SceneChestsManager not found. Can't produce shard.")
	else:
		# 从 manager 获取下一碎片路径
		var scene_path = scene_manager.get_next_shard_scene_path()
		if scene_path != "":
			var frag_scene = ResourceLoader.load(scene_path) as PackedScene
			if frag_scene:
				var fragment = frag_scene.instantiate() as Node3D
				add_child(fragment)
				fragment.global_transform = global_transform.translated(Vector3(0,3,0))
	# 产出碎片(如需)
	# ...
	
	#  任务加进度 => chest_quest_id
	QuestManager.add_progress(chest_quest_id, 1)
