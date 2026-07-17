extends Node

# The Godot 3 UWP template renders through an old ANGLE backend. Replace the
# shaders that use dynamic loops, roundEven and functions with out parameters
# by equivalent, conservative canvas shaders only in UWP builds.

var _charge_shader := Shader.new()
var _enemy_shader := Shader.new()
var _palette_shader := Shader.new()
var _replaced := 0
var _particle_bridges := []
var _charge_spirals := {}
var _charge_spiral_script := preload("res://src/System/UWPChargeSpiral.gd")
var _sprite_explosion_script := preload("res://src/System/UWPSpriteExplosion.gd")
var _explosion_sequence_script := preload("res://src/System/UWPExplosionSequence.gd")
var _explosion_texture := preload("res://src/Effects/Textures/explosion.png")
var _active := false
var _log_path := "user://uwp_diagnostics.log"

func _ready() -> void:
	_active = _should_run()
	if not _active:
		return
	_clear_log()
	diag("ready os=%s uwp_feature=%s" % [OS.get_name(), str(OS.has_feature("UWP"))])
	_create_fallback_shaders()
	get_tree().connect("node_added", self, "_on_node_added")
	_replace_incompatible_materials(get_tree().root)
	diag("shader fallback enabled materials=%d" % _replaced)
	print("UWP compatibility: ANGLE shader fallback enabled (%d materials)." % _replaced)
	set_process(true)

func _process(_delta: float) -> void:
	for index in range(_particle_bridges.size() - 1, -1, -1):
		var bridge: Dictionary = _particle_bridges[index]
		var gpu = bridge.gpu
		var cpu = bridge.cpu
		if not is_instance_valid(gpu):
			if is_instance_valid(cpu):
				cpu.queue_free()
			_particle_bridges.remove(index)
			continue
		if not is_instance_valid(cpu):
			_particle_bridges.remove(index)
			continue
		cpu.transform = gpu.transform
		cpu.visible = gpu.visible
		cpu.modulate = gpu.modulate
		cpu.z_index = gpu.z_index
		cpu.z_as_relative = gpu.z_as_relative
		if gpu.emitting != bridge.was_emitting:
			if gpu.emitting:
				cpu.restart()
			cpu.emitting = gpu.emitting
			bridge.was_emitting = gpu.emitting
			_particle_bridges[index] = bridge

func set_charge_spiral_visible(source: Node, is_visible: bool) -> void:
	if not _active:
		return
	if not is_instance_valid(source):
		return
	var key = source.get_instance_id()
	if not _charge_spirals.has(key):
		if source is Particles2D:
			_create_charge_spiral(source)
		else:
			return
	if _charge_spirals.has(key) and is_instance_valid(_charge_spirals[key]):
		_charge_spirals[key].set_active(is_visible)
		diag("charge spiral visible source=%s visible=%s source_visible=%s z=%s" % [source.name, str(is_visible), str(source.visible), str(source.z_index)])

func spawn_explosion_burst(world_position: Vector2, amount := 15, spread := 25.0, duration := 0.6, size_scale := 1.0, delay := 0.0, texture_override = null) -> void:
	if not _active:
		return
	if delay > 0.0:
		var timer := Timer.new()
		timer.one_shot = true
		timer.wait_time = delay
		timer.connect("timeout", self, "_on_delayed_explosion_burst", [timer, world_position, amount, spread, duration, size_scale, texture_override])
		var timer_parent := get_tree().current_scene
		if not timer_parent:
			timer_parent = get_tree().root
		timer_parent.add_child(timer)
		timer.start()
		return
	duration = max(duration, 0.55)
	amount = max(amount, 1)
	diag("spawn explosion burst pos=%s amount=%d spread=%.2f duration=%.2f scale=%.2f" % [str(world_position), amount, spread, duration, size_scale])
	var root := get_tree().current_scene
	if not root:
		root = get_tree().root
	for i in range(amount):
		var part := Node2D.new()
		part.set_script(_sprite_explosion_script)
		root.add_child(part)
		part.set("texture", texture_override if texture_override else _explosion_texture)
		part.global_position = world_position + Vector2(rand_range(-spread, spread), rand_range(-spread, spread))
		part.z_as_relative = false
		part.z_index = 100
		part.set("velocity", Vector2(rand_range(-85.0, 85.0), rand_range(-65.0, 65.0)) * size_scale)
		part.set("lifetime", duration)
		part.set("size_scale", size_scale)

