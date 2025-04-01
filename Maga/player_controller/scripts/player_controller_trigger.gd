# .----------------------------------------------------------------------------.
# |:::    :::     :::     :::        ::::::::  :::   :::  ::::::::  ::::    :::|
# |:+:    :+:   :+: :+:   :+:       :+:    :+: :+:   :+: :+:    :+: :+:+:   :+:|
# |+:+    +:+  +:+   +:+  +:+       +:+         +:+ +:+  +:+    +:+ :+:+:+  +:+|
# |+#++:++#++ +#++:++#++: +#+       +#+          +#++:   +#+    +:+ +#+ +:+ +#+|
# |+#+    +#+ +#+     +#+ +#+       +#+           +#+    +#+    +#+ +#+  +#+#+#|
# |#+#    #+# #+#     #+# #+#       #+#    #+#    #+#    #+#    #+# #+#   #+#+#|
# |###    ### ###     ### ########## ########     ###     ########  ###    ####|
# '----------------------------------------------------------------------------'
# Player Controller Spawner (Modified for Initial Spawn)
#
# Spawns the player character in _ready() if no player exists in the "player" group.
# Can optionally still spawn if a body enters the trigger later (if spawn_on_enter is true).
# Attach this script to the root node of player_trigger.tscn.
#
# Developed by:
# - Liam Maga
# - Gemini
# .----------------------------------------------------------------------------.

extends Node3D

## The player scene to instance.
@export var player_scene: PackedScene
## If true, also spawn player if a body enters the trigger (after initial check).
@export var spawn_on_enter := false 

## Reference to the trigger area.
@onready var area_3d: Area3D = $Area3D # Assumes child node is named "Area3D"

var has_spawned := false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# --- Check for existing player first ---
	var existing_players = get_tree().get_nodes_in_group("player")
	if existing_players.size() > 0:
		print("Spawner: Player already exists in the scene. Skipping initial spawn.")
		has_spawned = true # Prevent future spawns if player already exists
	else:
		# No player found, attempt initial spawn
		spawn_player()
	# -------------------------------------
	
	# --- Setup Trigger Area (Optional) ---
	if !area_3d:
		printerr("Spawner Error: Cannot find child Area3D node named 'Area3D'.")
	else:
		if spawn_on_enter:
			# Only connect if spawn_on_enter is true
			area_3d.body_entered.connect(_on_body_entered)
		else:
			# Disable area if not needed for enter spawns
			area_3d.monitoring = false
			area_3d.monitorable = false
	# -------------------------------------

# Called when a body enters the Area3D (only if spawn_on_enter is true).
func _on_body_entered(body: Node3D) -> void:
	print("Body entered trigger: ", body.name)
	# Check if the entering body is the player itself (or could be)
	# You might want more specific checks here (e.g., if body.is_in_group("player"))
	spawn_player()

# Central spawning function
func spawn_player() -> void:
	# Only spawn if we haven't already and a valid player scene is set
	if has_spawned or player_scene == null:
		if player_scene == null:
			printerr("Spawner Error: player_scene is not assigned in the Inspector.")
		return
		
	# Prevent future spawns
	has_spawned = true
	
	print("Spawning Player...")
	
	# Instance the player scene
	var player_instance = player_scene.instantiate()
	
	# Ensure the instance is a Node3D for positioning
	if !(player_instance is Node3D):
		printerr("Spawner Error: player_scene did not instantiate a Node3D.")
		# Reset flag if spawn failed?
		# has_spawned = false 
		return
		
	# Position the player at the spawner's location
	player_instance.global_position = self.global_position
	
	# Add the player to the scene tree (as a sibling to this spawner node)
	# Ensure this node is added to the main scene tree before calling this
	if get_parent():
		get_parent().add_child(player_instance)
		print("Player spawned at: ", player_instance.global_position)
		
		# Disable the trigger area after spawning if needed
		if area_3d and !spawn_on_enter:
			area_3d.monitoring = false
			area_3d.monitorable = false
	else:
		printerr("Spawner Error: Spawner node has no parent. Cannot add player instance.")
		# Reset flag if spawn failed?
		# has_spawned = false 


# Called every frame. 'delta' is the elapsed time since the previous frame.
# func _process(delta: float) -> void:
# 	pass
