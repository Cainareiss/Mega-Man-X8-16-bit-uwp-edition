extends Node

const CASES := [
	{
		"scene": "res://src/Levels/MetalValley/Stage_MetalValley.tscn",
		"door": "Objects/BossDoor1",
		"source": "Enemies/GiantMechaniloid",
		"signal": "death",
		"state": "health"
	},
	{
		"scene": "res://src/Levels/BoosterForest/Stage_BoosterForest.tscn",
		"door": "Objects/VileExitDoor",
		"source": "Objects/VileSpawner",
		"signal": "object_death",
		"state": "spawner"
	},
	{
		"scene": "res://src/Levels/Primrose/Stage_Primrose.tscn",
		"door": "Scenery/RoomVile/VileExitDoor",
		"source": "Scenery/RoomVile/VileSpawner",
		"signal": "object_death",
		"state": "spawner"
	},
	{
		"scene": "res://src/Levels/SigmaPalace/Stage_SigmaPalace.tscn",
		"door": "Objects/VileExitDoor",
		"source": "Objects/MidfightVileSpawner",
		"signal": "object_death",
		"state": "spawner"
	},
	{
		"scene": "res://src/Levels/SigmaPalace/SeraphTest.tscn",
		"door": "Objects/VileExitDoor",
		"source": "Objects/MidfightVileSpawner",
		"signal": "object_death",
		"state": "spawner"
	}
]

var failures := []
var cases_checked := 0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	_validate_frame_rate_policy()
	for definition in CASES:
		_validate_door(definition)
	# Let deferred resource and signal cleanup finish before quitting the engine.
	yield(get_tree(), "idle_frame")
	yield(get_tree(), "idle_frame")
	_finish()

func _validate_frame_rate_policy() -> void:
	_check(ProjectSettings.get_setting("application/run/target_fps") == 60, "Base target FPS is not 60")
	_check(ProjectSettings.get_setting("physics/common/physics_fps") == 60, "Physics FPS is not 60")
	_check(ProjectSettings.get_setting("display/window/vsync/use_vsync") == true, "VSync is not enabled")
	_check(ProjectSettings.get_setting("application/run/low_processor_mode") == false, "Low processor mode is still enabled")
	_check(Engine.target_fps == 60, "Runtime target FPS is not 60")
	_check(Engine.iterations_per_second == 60, "Runtime physics FPS is not 60")

func _validate_door(definition: Dictionary) -> void:
	var packed = ResourceLoader.load(definition.scene, "PackedScene")
	_check(packed != null, "Could not load stage: %s" % definition.scene)
	if not packed:
		return
	var stage = packed.instance()
	_check(stage != null, "Could not instance stage: %s" % definition.scene)
	if not stage:
		return
	var door = stage.get_node_or_null(definition.door)
	var source = stage.get_node_or_null(definition.source)
	_check(door != null, "Door not found: %s:%s" % [definition.scene, definition.door])
	_check(source != null, "Midboss source not found: %s:%s" % [definition.scene, definition.source])
	if not door or not source:
		stage.free()
		return

	_check(not door.able_to_open, "Midboss door must start locked: %s" % definition.scene)
	_check(not door.unlock_source.is_empty(), "Midboss door has no recovery source: %s" % definition.scene)
	_check(door.get_node_or_null(door.unlock_source) == source, "Door recovery source points to the wrong node: %s" % definition.scene)
	_check(source.has_signal(definition.signal), "Midboss source lost signal %s: %s" % [definition.signal, definition.scene])

	# Exercise the new binding without relying on the pre-existing scene connection.
	door._bind_unlock_source()
	_check(door._unlock_source_node == source, "Door could not bind its recovery source: %s" % definition.scene)

	# Simulate a missed signal. The watchdog must still recover from authoritative
	# health/spawner state, which is the failure observed on slower UWP frames.
	door.able_to_open = false
	door.able_to_explode = false
	if definition.state == "health":
		source.set("current_health", 0.0)
	else:
		source.set("has_spawned_once", true)
		source.set("has_spawned", false)
	door._check_unlock_source_state()
	_check(door.able_to_open and door.able_to_explode, "Door stayed locked after midboss defeat state: %s" % definition.scene)

	cases_checked += 1
	stage.free()

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _finish() -> void:
	var directory := Directory.new()
	directory.make_dir_recursive("res://build/validation")
	var report := File.new()
	if report.open("res://build/validation/midboss_door_validation.txt", File.WRITE) == OK:
		report.store_line("Midboss door and 60 FPS validation")
		report.store_line("cases_checked=%d" % cases_checked)
		report.store_line("failures=%d" % failures.size())
		for failure in failures:
			report.store_line("FAILURE: " + failure)
		report.close()
	print("Midboss door validation: cases=%d failures=%d" % [cases_checked, failures.size()])
	for failure in failures:
		printerr("Midboss door validation failure: " + failure)
	get_tree().quit(failures.size())
