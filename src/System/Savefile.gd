extends Node

const path := "user://savegame.save"
const save_version := 0.4
var game_data = {}
var storage = preload("res://src/System/SaveStorage.gd").new()
var _loaded := false
var _loading := false
var _save_queued := false

signal loaded
signal saved

func save() -> void:
	if not _loaded or _loading:
		return
	print("Save: Saving...")
	set_all_data()
	if write_to_file():
		emit_signal("saved")

func _ready() -> void:
	pause_mode = Node.PAUSE_MODE_PROCESS
	GlobalVariables.connect("value_changed", self, "queue_save")
	Configurations.connect("value_changed", self, "queue_save")

func queue_save(_key = null) -> void:
	if _loaded and not _loading and not _save_queued:
		_save_queued = true
		call_deferred("_flush_queued_save")

func _flush_queued_save() -> void:
	_save_queued = false
	save()

func _notification(what: int) -> void:
	if what == MainLoop.NOTIFICATION_WM_QUIT_REQUEST or what == MainLoop.NOTIFICATION_WM_FOCUS_OUT or what == MainLoop.NOTIFICATION_APP_PAUSED:
		if _loaded and not _loading:
			save()

func set_all_data() -> void:
	game_data["version"] = save_version
	game_data["collectibles"] = GameManager.collectibles
	game_data["variables"] = GlobalVariables.variables
	game_data["configs"] = Configurations.variables
	game_data["keys"] = InputManager.modified_keys
	game_data["achievements"] = Achievements.export_unlocked_list()

func write_to_file() -> bool:
	var success: bool = storage.write_data(game_data)
	if not success:
		push_error("Save: write failed; existing save preserved. Error=%d path=%s" % [storage.last_error, OS.get_user_data_dir()])
	return success

func load_from_file() -> void:
	var data = storage.load_data()
	if data != null:
		game_data = data
		print("Save: loaded from %s" % storage.loaded_from)
	else:
		game_data = empty_data()
		if not storage.writes_allowed:
			push_error("Save: unreadable save preserved; automatic writes disabled. Path=%s" % OS.get_user_data_dir())

func load_save():
	print("Save: Loading...")
	_loading = true
	load_from_file()
	apply_data()
	_loading = false
	_loaded = true
	emit_signal("loaded")

func clear_save():
	print("Save: Creating new savefile")
	game_data = empty_data()
	storage.writes_allowed = true
	InputMap.load_from_globals()
	write_to_file()

func empty_data() -> Dictionary:
	return {
		"version": save_version,
		"collectibles" : [],
		"variables" : {},
		"configs" : {},
		"keys" : {},
		"achievements" : {}
	}

func clear_game_data() -> void:
	print("Save: clearing game data")
	set_all_data()
	game_data["collectibles"] = []
	game_data["variables"] = {}
	apply_data()
	GatewayManager.reset_bosses()
	IGT.reset()
	write_to_file()

func clear_keybinds() -> void:
	print("Save: clearing keybinds")
	set_all_data()
	game_data["keys"] = {}
	InputMap.load_from_globals()
	apply_data()
	write_to_file()

func clear_options() -> void:
	print("Save: clearing configs")
	set_all_data()
	game_data["configs"] = {}
	apply_data()
	write_to_file()

func apply_data():
	if storage.valid(game_data):
		GameManager.collectibles = game_data["collectibles"]
		GlobalVariables.load_variables(game_data["variables"])
		Configurations.load_variables(game_data["configs"])
		Achievements.load_achievements(game_data["achievements"])
		InputManager.load_modified_keys(game_data["keys"])
		call_deferred("emit_signal","loaded")
		print("Save: Finished applying and emitted signal")
	else:
		push_error("Save: invalid data was not applied or erased")
		
