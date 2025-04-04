extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	setOxygen(8);

func setOxygen(x): # x can be 0, 1,
	if x == 0:
		$Oxygen0.visible = true;
		$Oxygen1.visible = false;
		$Oxygen2.visible = false;
		$Oxygen3.visible = false;
		$Oxygen4.visible = false;
		$Oxygen5.visible = false;
		$Oxygen6.visible = false;
		$Oxygen7.visible = false;
		$OxygenFull.visible = false;
		
	elif x == 1:
		$Oxygen0.visible = false;
		$Oxygen1.visible = false;
		$Oxygen2.visible = false;
		$Oxygen3.visible = false;
		$Oxygen4.visible = false;
		$Oxygen5.visible = false;
		$Oxygen6.visible = false;
		$Oxygen7.visible = true;
		$OxygenFull.visible = false;

	elif x == 2:
		$Oxygen0.visible = false;
		$Oxygen1.visible = false;
		$Oxygen2.visible = false;
		$Oxygen3.visible = false;
		$Oxygen4.visible = false;
		$Oxygen5.visible = false;
		$Oxygen6.visible = true;
		$Oxygen7.visible = false;
		$OxygenFull.visible = false;
		
	elif x == 3:
		$Oxygen0.visible = false;
		$Oxygen1.visible = false;
		$Oxygen2.visible = false;
		$Oxygen3.visible = false;
		$Oxygen4.visible = false;
		$Oxygen5.visible = true;
		$Oxygen6.visible = false;
		$Oxygen7.visible = false;
		$OxygenFull.visible = false;
		
	elif x == 4:
		$Oxygen0.visible = false;
		$Oxygen1.visible = false;
		$Oxygen2.visible = false;
		$Oxygen3.visible = false;
		$Oxygen4.visible = true;
		$Oxygen5.visible = false;
		$Oxygen6.visible = false;
		$Oxygen7.visible = false;
		$OxygenFull.visible = false;
		
	elif x == 5:
		$Oxygen0.visible = false;
		$Oxygen1.visible = false;
		$Oxygen2.visible = false;
		$Oxygen3.visible = true;
		$Oxygen4.visible = false;
		$Oxygen5.visible = false;
		$Oxygen6.visible = false;
		$Oxygen7.visible = false;
		$OxygenFull.visible = false;

		
	elif x == 6:
		$Oxygen0.visible = false;
		$Oxygen1.visible = false;
		$Oxygen2.visible = true;
		$Oxygen3.visible = false;
		$Oxygen4.visible = false;
		$Oxygen5.visible = false;
		$Oxygen6.visible = false;
		$Oxygen7.visible = false;
		$OxygenFull.visible = false;
		
	elif x == 7:
		$Oxygen0.visible = false;
		$Oxygen1.visible = true;
		$Oxygen2.visible = false;
		$Oxygen3.visible = false;
		$Oxygen4.visible = false;
		$Oxygen5.visible = false;
		$Oxygen6.visible = false;
		$Oxygen7.visible = false;
		$OxygenFull.visible = false;

	elif x == 8:
		$Oxygen0.visible = false;
		$Oxygen1.visible = false;
		$Oxygen2.visible = false;
		$Oxygen3.visible = false;
		$Oxygen4.visible = false;
		$Oxygen5.visible = false;
		$Oxygen6.visible = false;
		$Oxygen7.visible = false;
		$OxygenFull.visible = true;
