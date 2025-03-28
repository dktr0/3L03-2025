extends Control

func _on_button_pressed():
	get_tree().change_scene_to_file("res://Yunhan Liu2/future.tscn")
		
func _on_button_2_pressed():
	get_tree().change_scene_to_file("res://Omar/present.tscn")

func _on_button_3_pressed():
	get_tree().change_scene_to_file("res://Sandhya/past.tscn")
