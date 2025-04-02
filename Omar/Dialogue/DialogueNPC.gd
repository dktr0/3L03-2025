extends CanvasLayer

@export_file ("*.json") var d_file

func _ready() -> void:
	start()
#func start():
#	dialogue = load_dialogue()
#	$NinePatchRect/Name.text = dialogue[0]['name']
#	$NinePatchRect/Chat.text = dialogue[0]['text']

func load_dialogue():
	var file = FileAccess.open ("res://Omar/Dialogue/json/", FileAccess.READ)
	var content = JSON.parse_string(file.get_as_text())
	return content

var dialogue = []

#func load_dialogue():
#	if d_file.is_empty():
#		print ("error: no file selected")
#		return []

func start():
	dialogue = load_dialogue()
	print("Loaded dialogue:", dialogue)  # Debugging output

	if dialogue.size() > 0:
		$NinePatchRect/Name.text = dialogue[0]['name']
		$NinePatchRect/Chat.text = dialogue[0]['text']
	else:
		print("Error: Dialogue file is empty or not formatted correctly.")
