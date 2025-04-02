extends Node3D

@onready var popupScene = preload("res://dr0/popup.tscn");

func popup(t : String, cb : Callable = Callable()):
	var popup = popupScene.instantiate();
	popup.setup(t,cb);
	add_child(popup);

func _ready():
	popup("This is some awesome text that I want to share with the player.",Callable(self,"followup1"));
	
func followup1():
	print("here's the followup")
