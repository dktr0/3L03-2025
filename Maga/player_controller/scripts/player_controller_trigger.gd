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
# - 
# - 
# .----------------------------------------------------------------------------.

extends Node3D

## The player scene (.tscn file) to instance when spawning.
@export var player_scene: PackedScene 
## If true, spawn the player if a body enters the trigger area (in addition to the initial spawn check).
@export var spawn_on_enter := false 

## Reference to the trigger area child node.
@onready var area_3d: Area3D = $Area3D # Assumes child node is named "Area3D"

var has_spawned := false # Flag to prevent spawning multiple players

## Called when the node enters the scene tree for the first time.
## Checks if a player already exists and performs initial spawn if necessary.
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
			# Only connect the signal if we need to spawn when something enters
			area_3d.body_entered.connect(_on_body_entered)
		else:
			# Disable area monitoring if not needed for enter spawns to save resources
			area_3d.monitoring = false
			area_3d.monitorable = false
	# -------------------------------------

## Called when a body enters the Area3D (only connected if spawn_on_enter is true).
func _on_body_entered(body: Node3D) -> void:
	print("Body entered trigger: ", body.name)
	# Optional: Add more specific checks here (e.g., if body.is_in_group("player"))
	# Currently, any body entering will trigger a spawn attempt if spawn_on_enter is true.
	spawn_player()

## Handles the instantiation and placement of the player character.
func spawn_player() -> void:
	# Prevent spawning if already spawned or if scene is not set
	if has_spawned or player_scene == null:
		if player_scene == null:
			printerr("Spawner Error: player_scene is not assigned in the Inspector.")
		return
		
	# Set flag to prevent multiple spawns
	has_spawned = true
	
	print("Spawning Player...")
	
	var player_instance = player_scene.instantiate()
	
	# Ensure the instantiated scene root is a Node3D for positioning
	if !(player_instance is Node3D):
		printerr("Spawner Error: player_scene did not instantiate a Node3D.")
		# Consider resetting has_spawned = false here if retrying is desired
		return
		
	# Position the new player instance at the spawner's location
	player_instance.global_position = self.global_position
	
	# Add the player instance to the scene tree (as a sibling to this spawner)
	# Important: This spawner node must be part of the main scene tree.
	if get_parent():
		get_parent().add_child(player_instance)
		print("Player spawned at: ", player_instance.global_position)
		
		# Disable the trigger area after successful spawn if it's not needed for future enters
		if area_3d and not spawn_on_enter:
			area_3d.monitoring = false
			area_3d.monitorable = false
	else:
		printerr("Spawner Error: Spawner node has no parent. Cannot add player instance.")
		# Consider resetting has_spawned = false here if retrying is desired


# Called every frame. 'delta' is the elapsed time since the previous frame.
# func _process(delta: float) -> void:
# 	pass
