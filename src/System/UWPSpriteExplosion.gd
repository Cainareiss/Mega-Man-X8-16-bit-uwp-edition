extends Node2D

var texture: Texture
var velocity := Vector2.ZERO
var lifetime := 0.55
var frame_time := 0.035
var frame := 0
var age := 0.0
var frames := 16
var columns := 4
var size_scale := 1.0

func _ready() -> void:
	set_process(true)
	z_as_relative = false
	z_index = 100
	lifetime = max(lifetime, 0.45)
	frame_time = max(frame_time, 0.025)

func _process(delta: float) -> void:
	age += delta
	position += velocity * delta
	velocity = velocity.move_toward(Vector2.ZERO, 280.0 * delta)
	frame = int(age / frame_time)
	if age >= lifetime or frame >= frames:
		queue_free()
		return
	update()

func _draw() -> void:
	if not texture:
		var fallback_alpha := clamp(1.0 - age / max(lifetime, 0.001), 0.0, 1.0)
		draw_circle(Vector2.ZERO, (10.0 + age * 35.0) * size_scale, Color(1.0, 0.85, 0.25, fallback_alpha))
		draw_circle(Vector2.ZERO, (5.0 + age * 20.0) * size_scale, Color(1.0, 1.0, 1.0, fallback_alpha))
		return
	var size := texture.get_size() / Vector2(columns, columns)
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var col := frame % columns
	var row := int(frame / columns)
	var src := Rect2(Vector2(col, row) * size, size)
	var alpha := clamp(1.0 - age / max(lifetime, 0.001), 0.0, 1.0)
	var draw_size := size * size_scale
	draw_texture_rect_region(texture, Rect2(-draw_size * 0.5, draw_size), src, Color(1, 1, 1, alpha))
