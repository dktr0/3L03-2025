extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.
	setAmulet("1");

func setAmulet(x): # x can be "1" "2" "3" "4" "2_3" "2_4" "3_4"
	if x == "1": # final amulet (1=2+3+4)
		$Amulet1.visible = true;
		$Amulet2.visible = false;
		$Amulet3.visible = false;
		$Amulet4.visible = false;
		$Amulet23.visible = false;
		$Amulet24.visible = false;
		$Amulet34.visible = false;
	elif x == "2": # gem
		$Amulet1.visible = false;
		$Amulet2.visible = true;
		$Amulet3.visible = false;
		$Amulet4.visible = false;
		$Amulet23.visible = false;
		$Amulet24.visible = false;
		$Amulet34.visible = false;
	elif x == "3": # right ring
		$Amulet1.visible = false;
		$Amulet2.visible = false;
		$Amulet3.visible = true;
		$Amulet4.visible = false;
		$Amulet23.visible = false;
		$Amulet24.visible = false;
		$Amulet34.visible = false;
	elif x == "4": # left ring
		$Amulet1.visible = false;
		$Amulet2.visible = false;
		$Amulet3.visible = false;
		$Amulet4.visible = true;
		$Amulet23.visible = false;
		$Amulet24.visible = false;
		$Amulet34.visible = false;
	elif x == "2_3":# gem + right ring
		$Amulet1.visible = false;
		$Amulet2.visible = false;
		$Amulet3.visible = false;
		$Amulet4.visible = false;
		$Amulet23.visible = true;
		$Amulet24.visible = false;
		$Amulet34.visible = false;
	elif x == "2_4":# gem + left ring
		$Amulet1.visible = false;
		$Amulet2.visible = false;
		$Amulet3.visible = false;
		$Amulet4.visible = false;
		$Amulet23.visible = false;
		$Amulet24.visible = true;
		$Amulet34.visible = false;
	elif x == "3_4": # left + right rings
		$Amulet1.visible = false;
		$Amulet2.visible = false;
		$Amulet3.visible = false;
		$Amulet4.visible = false;
		$Amulet23.visible = false;
		$Amulet24.visible = false;
		$Amulet34.visible = true;
