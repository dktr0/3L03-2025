extends CharacterBody3D


var mouseLookLeftRight = 0
var mouseLookUpDown = 0

const SPEED = 2.5
const SWIM_SPEED = 2.5
const ACCEL = 10.0
const DECEL = 10.0

const GRAVITY = -4.0     
const BUOYANCY = 3.0     
const DRAG = 0.1         
const MOVE_SPEED = 2.5   
const JUMP_FORCE = 4.0     
const MAX_RISE_SPEED = 2.5


func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED);


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if Input.is_action_just_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED);
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE);


func _physics_process(delta):
	var stickLook = Input.get_vector("lookleft","lookright","lookup","lookdown")*(-0.1);
	rotate_y(mouseLookLeftRight + stickLook.x);
	$Camera3D.rotate_x(mouseLookUpDown + stickLook.y);
	$Camera3D.rotation.x = clampf($Camera3D.rotation.x, -deg_to_rad(30), deg_to_rad(5));
	mouseLookLeftRight = 0;
	mouseLookUpDown = 0;

	velocity.y += (GRAVITY + BUOYANCY) * delta
	velocity.y = clamp(velocity.y, -MAX_RISE_SPEED, MAX_RISE_SPEED)

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

	if Input.is_action_just_pressed("Jump"):
		velocity.y = JUMP_FORCE

	velocity = velocity.lerp(Vector3.ZERO, DRAG * delta)

	move_and_slide()


func _input(event):
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		mouseLookLeftRight = -event.relative.x * 0.01; # increase/decrease 0.01 to change sensitivity
		if abs(mouseLookLeftRight) < 0.02: # dead zone for mouse motion left/right
			mouseLookLeftRight = 0.0;
		mouseLookUpDown = -event.relative.y * 0.01; # increase/decrease 0.01 to change sensitivity
		if abs(mouseLookUpDown) < 0.02: # dead zone for mouse motion up/down
			mouseLookUpDown = 0.0;
