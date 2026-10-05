extends Reference

# Keep the original Variant format and filename, including legacy 0.4 saves.
const VERSION := 0.4
var path := "user://savegame.save"
var last_error := OK
var loaded_from := ""
var writes_allowed := false

func valid(data) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var version = data.get("version")
	if typeof(version) != TYPE_REAL and typeof(version) != TYPE_INT:
		return false
	if not is_equal_approx(float(version), VERSION):
		return false
	if typeof(data.get("collectibles")) != TYPE_ARRAY:
		return false
	for key in ["variables", "configs", "keys", "achievements"]:
		if typeof(data.get(key)) != TYPE_DICTIONARY:
			return false
	return true

func read_file(filename: String):
	var file := File.new()
	last_error = file.open(filename, File.READ)
	if last_error != OK:
		return null
	# Reject incomplete Variant records before asking Godot to deserialize them.
	if file.get_len() < 4:
		file.close()
		return null
	var payload_size := file.get_32()
	if payload_size <= 0 or payload_size != file.get_len() - 4:
		file.close()
		return null
	file.seek(0)
	var data = file.get_var(false)
	file.close()
	return data if valid(data) else null

func load_data():
	loaded_from = ""
	writes_allowed = false
	var any_file := false
	for filename in [path, path + ".bak", path + ".tmp"]:
		if File.new().file_exists(filename):
			any_file = true
			var data = read_file(filename)
			if data != null:
				loaded_from = filename
				writes_allowed = true
				return data
	# A damaged/unknown existing file must never be replaced by an empty save.
	writes_allowed = not any_file
	return null

func write_data(data: Dictionary) -> bool:
	if not writes_allowed or not valid(data):
		last_error = ERR_INVALID_DATA
		return false
	var pending := path + ".tmp"
	var file := File.new()
	last_error = file.open(pending, File.WRITE)
	if last_error != OK:
		return false
	file.store_var(data, false)
	file.flush()
	last_error = file.get_error()
	file.close()
	if last_error != OK or read_file(pending) == null:
		last_error = ERR_FILE_CORRUPT
		return false
	var directory := Directory.new()
	# Only rotate a known-good primary; never overwrite a recovery backup with
	# corrupt data. A failed replacement leaves the primary and backup intact.
	if read_file(path) != null:
		last_error = directory.copy(path, path + ".bak")
		if last_error != OK:
			return false
	last_error = directory.rename(pending, path)
	return last_error == OK
