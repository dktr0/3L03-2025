extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	setEnergy(4);

func setEnergy(x): # x can be 0, 1, 2, 3, 4
	if x == 0:
		$Bar1.visible = false;
		$Bar2.visible = false;
		$Bar3.visible = false;
		$Bar4.visible = true;
		$Bars.visible = false;
		
	elif x == 1:
		$Bar1.visible = false;
		$Bar2.visible = false;
		$Bar3.visible = true;
		$Bar4.visible = false;
		$Bars.visible = false;
	  
	elif x == 2:
		$Bar1.visible = false;
		$Bar2.visible = true;
		$Bar3.visible = true;
		$Bar4.visible = false;
		$Bars.visible = false;

	elif x == 3:
		$Bar1.visible = true;
		$Bar2.visible = false;
		$Bar3.visible = false;
		$Bar4.visible = false;
		$Bars.visible = false;
	else:
		$Bar1.visible = false;
		$Bar2.visible = false;
		$Bar3.visible = false;
		$Bar4.visible = false;
		$Bars.visible = true;

	
	
		
