extends Node2D

# GLES2/UWP replacement for the original one-particle charge effect. The
# source texture is a 4x4 atlas; Godot's particle material advances all 16
# frames over the particle lifetime. Drawing the same atlas directly keeps the
# authored animation without relying on ANGLE's particle-frame path.

var source: Particles2D
var texture: Texture
var color := Color(0.470588, 0.847059, 0.941176, 1.0)
var hframes := 4
var vframes := 4
var lifetime := 0.3
var lifetime_randomness := 0.0
var active := false
var frame := 0

var _elapsed := 0.0
var _cycle_duration := 0.3

func _ready() -> void:
	pause_mode = Node.PAUSE_MODE_PROCESS
	_reset_cycle()
	_sync_with_source()
	update()

func _process(delta: float) -> void:
	if not is_instance_valid(source):
		queue_free()
		return
	_sync_with_source()
	visible = active and source.is_visible_in_tree()
	_elapsed += delta
	while _elapsed >= _cycle_duration:
		_elapsed -= _cycle_duration
		_reset_cycle()
	var total_frames := max(hframes * vframes, 1)
	var next_frame := min(int((_elapsed / _cycle_duration) * total_frames), total_frames - 1)
	if next_frame != frame:
		frame = next_frame
		update()

func set_active(value: bool) -> void:
	active = value
	visible = value and is_instance_valid(source) and source.is_visible_in_tree()
	if value:
		update()

func _sync_with_source() -> void:
	if not is_instance_valid(source):
		return
	transform = source.transform
	z_index = source.z_index
	z_as_relative = source.z_as_relative
	modulate = source.modulate

func _reset_cycle() -> void:
	var randomness := clamp(lifetime_randomness, 0.0, 1.0)
	_cycle_duration = max(lifetime * (1.0 - rand_range(0.0, randomness)), 0.01)
	frame = 0

func _draw() -> void:
	if not visible or not texture:
		return
	var columns: int = max(hframes, 1)
	var rows: int = max(vframes, 1)
	var texture_size := texture.get_size()
	var frame_size := Vector2(texture_size.x / columns, texture_size.y / rows)
	var column: int = frame % columns
	var row: int = int(frame / columns)
	var source_rect := Rect2(Vector2(column, row) * frame_size, frame_size)
	var target_rect := Rect2(-frame_size * 0.5, frame_size)
	draw_texture_rect_region(texture, target_rect, source_rect, color)
