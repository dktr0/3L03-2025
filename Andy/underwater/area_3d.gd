extends Area3D

var player_in_range = false
var original_min_distance = 0.0
var original_max_distance = 0.0
var original_desired_distance = 0.0
var is_first_person = false

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
	if body.name == "Player":
		player_in_range = true

func _on_body_exited(body: Node) -> void:
	if body.name == "Player":
		player_in_range = false

func _process(delta: float) -> void:
	
	if player_in_range and Input.is_action_just_pressed("activate"):
		if is_first_person:
			switch_to_third_person()
		else:
			switch_to_first_person()

func switch_to_first_person():
	
	print("Helmet's current path is: ", get_path())
	var camera = get_node("../Player/CameraRoot/Camera3D") 
	if camera == null:
		push_warning("Camera node not found via relative path!")
		return

	
	original_min_distance = camera.min_distance
	original_max_distance = camera.max_distance
	original_desired_distance = camera.desired_distance

	
	camera.min_distance = 0.0
	camera.max_distance = 0.0
	camera.desired_distance = 0.0

	is_first_person = true
	print("Switched to 1st-person!")

func switch_to_third_person():
	var camera = get_node("../Player/CameraRoot/Camera3D")
	if camera == null:
		return

	
	camera.min_distance = original_min_distance
	camera.max_distance = original_max_distance
	camera.desired_distance = original_desired_distance

	is_first_person = false
	print("Switched back to 3rd-person!")
