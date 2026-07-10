extends X8OptionButton

func _ready() -> void:
	if Tools.is_console_platform():
		hide_on_console()
		return
	Configurations.listen("value_changed",self,"fullscreen_changed")

func hide_on_console() -> void:
	# Fullscreen toggling makes no sense on a closed console like Xbox Series S,
	# where the OS/shell always owns full-screen presentation.
	# Scene structure: Fullscreen (Control, parent) -> OptionName (Label) + Button (this script).
	# Containers in Godot skip invisible children when computing layout, so
	# hiding the parent row here is enough to close the gap automatically.
	focus_mode = Control.FOCUS_NONE
	var row = get_parent()
	if row:
		row.visible = false

func fullscreen_changed(key) -> void:
	if key == "Fullscreen":
		display()

func setup() -> void:
	if Tools.is_console_platform():
		return
	set_fullscreen(get_fullscreen())
	display()

func increase_value() -> void: #override
	if Tools.is_console_platform():
		return
	set_fullscreen(!get_fullscreen())
	display()

func decrease_value() -> void: #override
	if Tools.is_console_platform():
		return
	set_fullscreen(!get_fullscreen())
	display()


func set_fullscreen(value:bool) -> void:
	Configurations.set("Fullscreen",value)
	OS.window_fullscreen = value

func get_fullscreen() -> bool:
	if Configurations.get("Fullscreen"):
		return true
	else:
		return false

func display():
	if Configurations.get("Fullscreen"):
		display_value("ON_VALUE")
	else:
		display_value("OFF_VALUE")
