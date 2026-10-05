extends Node

var failures := []

func _ready() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		printerr(message)

func run() -> void:
	var phase := OS.get_environment("MMX_SAVE_TEST_PHASE")
	Savefile.load_save()
	if phase == "write":
		GlobalVariables.set("panda_defeated", true)
		Configurations.set("FPS", 60)
		GameManager.collectibles.append("icarus_foot")
		Savefile.queue_save()
		yield(get_tree(), "idle_frame")
		yield(get_tree(), "idle_frame")
		check(File.new().file_exists(Savefile.path), "Autosave was not written")
	elif phase == "read":
		check(GlobalVariables.get("panda_defeated") == true, "Boss progress lost across process restart")
		check(Configurations.get("FPS") == 60, "Options lost across process restart")
		check("icarus_foot" in GameManager.collectibles, "Collectibles lost across process restart")
		# A second write must leave a valid previous save for recovery.
		GlobalVariables.set("vile_defeated", true)
		Savefile.save()
		check(Savefile.storage.read_file(Savefile.path + ".bak") != null, "No valid save backup")
		# Simulate power loss while writing the primary, then recover the backup.
		var file := File.new()
		file.open(Savefile.path, File.WRITE)
		file.store_8(0)
		file.close()
		Savefile.load_save()
		check(Savefile.storage.loaded_from == Savefile.path + ".bak", "Corrupt primary did not recover backup")
		check(GlobalVariables.get("panda_defeated") == true, "Recovered save lost original progress")
		Savefile.save()
		check(Savefile.storage.read_file(Savefile.path) != null, "Recovery did not restore writable primary")
		# Failed writes may not claim success or destroy the last good primary.
		var original_path: String = Savefile.storage.path
		Savefile.storage.path = "user://missing-directory/savegame.save"
		check(not Savefile.storage.write_data(Savefile.game_data), "Failed file open was reported as successful")
		Savefile.storage.path = original_path
		check(Savefile.storage.read_file(original_path) != null, "Failed write destroyed primary")
		var isolated = preload("res://src/System/SaveStorage.gd").new()
		isolated.path = "user://invalid_existing.save"
		file.open(isolated.path, File.WRITE)
		file.store_8(42)
		file.close()
		check(isolated.load_data() == null and not isolated.writes_allowed, "Corrupt unknown save allowed empty overwrite")
		check(not isolated.write_data(Savefile.game_data), "Corrupt save was overwritten")
		check(File.new().file_exists(isolated.path), "Corrupt save was erased")
		var legacy = Savefile.game_data.duplicate(true)
		legacy.version = 0.40000000596046448
		check(isolated.valid(legacy), "Legacy float version rejected")
		legacy.version = 99
		check(not isolated.valid(legacy), "Unsupported version accepted")
	else:
		failures.append("Unknown test phase")
	print("SAVE REGRESSION phase=%s failures=%d" % [phase, failures.size()])
	get_tree().quit(failures.size())
