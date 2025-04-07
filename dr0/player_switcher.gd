extends Area3D

func _on_body_entered(body):
	if body.is_in_group("player"):
		switchToSwimming();

func _on_body_exited(body):
	if body.is_in_group("player"):
		switchToWalking();

func switchToSwimming():
	print("now swimming");
	
func switchToWalking():
	print("now walking");
	
