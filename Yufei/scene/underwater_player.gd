extends CharacterBody3D

const GRAVITY = -4.0     
const BUOYANCY = 3.0     
const DRAG = 0.1         
const MOVE_SPEED = 2.5   
const JUMP_FORCE = 4.0     
const MAX_RISE_SPEED = 2.5

func _physics_process(delta):
	
	velocity.y += (GRAVITY + BUOYANCY) * delta
	velocity.y = clamp(velocity.y, -MAX_RISE_SPEED, MAX_RISE_SPEED)
	
	if Input.is_action_just_pressed("ui_accept"):
		velocity.y = JUMP_FORCE
	
	var input_dir = Input.get_vector("Back","Front", "Left", "Right")
	var movement = Vector3(input_dir.x, 0, input_dir.y) * MOVE_SPEED
	
	
	velocity = velocity.lerp(Vector3.ZERO, DRAG * delta)
	
	
	velocity += movement * delta
	


	move_and_slide()
