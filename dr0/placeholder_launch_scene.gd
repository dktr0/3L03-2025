extends Control

func _on_button_pressed():
	get_tree().change_scene_to_file("res://Yunhan Liu2/beginning.tscn")
		
func _on_button_2_pressed():
	get_tree().change_scene_to_file("res://Omar/present.tscn")

func _on_button_3_pressed():
	get_tree().change_scene_to_file("res://Sandhya/past.tscn")

func _on_button_4_pressed():
	get_tree().change_scene_to_file("res://Yunhan Liu2/good.tscn")

func _on_button_5_pressed():
	get_tree().change_scene_to_file("res://Yunhan Liu2/bad.tscn")
