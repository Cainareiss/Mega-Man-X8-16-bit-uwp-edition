extends Node2D

signal particle_cache_finished
var compiled := false
var _show_debug_messages := false
var particles_cached := 0

var folder := "res://src/Effects/Materials"

func _ready() -> void:
	call_deferred("cache_materials")

func cache_materials(debug = false) -> void:
	_show_debug_messages = debug
	if has_node("/root/UWPCompatibility") and get_node("/root/UWPCompatibility").is_active():
		print("Cache: Skipped GPU particle warm-up on UWP/GLES2 compatibility mode.")
		finish_caching()
		return
	
	for file in get_files(folder):
		add_material_to_cache(file)

	finish_caching()

func add_material_to_cache(file) -> void:
	var mat = load(folder + "/" + file)
	var particle := Particles2D.new()
	particle.set_meta("shader_cache_only", true)
	Log("Adding to cache: " + file)
	if mat is ParticlesMaterial:
		particle.set_process_material(mat)
	else:
		particle.set_material(mat)
	particle.set_one_shot(true)
	particle.set_amount(1)
	particle.set_lifetime(0.25)
	particle.set_emitting(true)
	if GameManager.camera:
		GameManager.camera.add_child(particle)
		particle.global_position = GameManager.camera.get_camera_screen_center()
	else:
		get_tree().current_scene.add_child(particle)
	
	particles_cached += 1

func finish_caching() -> void:
	print("Cache: Finished Caching. " + str(particles_cached) + " particles cached.")
	compiled = true
	emit_signal("particle_cache_finished")
	

func get_files(path) -> Array:
	var files = []
	var dir = Directory.new()
	dir.open(path)
	dir.list_dir_begin(true)

	var file = dir.get_next()
	while file != '':
		files += [file]
		file = dir.get_next()

	return files

func Log(message) -> void:
	if _show_debug_messages:
		print_debug("Cache: " + str(message))
