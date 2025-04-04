extends Node3D

@export var fragment_scene: PackedScene
@export var fragment_index: int = 1
@export var spawn_condition_mode: int = 0

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var area: Area3D = $Area3D
@onready var open_sfx: AudioStreamPlayer3D = $OpenSFX
var is_opened: bool = false
var can_open: bool = false

func _ready():
	if spawn_condition_mode == 1:
		visible = false
		area.monitoring = false
	
	# 1) 连接Area3D进出事件
	area.body_entered.connect(_on_area_body_entered)
	area.body_exited.connect(_on_area_body_exited)

	# 2) 监听QuestManager任务完成
	QuestManager.connect("quest_completed", Callable(self, "_on_quest_completed"))

	# 3) 连接动画结束信号
	anim_player.animation_finished.connect(_on_animation_finished)

func _on_area_body_entered(body: Node):
	if body.name == "Player" and not is_opened:
		can_open = true

func _on_area_body_exited(body: Node):
	if body.name == "Player":
		can_open = false

func _input(event):
	# 1) 正常玩家交互
	if event.is_action_pressed("activate") and can_open and not is_opened:
		open_chest()

	# 2) 开发者测试: 按下 "dev_complete_quest" 直接让箱子出现(相当于任务完成)
	if event.is_action_pressed("dev_complete_quest"):
		if spawn_condition_mode == 1:
			_on_quest_completed()

func open_chest():
	if is_opened:
		return
	is_opened = true
	if open_sfx:
		open_sfx.play()
	# 如果存在名为 "open" 的动画，则播放
	if anim_player.has_animation("open"):
		anim_player.play("open")
	else:
		# 如果没有"open"动画, 直接执行生成碎片
		_on_open_animation_finished()


func _on_animation_finished(anim_name: String):
	if anim_name == "open":
		_on_open_animation_finished()

#
# 播放完动画后，生成护身符碎片
#
func _on_open_animation_finished():
	if fragment_scene:
		var fragment = fragment_scene.instantiate() as Node3D
		add_child(fragment)
		fragment.set("shard_index", fragment_index)
		fragment.global_transform = global_transform.translated(Vector3(0, 3, 0))


func _on_quest_completed():
	if spawn_condition_mode == 1:
		visible = true
		area.monitoring = true
