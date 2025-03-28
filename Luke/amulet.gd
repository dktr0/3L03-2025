extends Node3D

@onready var ring1 = $ring1
@onready var ring2 = $ring2
@onready var ring3 = $ring3

var rotation_speed = 0.5  # Adjust speed as needed

func _process(delta):
	ring1.rotation_degrees.x += rotation_speed * delta * 60
	ring2.rotation_degrees.y += rotation_speed * delta * 60
	ring3.rotation_degrees.z += rotation_speed * delta * 60
