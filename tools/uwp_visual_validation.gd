extends Node2D

var failures := []
var warnings := []
var loaded_scenes := 0
var visual_nodes := 0
var textures_checked := 0
var _checked_textures := {}

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	VisualServer.set_default_clear_color(Color(0.015, 0.02, 0.05, 1.0))
	var compatibility = get_node_or_null("/root/UWPCompatibility")
	_check(compatibility != null, "UWPCompatibility autoload is missing")
	if not compatibility:
		_finish()
		return
	_check(compatibility.is_active(), "UWP compatibility test mode is not active")

	var charge_source := Particles2D.new()
	charge_source.name = "ChargingParticle"
	charge_source.position = Vector2(105, 112)
	charge_source.visible = true
	charge_source.emitting = false
	charge_source.texture = load("res://src/Effects/Textures/charge_1.png")
	add_child(charge_source)
	yield(get_tree(), "idle_frame")
	yield(get_tree(), "idle_frame")
	compatibility.set_charge_spiral_visible(charge_source, true)
	yield(get_tree(), "idle_frame")

	var spiral = get_node_or_null("ChargingParticle UWP Spiral")
	_check(spiral != null, "Mega Buster CPU spiral was not created")
	if spiral:
		_check(spiral.active, "Mega Buster CPU spiral did not activate")
		_check(spiral.visible, "Mega Buster CPU spiral is not visible")

	compatibility.spawn_explosion_burst(Vector2(290, 112), 5, 9.0, 0.65, 0.55)
	var timer := get_tree().create_timer(0.16)
	yield(timer, "timeout")
	var explosion_count := 0
	var animated_explosion_count := 0
	for child in get_children():
		if child.get_script() and child.get_script().resource_path == "res://src/System/UWPSpriteExplosion.gd":
			explosion_count += 1
			if child.frame > 0:
				animated_explosion_count += 1
	_check(explosion_count == 5, "Expected 5 CPU explosions, got %d" % explosion_count)
	_check(animated_explosion_count == explosion_count, "CPU explosion frames did not advance")

	yield(VisualServer, "frame_post_draw")
	_save_screenshot()
	yield(_validate_game_scenes(), "completed")
	_finish()

func _validate_game_scenes() -> GDScriptFunctionState:
	var paths := []
	_collect_scenes("res://src/Actors/Bosses", paths, false)
	_collect_scenes("res://src/Levels", paths, true)
	for path in paths:
		var packed = ResourceLoader.load(path, "PackedScene")
		if not packed:
			failures.append("Could not load scene: %s" % path)
			continue
		var instance = packed.instance()
		if not instance:
			failures.append("Could not instance scene: %s" % path)
			continue
		loaded_scenes += 1
		_scan_visual_nodes(instance, path, instance.name)
		instance.free()
		if loaded_scenes % 8 == 0:
			yield(get_tree(), "idle_frame")
	return

func _collect_scenes(folder: String, output: Array, stages_only: bool) -> void:
	var directory := Directory.new()
	if directory.open(folder) != OK:
		failures.append("Could not open folder: %s" % folder)
		return
	directory.list_dir_begin(true, true)
	var entry := directory.get_next()
	while entry != "":
		var path := folder.plus_file(entry)
		if directory.current_is_dir():
			_collect_scenes(path, output, stages_only)
		elif entry.ends_with(".tscn") and (not stages_only or entry.begins_with("Stage_")):
			output.append(path)
		entry = directory.get_next()
	directory.list_dir_end()

func _scan_visual_nodes(node: Node, owner_path: String, node_path: String) -> void:
	if node is Sprite:
		visual_nodes += 1
		if node.texture:
			_check_texture(node.texture, owner_path + ":" + node_path)
		elif node.visible:
			warnings.append("Visible Sprite without texture: %s:%s" % [owner_path, node_path])
	elif node is AnimatedSprite:
		visual_nodes += 1
		if not node.frames:
			failures.append("AnimatedSprite without SpriteFrames: %s:%s" % [owner_path, node_path])
		else:
			for animation in node.frames.get_animation_names():
				for frame_index in range(node.frames.get_frame_count(animation)):
					var texture = node.frames.get_frame(animation, frame_index)
					if texture:
						_check_texture(texture, owner_path + ":" + node_path)
	for child in node.get_children():
		_scan_visual_nodes(child, owner_path, node_path + "/" + child.name)

func _check_texture(texture: Texture, context: String) -> void:
	var key := texture.get_instance_id()
	if _checked_textures.has(key):
		return
	_checked_textures[key] = true
	textures_checked += 1
	var size := texture.get_size()
	if size.x <= 0 or size.y <= 0:
		failures.append("Texture has invalid size: %s (%s)" % [context, str(size)])

func _save_screenshot() -> void:
	var directory := Directory.new()
	directory.make_dir_recursive("res://build/validation")
	var image := get_viewport().get_texture().get_data()
	image.flip_y()
	var error := image.save_png("res://build/validation/uwp_effects.png")
	_check(error == OK, "Could not save UWP effects validation screenshot")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _finish() -> void:
	var directory := Directory.new()
	directory.make_dir_recursive("res://build/validation")
	var report := File.new()
	if report.open("res://build/validation/uwp_validation.txt", File.WRITE) == OK:
		report.store_line("UWP GLES2 validation")
		report.store_line("loaded_scenes=%d" % loaded_scenes)
		report.store_line("visual_nodes=%d" % visual_nodes)
		report.store_line("textures_checked=%d" % textures_checked)
		report.store_line("warnings=%d" % warnings.size())
		report.store_line("failures=%d" % failures.size())
		for warning in warnings:
			report.store_line("WARNING: " + warning)
		for failure in failures:
			report.store_line("FAILURE: " + failure)
		report.close()
	print("UWP validation: scenes=%d visuals=%d textures=%d warnings=%d failures=%d" % [loaded_scenes, visual_nodes, textures_checked, warnings.size(), failures.size()])
	for failure in failures:
		printerr("UWP validation failure: " + failure)
	get_tree().quit(failures.size())
