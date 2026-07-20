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

	var waterfall := Sprite.new()
	waterfall.name = "WaterfallPaletteValidation"
	waterfall.position = Vector2(-1000, -1000)
	waterfall.texture = load("res://src/Levels/NoahsPark/tiled_waterfall1.png")
	# Keep the original Shader resource reference so this follows the exact
	# resource_path-based replacement used by the exported scene.
	waterfall.material = load("res://src/Effects/Materials/mat_waterfall.tres").duplicate(false)
	add_child(waterfall)
	yield(get_tree(), "idle_frame")
	_check(waterfall.material.shader == compatibility._palette_shader, "Waterfall did not use the GLES2 palette animation")
	_check(is_equal_approx(float(waterfall.material.get_shader_param("fps")), 24.0), "Waterfall palette animation lost its original 24 FPS cadence")
	_check(float(waterfall.material.get_shader_param("palette_columns")) > 1.0, "Waterfall palette width was not configured")
	_check(float(waterfall.material.get_shader_param("palette_rows")) > 1.0, "Waterfall palette rows were not configured")

	# Add the source as part of a PackedScene so node_added fires while Godot is
	# still mounting a child tree, exactly like the real Player.tscn path.
	var charge_definitions := [
		{
			"name": "ChargingParticle",
			"texture": load("res://src/Effects/Textures/charge_1.png"),
			"process_material": load("res://src/Effects/Materials/x_charging_particle.tres")
		},
		{
			"name": "ChargedParticle",
			"texture": load("res://src/Effects/Textures/charge_2.png"),
			"process_material": load("res://src/Effects/Materials/x_charged_particle.tres")
		},
		{
			"name": "SuperChargeParticle",
			"texture": load("res://src/Effects/Textures/charge_2.png"),
			"process_material": load("res://src/Effects/Materials/x_supercharged_particle.tres")
		}
	]
	var packed_charge := PackedScene.new()
	var charge_carrier := Node2D.new()
	charge_carrier.name = "ChargeCarrier"
	for charge_index in range(charge_definitions.size()):
		var definition: Dictionary = charge_definitions[charge_index]
		var packed_charge_source := Particles2D.new()
		packed_charge_source.name = definition.name
		packed_charge_source.position = Vector2(105 + charge_index * 60, 112)
		packed_charge_source.visible = true
		packed_charge_source.emitting = false
		packed_charge_source.lifetime = 0.3
		packed_charge_source.texture = definition.texture
		packed_charge_source.material = load("res://src/Effects/Materials/mat_chargeparticle.tres")
		packed_charge_source.process_material = definition.process_material
		charge_carrier.add_child(packed_charge_source)
		packed_charge_source.owner = charge_carrier
	packed_charge.pack(charge_carrier)
	charge_carrier.free()
	var charge_instance = packed_charge.instance()
	add_child(charge_instance)
	yield(get_tree(), "idle_frame")
	yield(get_tree(), "idle_frame")
	var charge_sources := []
	for definition in charge_definitions:
		var charge_source = charge_instance.get_node(definition.name)
		charge_sources.append(charge_source)
		compatibility.set_charge_animation_visible(charge_source, true)
	yield(get_tree(), "idle_frame")

	var first_charge_animation = null
	for charge_source in charge_sources:
		var animation_name: String = charge_source.name + " UWP Charge Animation"
		var charge_animation = charge_instance.get_node_or_null(animation_name)
		_check(charge_animation != null, "%s original charge atlas was not created" % charge_source.name)
		if not charge_animation:
			continue
		if first_charge_animation == null:
			first_charge_animation = charge_animation
		_check(charge_animation.active, "%s original charge atlas did not activate" % charge_source.name)
		_check(charge_animation.visible, "%s original charge atlas is not visible" % charge_source.name)
		_check(charge_animation.texture == charge_source.texture, "%s fallback is not using the original texture" % charge_source.name)
		_check(charge_animation.color == charge_source.process_material.color, "%s fallback lost the original particle color" % charge_source.name)
		_check(charge_animation.hframes == 4 and charge_animation.vframes == 4, "%s fallback lost the original 4x4 atlas layout" % charge_source.name)
		_check(is_equal_approx(charge_animation.lifetime, 0.3), "%s fallback lost the original 0.3 second timing" % charge_source.name)
	if first_charge_animation:
		var first_charge_frame: int = first_charge_animation.frame
		var charge_frame_timer := get_tree().create_timer(0.08)
		yield(charge_frame_timer, "timeout")
		_check(first_charge_animation.frame != first_charge_frame, "Mega Buster original atlas frames did not advance")

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

	var sequence_source := Node2D.new()
	sequence_source.name = "LargeEnemyDeath"
	sequence_source.position = Vector2(290, 112)
	add_child(sequence_source)
	compatibility.spawn_explosion_sequence(sequence_source, 8, 18.0, 0.9, 0.55, 2.0, load("res://src/Effects/Textures/explosion.png"))
	yield(get_tree(), "idle_frame")
	var sequence = get_node_or_null("UWP Explosion Sequence")
	_check(sequence != null, "Sustained large-enemy explosion sequence was not created")
	var sequence_timer := get_tree().create_timer(0.32)
	yield(sequence_timer, "timeout")
	if sequence:
		_check(sequence._spawned >= 2, "Large-enemy explosions did not continue over time")

	yield(VisualServer, "frame_post_draw")
	_save_screenshot()
	if OS.get_environment("MMX_UWP_QUICK_TEST") != "1":
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
