extends CanvasLayer

var dialogue = [
	{'name': 'Fisherman', 'text': 'Hello there, traveler! I dont think we have seen each other in ages.'},
	{'name': 'Player', 'text': 'Oh, yeah! The Fisherman! Why are you still here?'},
	{'name': 'Fisherman', 'text': 'Because you saved the world,  Ive been waiting here for you. Go see the new world now! Want to go fishing later?'},
	{'name': 'Player', 'text': 'I will be back for your fishing trip.'}
]

var current_dialogue_id = 0
var d_active = false

func _ready() -> void:
	$NinePatchRect.visible = false

func start():
	if d_active:
		return
	d_active = true
	$NinePatchRect.visible = true
	
	current_dialogue_id = -1
	next_script()

func _input(event):
	if not d_active:
		return
	if event.is_action_pressed("ui_accept"):
		next_script()

func next_script():
	current_dialogue_id += 1
	
	if current_dialogue_id >= len(dialogue):
		$Timer.start()
		$NinePatchRect.visible = false
		return
	
	$NinePatchRect/Name.text = dialogue[current_dialogue_id]['name']
	$NinePatchRect/Chat.text = dialogue[current_dialogue_id]['text']

func _on_timer_timeout() -> void:
	d_active = false
