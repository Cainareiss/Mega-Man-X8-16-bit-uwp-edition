extends Node2D

var source: Particles2D
var texture: Texture
var color := Color(0.55, 0.9, 1.0, 1.0)
var radius := 11.0
var speed := 8.0
var phase := 0.0
var active := false
var _time := 0.0

func _ready() -> void:
	set_as_toplevel(true)
	z_as_relative = false
	z_index = 350

func _process(delta: float) -> void:
	if not is_instance_valid(source):
		queue_free()
		return
	visible = active and source.is_visible_in_tree()
	global_position = source.global_position
	z_index = 350
	_time += delta
	update()

func set_active(value: bool) -> void:
	active = value
	visible = value and is_instance_valid(source) and source.is_visible_in_tree()
	if value:
		update()

func _draw() -> void:
	if not visible:
		return
	var pulse := 0.65 + 0.35 * abs(sin(_time * 12.0 + phase))
	for i in range(8):
		var angle := _time * speed + phase + PI * 2.0 * float(i) / 8.0
		var offset := Vector2(cos(angle), sin(angle)) * radius
		var scale := 0.75 + pulse * 0.45
		var alpha := 0.65 + pulse * 0.35
		draw_circle(offset, 4.5 * scale, Color(color.r, color.g, color.b, alpha))
		draw_circle(offset * 0.65, 2.0 * scale, Color(1.0, 1.0, 1.0, alpha * 0.75))
	draw_arc(Vector2.ZERO, radius + 3.0 * pulse, _time * speed, _time * speed + PI * 1.45, 24, Color(color.r, color.g, color.b, 0.85), 3.0, true)
