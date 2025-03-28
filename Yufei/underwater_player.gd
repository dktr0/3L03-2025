extends CharacterBody3D

const SPEED = 5.0
const ACCEL = 4.0
const DECEL = 5.0
const GRAVITY = -5.0     
const BUOYANCY = 3.0     
const DRAG = 0.1         
const MOVE_SPEED = 3   
const JUMP_FORCE = 10.0     
const MAX_RISE_SPEED = 2.5
var score = 0
var total_Collectable = 6

var mouseLookLeftRight = 0;
var mouseLookUpDown = 0;
var is_paused = false


func _ready():
	
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta):
	velocity.y += (GRAVITY + BUOYANCY) * delta
	velocity.y = clamp(velocity.y, -MAX_RISE_SPEED, MAX_RISE_SPEED)


	if Input.is_action_just_pressed("ui_accept"):
		velocity.y = JUMP_FORCE

		
	var stickLook = Input.get_vector("lookleft","lookright","lookup","lookdown")*(-0.1);
	rotate_y(mouseLookLeftRight + stickLook.x);
	$Camera3D.rotate_x(mouseLookUpDown + stickLook.y);
	$Camera3D.rotation.x = clampf($Camera3D.rotation.x, -deg_to_rad(70), deg_to_rad(70))
	mouseLookLeftRight = 0;
	mouseLookUpDown = 0;
	



	var input_dir = Input.get_vector("left", "right", "forward", "back")
	var dir = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized();
	if dir:
		velocity.x = move_toward(velocity.x, dir.x*SPEED, abs(dir.x*ACCEL*delta));
		velocity.z = move_toward(velocity.z, dir.z*SPEED, abs(dir.z*ACCEL*delta));
	else:
		var velDir = velocity.normalized();
		velocity.x = move_toward(velocity.x, 0, abs(velDir.x*DECEL*delta));
		velocity.z = move_toward(velocity.z, 0, abs(velDir.z*DECEL*delta));

	move_and_slide()
	
func _input(event):
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		mouseLookLeftRight = -event.relative.x * 0.01; 
		if abs(mouseLookLeftRight) < 0.02: 
			mouseLookLeftRight = 0.0;
		mouseLookUpDown = -event.relative.y * 0.01; 
		if abs(mouseLookUpDown) < 0.02: 
			mouseLookUpDown = 0.0;
			
func _on_area_3d_area_shape_entered(area_rid: RID, area: Area3D, area_shape_index: int, local_shape_index: int) -> void:
	if area.is_in_group("collectable"):
		score += 1;
		total_Collectable -= 1
		area.queue_free()
		print("collectable inventory = " + str(score));
		print("rest of collectables = " + str(total_Collectable));
	
	if score == 6 && total_Collectable == 0:
		print("Congrats! you have collected all collectables")
