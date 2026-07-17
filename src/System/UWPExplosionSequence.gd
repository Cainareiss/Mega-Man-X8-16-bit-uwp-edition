extends Node

var compatibility: Node
var source: Node2D
var world_position := Vector2.ZERO
var texture: Texture
var spread := 25.0
var total_duration := 2.0
var size_scale := 1.0
var emission_rate := 7.5
var max_explosions := 15

var _elapsed := 0.0
var _emission_accumulator := 1.0
var _spawned := 0

func _ready() -> void:
	set_process(true)

func _process(delta: float) -> void:
	_elapsed += delta
	if is_instance_valid(source):
		world_position = source.global_position
	_emission_accumulator += emission_rate * delta
	while _emission_accumulator >= 1.0 and _spawned < max_explosions and _elapsed <= total_duration:
		_emission_accumulator -= 1.0
		_spawned += 1
		if is_instance_valid(compatibility):
			compatibility.spawn_explosion_burst(world_position, 1, spread, 0.58, size_scale, 0.0, texture)
	if _elapsed >= total_duration or _spawned >= max_explosions:
		queue_free()
