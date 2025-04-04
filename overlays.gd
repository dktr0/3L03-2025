extends Control

func _ready() -> void:
	hideEnergy();

func setEnergy(x): # x can be 0, 1, 2, 3, 4
	$AllBars.visible = true;
	$AllBars.setEnergy(x);
	
func hideEnergy():
	$AllBars.visible = false;
