extends Node3D



@export var player_path: NodePath
@export var mouse_sensitivity: float = 0.2


@export var pitch_min: float = -80.0
@export var pitch_max: float = 20.0

@export var follow_height_offset: float = 2.0
@export var follow_lerp_speed: float = 5.0

@export var collision_margin: float = 0.3
@export var min_camera_distance: float = 1.0
@export var partial_clamp_front: float = 0.5


@export var default_camera_distance: float = 4.0
@export var sprint_camera_distance: float  = 6.0
@export var aim_camera_distance: float     = 3.0

@export var default_fov: float = 70.0
@export var sprint_fov: float  = 85.0
@export var aim_fov: float     = 60.0


@export var keep_player_back_to_camera: bool = false


var yaw: float = 0.0
var pitch: float = 0.0
var original_cam_offset: Vector3 = Vector3.ZERO

var current_camera_distance: float = 0.0
var current_fov: float = 0.0

func _ready():
	var pivot = $Pivot
	var cam = pivot.get_node("Camera3D") as Camera3D
	

	original_cam_offset = cam.position


	current_camera_distance = default_camera_distance
	current_fov = default_fov

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _input(event):
	if event is InputEventMouseMotion:
		yaw   -= event.relative.x * mouse_sensitivity
		pitch -= event.relative.y * mouse_sensitivity
		pitch = clamp(pitch, pitch_min, pitch_max)


func _process(delta: float):

	var player = get_node_or_null(player_path) as Node3D
	if player:
		var now_pos = global_transform.origin
		var tgt_pos = player.global_transform.origin
		tgt_pos.y   += follow_height_offset
		global_transform.origin = now_pos.lerp(tgt_pos, follow_lerp_speed * delta)


	rotation_degrees = Vector3(0, yaw, 0)
	$Pivot.rotation_degrees.x = pitch


	if keep_player_back_to_camera and player:
		_sync_player_orientation_with_camera(player)


	var desired_dist = default_camera_distance
	var desired_fov  = default_fov


	if player and player.has_method("is_sprinting") and player.call("is_sprinting"):
		desired_dist = sprint_camera_distance
		desired_fov  = sprint_fov
	elif player and player.has_method("is_aiming") and player.call("is_aiming"):
		desired_dist = aim_camera_distance
		desired_fov  = aim_fov


	current_camera_distance = lerp(current_camera_distance, desired_dist, 5.0 * delta)
	current_fov = lerp(current_fov, desired_fov, 5.0 * delta)


	var offset_dir = original_cam_offset.normalized()
	var ideal_local_off = offset_dir * current_camera_distance

	_update_camera_offset(ideal_local_off)


func _update_camera_offset(ideal_local_off: Vector3):
	var pivot = $Pivot
	var cam   = pivot.get_node("Camera3D")

	
	cam.position = ideal_local_off

	
	var from_global = pivot.global_transform.origin
	var to_global   = from_global + pivot.global_transform.basis * ideal_local_off

	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.new()
	query.from = from_global
	query.to   = to_global
	query.collide_with_bodies = true
	query.collide_with_areas  = false
	query.collision_mask = 0xffffffff  

	var res = space_state.intersect_ray(query)
	if res.has("position"):
		var collision_pos = res["position"]
		var dist = from_global.distance_to(collision_pos) - collision_margin
		if dist < 0:
			dist = 0

		var is_back = _is_camera_behind_player()
		var ideal_len = ideal_local_off.length()

		if is_back:
			dist = clamp(dist, min_camera_distance, ideal_len)
		else:
			var partial_min = ideal_len * partial_clamp_front
			if partial_min < min_camera_distance:
				partial_min = min_camera_distance
			dist = clamp(dist, partial_min, ideal_len)

		var offset_dir = ideal_local_off.normalized()
		var new_local_off = offset_dir * dist
		cam.position = new_local_off
	else:
		cam.position = ideal_local_off

	
	cam.fov = current_fov


func _is_camera_behind_player() -> bool:
	var player = get_node_or_null(player_path) as Node3D
	if not player:
		return true


	var angle_cam  = fposmod(yaw, 360.0)
	var angle_char = fposmod(player.rotation_degrees.y, 360.0)
	var angle_diff = abs(angle_cam - angle_char)
	angle_diff = fposmod(angle_diff, 360.0)


	return (angle_diff < 90.0 or angle_diff > 270.0)


func _sync_player_orientation_with_camera(player: Node3D) -> void:

	player.rotation_degrees = Vector3(
		player.rotation_degrees.x,
		fposmod(yaw + 180.0, 360.0),
		player.rotation_degrees.z
	)
