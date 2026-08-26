extends StaticBody2D

export var able_to_open := true
export var able_to_explode := true
export var alternate_sprite_frames : SpriteFrames
export var boss_spawner : NodePath #used by ExplosionCloser
export var unlock_source : NodePath
signal open
signal passing
signal close
signal explode
signal finish

var _unlock_source_node: Node

func _ready() -> void:
	if alternate_sprite_frames:
		$animatedSprite.frames = alternate_sprite_frames
	set_physics_process(false)
	if not unlock_source.is_empty():
		call_deferred("_bind_unlock_source")

func _physics_process(_delta: float) -> void:
	_check_unlock_source_state()

func _bind_unlock_source() -> void:
	_unlock_source_node = get_node_or_null(unlock_source)
	if not is_instance_valid(_unlock_source_node):
		push_warning("Door unlock source was not found: %s" % str(unlock_source))
		return
	for source_signal in ["zero_health", "death", "object_death", "actual_enemy_death", "defeated"]:
		if _unlock_source_node.has_signal(source_signal) and not _unlock_source_node.is_connected(source_signal, self, "_on_unlock_source_defeated"):
			_unlock_source_node.connect(source_signal, self, "_on_unlock_source_defeated")
	set_physics_process(not able_to_open)
	_check_unlock_source_state()

func _check_unlock_source_state() -> void:
	if able_to_open:
		set_physics_process(false)
		return
	if not is_instance_valid(_unlock_source_node):
		return
	if _source_is_defeated(_unlock_source_node):
		_on_unlock_source_defeated()

func _source_is_defeated(source: Node) -> bool:
	if source.has_method("is_defeated") and source.call("is_defeated"):
		return true
	if _has_property(source, "current_health"):
		var health = source.get("current_health")
		if (typeof(health) == TYPE_INT or typeof(health) == TYPE_REAL) and float(health) <= 0.0:
			return true
	if _has_property(source, "has_spawned_once") and _has_property(source, "has_spawned"):
		return bool(source.get("has_spawned_once")) and not bool(source.get("has_spawned"))
	return false

func _has_property(object: Object, property_name: String) -> bool:
	for property in object.get_property_list():
		if property.name == property_name:
			return true
	return false

func _on_unlock_source_defeated(_argument = null) -> void:
	if able_to_open and able_to_explode:
		return
	_on_Unlock_and_able_to_explode()
	set_physics_process(false)
	if is_inside_tree():
		var compatibility = get_node_or_null("/root/UWPCompatibility")
		if compatibility and compatibility.is_active():
			compatibility.diag("midboss door unlocked door=%s source=%s" % [name, _unlock_source_node.name if is_instance_valid(_unlock_source_node) else str(unlock_source)])

func _on_Open_start(_ability_name) -> void:
	emit_signal("open")

func _on_PassThrough_start(_ability_name) -> void:
	emit_signal("passing")

func _on_Close_start(_ability_name) -> void:
	emit_signal("close")

func _on_Explode_start(_ability_name) -> void:
	emit_signal("explode")

func _on_Close_stop(_ability_name) -> void:
	emit_signal("finish")

func _on_Unlock() -> void:
	able_to_open = true
	set_physics_process(false)

func _on_Unlock_and_able_to_explode() -> void:
	_on_Unlock()
	able_to_explode = true
	
func _on_Lock() -> void:
	able_to_open = false
	able_to_explode = false

func destroy() -> void:
	queue_free()