func _on_delayed_explosion_burst(timer: Timer, world_position: Vector2, amount: int, spread: float, duration: float, size_scale: float, texture_override) -> void:
	if is_instance_valid(timer):
		timer.queue_free()
	spawn_explosion_burst(world_position, amount, spread, duration, size_scale, 0.0, texture_override)

func spawn_explosion_sequence(source: Node2D, particle_amount: int, spread: float, total_duration: float, size_scale := 1.0, particle_lifetime := 2.0, texture_override = null) -> void:
	if not _active or not is_instance_valid(source):
		return
	if total_duration <= 0.1:
		spawn_explosion_burst(source.global_position, min(max(particle_amount, 1), 5), spread, 0.55, size_scale, 0.0, texture_override)
		return
	var sequence := Node.new()
	sequence.name = "UWP Explosion Sequence"
	sequence.set_script(_explosion_sequence_script)
	sequence.set("compatibility", self)
	sequence.set("source", source)
	sequence.set("world_position", source.global_position)
	sequence.set("spread", spread)
	sequence.set("total_duration", total_duration)
	sequence.set("size_scale", size_scale)
	sequence.set("texture", texture_override if texture_override else _explosion_texture)
	var emission_rate := clamp(float(max(particle_amount, 1)) / max(particle_lifetime, 0.1), 1.0, 14.0)
	sequence.set("emission_rate", emission_rate)
	sequence.set("max_explosions", min(int(ceil(emission_rate * total_duration)), 160))
	var root := get_tree().current_scene
	if not root:
		root = get_tree().root
	root.call_deferred("add_child", sequence)
	diag("spawn explosion sequence source=%s amount=%d rate=%.2f duration=%.2f spread=%.2f scale=%.2f" % [source.name, particle_amount, emission_rate, total_duration, spread, size_scale])

func is_active() -> bool:
	return _active

func diag(message: String) -> void:
	if not _active:
		return
	var file := File.new()
	if file.open(_log_path, File.READ_WRITE) != OK:
		return
	file.seek_end()
	file.store_line("[%d] %s" % [OS.get_ticks_msec(), message])
	file.close()

func _clear_log() -> void:
	var file := File.new()
	if file.open(_log_path, File.WRITE) == OK:
		file.store_line("Mega Man X8 UWP diagnostics")
		file.close()

func _should_run() -> bool:
	if OS.get_environment("MMX_UWP_COMPAT_TEST") == "1":
		return true
	if OS.has_feature("editor"):
		return false
	if OS.has_feature("UWP") or OS.get_name() == "UWP":
		return true
	return true

