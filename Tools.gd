extends Node
class_name Tools

const buttons = ["move_left","move_right","move_up","move_down",
				 "alt_fire"]

static func filter_for_type(type,children): #returns a list
	var particle_list = []
	for child in children:
		if child is type:
			particle_list.append(child)
	return particle_list

static func filter_particles(children): #returns a list
	var particle_list = []
	for child in children:
		if child is Particles2D:
			particle_list.append(child)
	return particle_list
	
static func filter_for_name(text : String, children): #returns a list
	var valid_children = []
	for child in children:
		if text in child.name:
			valid_children.append(child)
	return valid_children
	
static func toggle_emit(object, state : bool):
	if object is Array:
		for particle in object:
			particle.emitting = state
	else:
		object.emitting = state
		
static func flip(object, d : int):
	if object is Array:
		for particle in object:
			particle.scale.x = d
	else:
		object.scale.x = d
		
static func is_almost_equal(value_a, value_b, range_ := 0.1) -> bool:
	return value_a > value_b - range_ and value_a < value_b + range_
	
static func is_between(value, minimum, maximum) -> bool:
	return value >= minimum and value <= maximum

static func instantiate(scene : PackedScene) -> Node2D:
	var instance = scene.instance()
	return instance

static func get_player_angle(global_position : Vector2) -> Vector2:
	return ((GameManager.get_player_position() + Vector2(0,5)) - global_position).normalized()
	
static func get_angle_between(target, tracker) -> Vector2:
	return (target.global_position - tracker.global_position).normalized()

static func flip_input(key) -> String:
	if key == "move_left":
		return "move_right"
	elif key == "move_right":
		return "move_left"
	elif key == "move_left_analog":
		return "move_right_analog"
	elif key == "move_right_analog":
		return "move_left_analog"
	return key

static func get_readable_time(time) -> String:
	var minutes = fmod((time/60),60)
	var seconds = fmod(time,60)
	var miliseconds = int((time - int(time)) * 100)
	return "%02d:%02d.%02d" % [minutes, seconds, miliseconds]

static func get_full_readable_time(time) -> String:
	var hours = (time/60)/60
	var minutes = fmod((time/60),60)
	var seconds = fmod(time,60)
	var miliseconds = int((time - int(time)) * 100)
	return "%02d:%02d:%02d.%02d" % [hours, minutes, seconds, miliseconds]
	

static func timer(wait_time : float, method : String, parent : Node, method_owner = null, ignore_pause := false) -> void:
	var timer = Timer.new()
	if method_owner == null:
		method_owner = parent
	timer.connect("timeout",method_owner,method)
	timer.connect("timeout",timer,"queue_free",[],1)
	timer.wait_time = wait_time
	timer.one_shot = true
	if ignore_pause:
		timer.pause_mode = Node.PAUSE_MODE_PROCESS
	parent.call_deferred("add_child",timer)
	timer.call_deferred("start")
	
static func timer_p(wait_time : float, method : String, parent : Node, param) -> void:
	var timer = Timer.new()
	if param is Array:
		timer.connect("timeout",parent,method, param)
	else:
		timer.connect("timeout",parent,method, [param])
	timer.wait_time = wait_time
	timer.one_shot = true
	parent.call_deferred("add_child",timer)
	timer.call_deferred("start")

static func timer_r(wait_time : float, method : String, parent : Node, param = null) -> Timer:
	var timer = Timer.new()
	if not param is Array:
		timer.connect("timeout",parent,method, [param])
	else:
		timer.connect("timeout",parent,method, param)
	#timer.connect("timeout",timer,"queue_free",1)
	timer.wait_time = wait_time
	timer.one_shot = true
	parent.call_deferred("add_child",timer)
	timer.call_deferred("start")
	return timer

# warning-ignore:unused_argument
static func tween(parent,property,final_value,duration, ease_type := Tween.EASE_IN_OUT, trans_type := Tween.TRANS_LINEAR) -> void:
	var tween : SceneTreeTween  = parent.create_tween()
# warning-ignore:return_value_discarded
	tween.tween_property(parent,property,final_value, duration).set_ease(Tween.EASE_IN_OUT).set_trans(trans_type)
	
static func tween_method(parent,method,start_value,final_value,duration) -> void:
	var tween : SceneTreeTween  = parent.create_tween()
# warning-ignore:return_value_discarded
	tween.tween_method(parent,method,start_value,final_value,duration)

static func raycast(object : Node2D, local_target_position : Vector2, start_position = null, collision_layer = 1) -> Dictionary:
	if start_position == null:
		start_position = object.global_position
	local_target_position += object.global_position
	var space_state = object.get_world_2d().direct_space_state
	return space_state.intersect_ray(start_position, local_target_position, [object], collision_layer)

static func distance(value1 :float, value2 :float) -> float:
	return abs(abs(value1) - abs(value2))

# --- Xbox/UWP port helpers ---
# Godot 3.x's documented way to detect the export platform at runtime is via
# feature tags (OS.has_feature), not OS.get_name(). "UWP" is the feature tag
# Godot's exporter attaches to UWP builds. We also check OS.get_name() as a
# redundant fallback in case the feature tag isn't present in a given build.
# IMPORTANT: verify this against an actual UWP export running on device/emulator
# before relying on it for anything player-facing - feature tag behavior should
# be confirmed empirically, not assumed.
static func is_uwp_platform() -> bool:
	return OS.has_feature("UWP") or OS.get_name() == "UWP"

# Convenience alias: anything that doesn't make sense on a closed console
# (manual window mode toggles, desktop-only display options, etc.) should
# check this before showing itself or applying its effect.
static func is_console_platform() -> bool:
	return is_uwp_platform()
