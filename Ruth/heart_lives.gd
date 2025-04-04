extends Control


# Called when the node enters the scene tree for the first time.


func _ready() -> void:
	setHealth(1);

func setHealth(x): # x can be 0, 0.5, 1
	if x == 0:
		$EmptyHeart.visible = true;
		$Heart.visible = false;
		$HalfHeart.visible = false;
		
	elif x == 0.5:
		$EmptyHeart.visible = false;
		$Heart.visible = false;
		$HalfHeart.visible = true;
		
	elif x == 1:
		$EmptyHeart.visible = false;
		$Heart.visible = true;
		$HalfHeart.visible = false;
		
