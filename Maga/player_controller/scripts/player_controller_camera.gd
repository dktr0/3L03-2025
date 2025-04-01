extends Camera3D

@export var follow_speed := 5.0
@export var rotation_speed := 2.0
@export var min_distance := 2.0
@export var max_distance := 8.0
@export var desired_distance := 6.0
@export var desired_height := 2.0
@export var targeting_height := 1.5
@export var targeting_distance := 4.0
@export var targeting_lerp_speed := 8.0
@export var collision_mask := 1  # Layer for camera collision
@export var target_path: NodePath

var target: Node3D
var camera_pitch := 0.0
var camera_yaw := 0.0
var current_distance := desired_distance
var right_stick_deadzone := 0.1
var targeting_mode := false
var current_target: Node3D = null

func _ready():
    if target_path:
        target = get_node(target_path)

func _process(delta):
    if target == null:
        return

    if targeting_mode and current_target:
        process_targeting_camera(delta)
    else:
        process_free_camera(delta)

func process_free_camera(delta):
    # Get right stick input for camera rotation
    var right_x = Input.get_action_strength("camera_right") - Input.get_action_strength("camera_left")
    var right_y = Input.get_action_strength("camera_down") - Input.get_action_strength("camera_up")
    
    # Apply deadzone
    if abs(right_x) < right_stick_deadzone:
        right_x = 0
    if abs(right_y) < right_stick_deadzone:
        right_y = 0
        
    # Rotate camera
    camera_yaw -= right_x * rotation_speed * delta
    camera_pitch -= right_y * rotation_speed * delta
    
    # Clamp pitch to prevent camera flipping
    camera_pitch = clamp(camera_pitch, -PI/4, PI/3)
    
    # Calculate camera position
    var cam_rot = Basis()
    cam_rot = cam_rot.rotated(Vector3.UP, camera_yaw)
    cam_rot = cam_rot.rotated(cam_rot.x, camera_pitch)
    
    var target_pos = target.global_transform.origin + Vector3.UP * desired_height
    var cam_dir = -cam_rot.z.normalized()
    
    # Check for collisions
    var space_state = get_world_3d().direct_space_state
    var ray_params = PhysicsRayQueryParameters3D.new()
    ray_params.from = target_pos
    ray_params.to = target_pos + cam_dir * desired_distance
    ray_params.collision_mask = collision_mask
    ray_params.exclude = [target]
    
    var collision = space_state.intersect_ray(ray_params)
    if collision:
        current_distance = min(collision.position.distance_to(target_pos), desired_distance)
    else:
        current_distance = lerp(current_distance, desired_distance, delta * follow_speed)
    
    current_distance = clamp(current_distance, min_distance, max_distance)
    
    # Set camera position and orientation
    global_transform.origin = target_pos + cam_dir * current_distance
    look_at(target_pos, Vector3.UP)

func process_targeting_camera(delta):
    if !is_instance_valid(current_target) or !current_target.is_inside_tree():
        set_targeting_mode(false, null)
        return

    # Calculate midpoint between player and target
    var player_pos = target.global_position
    var target_pos = current_target.global_position
    var midpoint = (player_pos + target_pos) * 0.5
    
    # Adjust midpoint height
    midpoint.y += targeting_height
    
    # Calculate direction from target to player
    var direction = (player_pos - target_pos).normalized()
    direction.y = 0
    direction = direction.normalized()
    
    # Position camera behind the player
    var cam_pos = midpoint + direction * targeting_distance
    
    # Check for collision
    var space_state = get_world_3d().direct_space_state
    var ray_params = PhysicsRayQueryParameters3D.new()
    ray_params.from = midpoint
    ray_params.to = cam_pos
    ray_params.collision_mask = collision_mask
    ray_params.exclude = [target]
    
    var collision = space_state.intersect_ray(ray_params)
    if collision:
        cam_pos = collision.position + collision.normal * 0.2
    
    # Smoothly move to targeting camera position
    global_transform.origin = global_transform.origin.lerp(cam_pos, delta * targeting_lerp_speed)
    
    # Look at midpoint
    look_at(midpoint, Vector3.UP)

# Called by the core when targeting is engaged/disengaged
func set_targeting_mode(is_targeting: bool, target_node: Node3D):
    targeting_mode = is_targeting
    current_target = target_node
    
    if !targeting_mode:
        # When exiting targeting mode, try to preserve camera orientation
        var current_basis = global_transform.basis
        var forward = -current_basis.z
        forward.y = 0
        forward = forward.normalized()
        
        # Calculate yaw from forward vector
        camera_yaw = atan2(forward.x, forward.z)
