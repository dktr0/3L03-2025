extends Node3D

@export var fragment_scene: PackedScene
@export var fragment_index: int = 1
@export var spawn_condition_mode: int = 0
"""
0 = 默认可见
1 = 要等“某个任务”完成后才出现
(因为我们没指定具体任务ID，所以只要任意任务完成就会触发 _on_quest_completed)
"""

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var area: Area3D = $Area3D
@onready var open_sfx: AudioStreamPlayer3D = $OpenSFX

var is_opened: bool = false
var can_open: bool = false

func _ready():
	# 若 spawn_condition_mode=1, 则默认隐藏, 等任务完成后再显示
	if spawn_condition_mode == 1:
		visible = false
		area.monitoring = false

	# 1) 连接 Area3D 的检测事件
	area.body_entered.connect(_on_area_body_entered)
	area.body_exited.connect(_on_area_body_exited)

	# 2) 监听 QuestManager 的 "quest_completed" 信号
	#    只要有任务完成，就调用 _on_quest_completed()
	QuestManager.connect("quest_completed", self._on_quest_completed)

	# 3) 监听动画结束
	anim_player.animation_finished.connect(_on_animation_finished)

func _on_area_body_entered(body: Node):
	if body.name == "Player" and not is_opened:
		can_open = true

func _on_area_body_exited(body: Node):
	if body.name == "Player":
		can_open = false

func _input(event):
	# 玩家按键“activate”，可以开箱
	if event.is_action_pressed("activate"):
		if can_open and not is_opened:
			open_chest()

	# 测试用: 按下 "dev_complete_quest" 等效于任务完成
	if event.is_action_pressed("dev_complete_quest"):
		if spawn_condition_mode == 1:
			_on_quest_completed()

#
# 打开宝箱
#
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

#
# 动画播放结束
#
func _on_animation_finished(anim_name: String):
	if anim_name == "open":
		_on_open_animation_finished()

#
# 生成护身符碎片
#
func _on_open_animation_finished():
	if fragment_scene:
		var fragment = fragment_scene.instantiate() as Node3D
		add_child(fragment)
		fragment.set("shard_index", fragment_index)
		fragment.global_transform = global_transform.translated(Vector3(0, 3, 0))

#
# 当有人调用 QuestManager.emit_signal("quest_completed", ...) 时触发
#
func _on_quest_completed():
	if spawn_condition_mode == 1:
		visible = true
		area.monitoring = true