func _create_fallback_shaders() -> void:
	_charge_shader.code = """shader_type canvas_item;
uniform float Flash = 0.0;
uniform float Charge = 0.0;
uniform vec4 Color : hint_color = vec4(1.0);
uniform float Alpha = 1.0;
uniform vec4 MainColor1 : hint_color = vec4(0.0);
uniform vec4 MainColor2 : hint_color = vec4(0.0);
uniform vec4 MainColor3 : hint_color = vec4(0.0);
uniform vec4 MainColor4 : hint_color = vec4(0.0);
uniform vec4 MainColor5 : hint_color = vec4(0.0);
uniform vec4 MainColor6 : hint_color = vec4(0.0);
uniform vec4 R_MainColor1 : hint_color = vec4(0.0);
uniform vec4 R_MainColor2 : hint_color = vec4(0.0);
uniform vec4 R_MainColor3 : hint_color = vec4(0.0);
uniform vec4 R_MainColor4 : hint_color = vec4(0.0);
uniform vec4 R_MainColor5 : hint_color = vec4(0.0);
uniform vec4 R_MainColor6 : hint_color = vec4(0.0);
uniform vec4 CrystalColor1 : hint_color = vec4(0.0);
uniform vec4 CrystalColor2 : hint_color = vec4(0.0);
uniform vec4 CrystalColor3 : hint_color = vec4(0.0);
uniform vec4 R_CrystalColor1 : hint_color = vec4(0.0);
uniform vec4 R_CrystalColor2 : hint_color = vec4(0.0);
uniform vec4 R_CrystalColor3 : hint_color = vec4(0.0);
uniform float Alert = 0.0;
uniform float tolerance = 0.01;

bool same_color(vec3 a, vec3 b) {
	vec3 diff = abs(a - b);
	return max(max(diff.r, diff.g), diff.b) <= tolerance;
}

vec3 swap_color(vec3 source) {
	float alert_pulse = mix(1.0, cos(TIME * 8.5) + 1.4, clamp(Alert * 1.5, 0.0, 1.0));
	if (same_color(source, CrystalColor1.rgb)) { return R_CrystalColor1.rgb * alert_pulse; }
	if (same_color(source, CrystalColor2.rgb)) { return R_CrystalColor2.rgb * alert_pulse; }
	if (same_color(source, CrystalColor3.rgb)) { return R_CrystalColor3.rgb * alert_pulse; }
	if (same_color(source, MainColor1.rgb)) { return R_MainColor1.rgb; }
	if (same_color(source, MainColor2.rgb)) { return R_MainColor2.rgb; }
	if (same_color(source, MainColor3.rgb)) { return R_MainColor3.rgb; }
	if (same_color(source, MainColor4.rgb)) { return R_MainColor4.rgb; }
	if (same_color(source, MainColor5.rgb)) { return R_MainColor5.rgb; }
	if (same_color(source, MainColor6.rgb)) { return R_MainColor6.rgb; }
	return source;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec3 base = swap_color(tex.rgb);
	float pulse = step(0.5, abs(cos(TIME * 42.0)) - 0.3);
	float dark_mask = step(dot(base, vec3(0.333333)), 0.3);
	vec3 charged = max(base, min(Color.rgb, vec3(dark_mask)));
	vec3 color = mix(base, charged, clamp(Charge * pulse, 0.0, 1.0));
	color = mix(color, vec3(1.0), clamp(Flash, 0.0, 1.0));
	COLOR = vec4(color, tex.a * Alpha) * COLOR;
}"""

	_enemy_shader.code = """shader_type canvas_item;
uniform float Flash = 0.0;
uniform float Should_Blink = 0.0;
uniform float Darken = 1.0;
uniform float Alpha = 1.0;
uniform float Alpha_Blink = 0.0;
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float flash_pulse = step(0.5, abs(cos(TIME * 42.0)) - 0.3);
	float flash_amount = clamp(Flash * mix(1.0, flash_pulse, clamp(Should_Blink, 0.0, 1.0)), 0.0, 1.0);
	float dark_mask = step(dot(tex.rgb, vec3(0.333333)), 0.3);
	vec3 flash_color = max(tex.rgb, vec3(0.72, 0.97, 1.0) * dark_mask);
	vec3 color = mix(tex.rgb, flash_color, flash_amount) * Darken;
	float blink_gate = mix(1.0, step(0.5, abs(cos(TIME * 60.0)) - 0.3), clamp(Alpha_Blink, 0.0, 1.0));
	COLOR = vec4(color, tex.a * max(Alpha, 0.0) * blink_gate) * COLOR;
}"""

	_palette_shader.code = """shader_type canvas_item;
uniform sampler2D palette;
uniform bool skip_first_row = true;
uniform bool use_palette_alpha = false;
uniform float fps = 6.0;
uniform float palette_columns = 16.0;
uniform float palette_rows = 16.0;
void fragment() {
	vec4 original = texture(TEXTURE, UV);
	ivec3 source_color = ivec3(floor(original.rgb * 255.0 + vec3(0.5)));
	float columns = max(palette_columns, 1.0);
	float rows_total = max(palette_rows, 1.0);
	float index = -1.0;
	for (int i = 0; i < 256; i++) {
		if (float(i) >= columns) { break; }
		vec3 sample_color = texture(palette, vec2(float(i) / max(columns - 1.0, 1.0), 0.0)).rgb;
		ivec3 candidate = ivec3(floor(sample_color * 255.0 + vec3(0.5)));
		if (all(equal(source_color, candidate))) { index = float(i); break; }
	}
	if (index >= 0.0) {
		float first_row = float(skip_first_row);
		float rows = max((rows_total - 1.0) - first_row, 1.0);
		vec2 palette_uv = vec2(index / max(columns - 1.0, 1.0),
			(mod(TIME * fps, rows) + first_row) / max(rows_total - 1.0, 1.0));
		vec4 replacement = texture(palette, palette_uv);
		COLOR = vec4(replacement.rgb, mix(original.a, replacement.a, float(use_palette_alpha))) * COLOR;
	} else {
		COLOR = original * COLOR;
	}
}"""

func _on_node_added(node: Node) -> void:
	_disable_shader_cache(node)
	_replace_incompatible_material(node)
	_prepare_cpu_particles(node)

func _replace_incompatible_materials(node: Node) -> void:
	_replace_incompatible_material(node)
	_prepare_cpu_particles(node)
	for child in node.get_children():
		_replace_incompatible_materials(child)

