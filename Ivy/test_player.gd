extends CharacterBody3D


var mouseLookLeftRight = 0
var mouseLookUpDown = 0
var max_jumps: int = 2
var jumps_left: int = max_jumps


const SPEED = 2.5
const JUMP_VELOCITY = 6
const ACCEL = 10.0
const DECEL = 10.0
const DEATH_Y = -10


func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED);


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if Input.is_action_just_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED);
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE);

	if global_transform.origin.y < DEATH_Y:
		get_tree().reload_current_scene();


func _physics_process(delta):
	var stickLook = Input.get_vector("lookleft","lookright","lookup","lookdown")*(-0.1);
	rotate_y(mouseLookLeftRight + stickLook.x);
	$Camera3D.rotate_x(mouseLookUpDown + stickLook.y);
	$Camera3D.rotation.x = clampf($Camera3D.rotation.x, -deg_to_rad(30), deg_to_rad(5));
	mouseLookLeftRight = 0;
	mouseLookUpDown = 0;
	
	if not is_on_floor(): # gravity
		velocity += get_gravity() * delta;

	if is_on_floor():
		jumps_left = max_jumps

	if Input.is_action_just_pressed("Jump") and jumps_left > 0: # jumping
		velocity.y = JUMP_VELOCITY;
		jumps_left -= 1

	var input_dir = Input.get_vector("left", "right", "forward", "back");
	var dir = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized();
	# handling 4 different possibilities:
	# these can easily be tweaked to the requirements of specific games
	if dir: # if player is pressing a direction control...
		velocity.x = move_toward(velocity.x, dir.x*SPEED, abs(dir.x*ACCEL*delta));
		velocity.z = move_toward(velocity.z, dir.z*SPEED, abs(dir.z*ACCEL*delta));
	else:
		var velDir = velocity.normalized();
		velocity.x = move_toward(velocity.x, 0, abs(velDir.x*DECEL*delta));
		velocity.z = move_toward(velocity.z, 0, abs(velDir.z*DECEL*delta));

	move_and_slide()


func _input(event):
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		mouseLookLeftRight = -event.relative.x * 0.01; # increase/decrease 0.01 to change sensitivity
		if abs(mouseLookLeftRight) < 0.02: # dead zone for mouse motion left/right
			mouseLookLeftRight = 0.0;
		mouseLookUpDown = -event.relative.y * 0.01; # increase/decrease 0.01 to change sensitivity
		if abs(mouseLookUpDown) < 0.02: # dead zone for mouse motion up/down
			mouseLookUpDown = 0.0;
