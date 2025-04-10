extends Node3D

func _process(_delta):
	if Input.is_action_just_pressed("toggle_fullscreen"):
		var m = get_window().mode;
		if m == Window.MODE_WINDOWED:
			get_window().mode = Window.MODE_FULLSCREEN;
		else:
			get_window().mode = Window.MODE_WINDOWED;
			
func _physics_process(_delta):
	if Input.is_action_just_pressed("jump_to_beginning"):
		get_tree().change_scene_to_file("res://Yunhan Liu2/beginning.tscn");
	if Input.is_action_just_pressed("jump_to_present"):
		get_tree().change_scene_to_file("res://Omar/present.tscn");
	if Input.is_action_just_pressed("jump_to_past"):
		get_tree().change_scene_to_file("res://Sandhya/past.tscn");
	if Input.is_action_just_pressed("jump_to_good_ending"):
		get_tree().change_scene_to_file("res://Yunhan Liu2/good.tscn");
	if Input.is_action_just_pressed("jump_to_bad_ending"):
		get_tree().change_scene_to_file("res://Yunhan Liu2/bad.tscn");
	if Input.is_action_just_pressed("teleport_up"):
		print("finding player for teleport...");
		var player = $"/root".find_child("Player");
		if player != null:
			print("teleporting up 10 metres");
			player.set_global_position(player.get_global_position() + Vector3(0,10,0));
		else:
			print("couldn't find player node for teleporting!");
