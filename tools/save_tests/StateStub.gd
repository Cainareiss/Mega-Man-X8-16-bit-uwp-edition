extends Node

var collectibles := []
var modified_keys := {}
var unlocked := {}

func reset_bosses() -> void:
	pass

func reset() -> void:
	pass

func export_unlocked_list() -> Dictionary:
	return unlocked

func load_achievements(data: Dictionary) -> void:
	unlocked = data.duplicate(true)

func load_modified_keys(data: Dictionary) -> void:
	modified_keys = data.duplicate(true)
