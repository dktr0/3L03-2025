extends Node3D

func playRandom():
	var c = randi() % get_child_count()
	get_child(c).play()
