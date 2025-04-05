extends Control

# to use:
# [this].setEnergy(0 or 1 or 2 or 3 or 4) # make it visible with that level of health/energy
# [this].hideEnergy() # hide the health/energy UI completely
# [this].setAmulet(true,false,true) # 
# [this].hideAmulet() # hide the amulet UI completely

@onready var energy = $AllBars;
@onready var amulet = $"Final Amulet";

func _ready() -> void:
	hideEnergy();
	hideAmulet();
	
func setEnergy(x): # x can be 0, 1, 2, 3, 4
	energy.visible = true;
	energy.setEnergy(x);
	
func hideEnergy():
	energy.visible = false;
	
func setAmulet(x=false,y=false,z=false): # x y z are true or false
	if x && y && z:
		amulet.visible = true; amulet.setAmulet("1");
	elif x && !y && !z:
		amulet.visible = true; amulet.setAmulet("2");
	elif !x && y && !z:
		amulet.visible = true; amulet.setAmulet("3");
	elif !x && !y && z:
		amulet.visible = true; amulet.setAmulet("4");
	elif x && !y && z:
		amulet.visible = true; amulet.setAmulet("2_4");
	elif x && y && !z:
		amulet.visible = true; amulet.setAmulet("2_3");
	elif !x && y && z:
		amulet.visible = true; amulet.setAmulet("3_4");
	else:
		amulet.visible = false;
		amulet.setAmulet("1")
		
func hideAmulet():
	amulet.visible = false;
