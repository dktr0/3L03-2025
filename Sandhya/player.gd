extends CharacterBody3D

var score = 0;
#the number of jumps
var jump_count = 0
var max_jumps = 2

const SPEED = 23.0
const JUMP_VELOCITY = 16.5
const ACCEL = 10.0
const DECEL = 15.0

var mouseLookLeftRight = 0;
var mouseLookUpDown = 0;

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _physics_process(delta):
	var stickLook = Input.get_vector("Lookleft","Lookright","Lookup","Lookdown")*(-0.1);
	rotate_y(mouseLookLeftRight + stickLook.x);
	$Camera3D.rotate_x(mouseLookUpDown + stickLook.y);
	$Camera3D.rotation.x = clampf($Camera3D.rotation.x, -deg_to_rad(70), deg_to_rad(70))
	mouseLookLeftRight = 0;
	mouseLookUpDown = 0;
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
		
	if is_on_floor(): 
		jump_count = 0
	# Handle jump.
	if Input.is_action_just_pressed("Jump") and jump_count < max_jumps: # jumping
		velocity.y = JUMP_VELOCITY
		jump_count += 1

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir = Input.get_vector("Left", "Right", "Forward", "Backward")
	var dir = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized();
	
	var rawVelocity = dir * SPEED;
	velocity = Vector3(rawVelocity.x,velocity.y,rawVelocity.z);
	
	#if dir:
	#	velocity.x = move_toward(velocity.x, dir.x*SPEED, abs(dir.x*ACCEL*delta));
	#	velocity.z = move_toward(velocity.z, dir.z*SPEED, abs(dir.z*ACCEL*delta));
	#else:
		#var velDir = velocity.normalized();
		#velocity.x = move_toward(velocity.x, 0, abs(velDir.x*DECEL*delta));
		#velocity.z = move_toward(velocity.z, 0, abs(velDir.z*DECEL*delta));

	move_and_slide()
	
func _input(event):
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		mouseLookLeftRight = -event.relative.x * 0.01; # increase/decrease 0.01 to change sensitivity
		if abs(mouseLookLeftRight) < 0.01: # dead zone for mouse motion left/right
			mouseLookLeftRight = 0.0;
		mouseLookUpDown = -event.relative.y * 0.01; # increase/decrease 0.01 to change sensitivity
		if abs(mouseLookUpDown) < 0.01: # dead zone for mouse motion up/down
			mouseLookUpDown = 0.0;
	
func _on_area_3d_body_entered(body):
	pass # not doing anything here yet...

	
func _on_area_3d_area_entered(area: Area3D) -> void:
	if(area.is_in_group("Collectable")):
		score = score + 1;
		print("hit collectable, new score = " + str(score));
		area.queue_free();