func _prepare_cpu_particles(node: Node) -> void:
	if !(node is Particles2D) or node.has_meta("uwp_cpu_bridge"):
		return
	if _belongs_to_shader_cache(node):
		return
	if _is_charge_particle(node):
		_create_charge_spiral(node)
		return
	node.set_meta("uwp_cpu_bridge", true)
	call_deferred("_create_cpu_particle_bridge", node)

func _belongs_to_shader_cache(node: Node) -> bool:
	var current := node
	while is_instance_valid(current):
		if current.has_meta("shader_cache_only"):
			return true
		var script = current.get_script()
		if script and script.resource_path == "res://addons/gd-shader-cache/src/ShaderCache.gd":
			return true
		current = current.get_parent()
	return false

func _disable_shader_cache(node: Node) -> void:
	var script = node.get_script()
	if not script or script.resource_path != "res://addons/gd-shader-cache/src/ShaderCache.gd":
		return
	if "active" in node:
		node.set("active", false)
	node.visible = false
	node.set_process(false)
	diag("disabled scene shader cache node=%s" % node.name)

func _is_charge_particle(node: Node) -> bool:
	return node.name == "ChargingParticle" or node.name == "ChargedParticle" or node.name == "SuperChargeParticle"

func _create_charge_spiral(gpu: Particles2D) -> void:
	if gpu.has_meta("uwp_charge_spiral"):
		return
	gpu.set_meta("uwp_charge_spiral", true)
	var spiral := Node2D.new()
	spiral.name = gpu.name + " UWP Spiral"
	spiral.set_script(_charge_spiral_script)
	var root := get_tree().current_scene
	if not root:
		root = get_tree().root
	root.call_deferred("add_child", spiral)
	spiral.set("source", gpu)
	spiral.set("texture", gpu.texture)
	if gpu.name == "ChargedParticle":
		spiral.set("color", Color(1.0, 0.92, 0.35, 1.0))
		spiral.set("radius", 13.0)
		spiral.set("speed", 10.0)
	elif gpu.name == "SuperChargeParticle":
		spiral.set("color", Color(1.0, 1.0, 1.0, 1.0))
		spiral.set("radius", 15.0)
		spiral.set("speed", 12.0)
	_charge_spirals[gpu.get_instance_id()] = spiral
	diag("created charge spiral source=%s texture=%s parent=%s visible=%s global=%s" % [gpu.name, str(gpu.texture), gpu.get_parent().name, str(gpu.visible), str(gpu.global_position)])

func _create_cpu_particle_bridge(gpu: Particles2D) -> void:
	if not is_instance_valid(gpu) or not is_instance_valid(gpu.get_parent()):
		return
	var cpu := CPUParticles2D.new()
	cpu.name = gpu.name + " UWP CPU"
	cpu.convert_from_particles(gpu)
	cpu.texture = gpu.texture
	cpu.material = gpu.material
	gpu.get_parent().add_child(cpu)
	cpu.transform = gpu.transform
	cpu.visible = gpu.visible
	cpu.modulate = gpu.modulate
	cpu.self_modulate = gpu.self_modulate
	cpu.z_index = gpu.z_index
	cpu.z_as_relative = gpu.z_as_relative
	var hidden_color := gpu.self_modulate
	hidden_color.a = 0.0
	gpu.self_modulate = hidden_color
	if gpu.emitting:
		cpu.restart()
		cpu.emitting = true
	_particle_bridges.append({"gpu": gpu, "cpu": cpu, "was_emitting": gpu.emitting})

func _replace_incompatible_material(node: Node) -> void:
	if !(node is CanvasItem) or !(node.material is ShaderMaterial):
		return
	var material := node.material as ShaderMaterial
	if not material.shader:
		return
	_configure_palette_size(material)
	match material.shader.resource_path:
		"res://src/Actors/charge_shader.tres":
			material.shader = _charge_shader
			_replaced += 1
		"res://src/Effects/enemy_shader.tres":
			material.shader = _enemy_shader
			_replaced += 1
		"res://addons/PaletteSwap/PaletteSwap.gdshader":
			# The original waterfall does not scroll its texture. Its apparent
			# downward flow comes from cycling waterfall_palette.png at 24 FPS.
			# Use the same palette path for UWP so direction and cadence match.
			material.shader = _palette_shader
			_configure_palette_size(material)
			_replaced += 1

func _configure_palette_size(material: ShaderMaterial) -> void:
	if not material:
		return
	var palette = material.get_shader_param("palette")
	if palette and palette is Texture:
		var size: Vector2 = palette.get_size()
		material.set_shader_param("palette_columns", max(size.x, 1.0))
		material.set_shader_param("palette_rows", max(size.y, 1.0))
