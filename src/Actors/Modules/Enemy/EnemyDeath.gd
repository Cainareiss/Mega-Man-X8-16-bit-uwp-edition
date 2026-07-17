extends BaseAbility
class_name EnemyDeath

onready var explosions = $"Explosion Particles"
onready var sprite = get_parent().get_node("animatedSprite")
onready var death_particle = $"Remains"
export var should_spawn_item := true
export var should_emit_kill_signal := true
export var explosion_duration:= 2.0
var times_sound_played := 0.0
onready var audioplayer: AudioStreamPlayer2D = $audioStreamPlayer2D

func _ready() -> void:
	if active:
		character.listen("zero_health",self,"_on_zero_health")
		death_particle.emitting = false
		death_particle.get_node("remains_particles").emitting = false

func particle_cache_check() -> void:
	var checklist = [$"Explosion Particles", $Remains, $Remains.get_node("remains_particles")]
	for item in checklist:
		if item and item.process_material.resource_name == "":
			print("...")
			print("Checking for " + name + " in " + get_parent().name)
			print(item.process_material.resource_name)
	

func _Setup():
	if has_node("/root/UWPCompatibility") and get_node("/root/UWPCompatibility").is_active():
		get_node("/root/UWPCompatibility").diag("EnemyDeath.setup enemy=%s hp=%.2f pos=%s explosion_amount=%d" % [character.name, character.current_health, str(global_position), int(explosions.amount)])
	if explosion_duration == 0:
		audioplayer.play()
	if should_emit_kill_signal:
		Event.emit_signal("enemy_kill",character)
	explosions.emitting = true
	if has_node("/root/UWPCompatibility") and get_node("/root/UWPCompatibility").is_active():
		var quick_death := explosion_duration <= 0.05
		var fallback_amount := 5 if quick_death else int(explosions.amount)
		var fallback_spread := 9.0 if quick_death else get_explosion_spread(25.0)
		var fallback_scale := 0.42 if quick_death else 1.0
		get_node("/root/UWPCompatibility").spawn_explosion_sequence(self, fallback_amount, fallback_spread, explosion_duration, fallback_scale, explosions.lifetime, explosions.texture)
	sprite.playing = false
	sprite.material.set_shader_param("Alpha_Blink", 1)
	extra_actions_at_death_start()

func _StartCondition() -> bool:
	return false

func _Update(_delta):
	if timer > times_sound_played/5 and timer < explosion_duration:
		times_sound_played += 1
		var audio = audioplayer.duplicate()
		add_child(audio)
		audio.pitch_scale = rand_range(0.95,1.05)
		audio.play()
	if timer > explosion_duration:
		if explosions.emitting:
			spawn_item()
			emit_remains_particles()
			character.emit_signal("death")
			extra_actions_after_death()
			explosions.emitting = false
		sprite.visible = false


func extra_actions_after_death() -> void: #override
	pass
func extra_actions_at_death_start() -> void: #override
	pass

func _EndCondition() -> bool:
	return timer > explosion_duration + 1

func spawn_item():
	if should_spawn_item:
		var item = get_spawn_item()
		if item:
			instance_item(item)

func instance_item(item) -> void:
	item = item.instance()
	item.expirable = true
	get_parent().get_parent().add_child(item)
	item.global_position = Vector2(round(global_position.x), round(global_position.y))
	item.velocity.y = -200

func get_spawn_item():
	return GameManager.get_next_spawn_item()

func _Interrupt():
	get_parent().queue_free()
	sprite.material.set_shader_param("Alpha_Blink", 0)
	
func _on_zero_health() -> void:
	Log("heard zero health event")
	if has_node("/root/UWPCompatibility") and get_node("/root/UWPCompatibility").is_active():
		get_node("/root/UWPCompatibility").diag("EnemyDeath.zero_health enemy=%s executing=%s visible=%s hp=%.2f" % [character.name, str(executing), str(sprite.visible), character.current_health])
	if not executing:
		character.interrupt_all_moves()
		ExecuteOnce()

func emit_remains_particles():
	if GameManager.is_on_screen(global_position) and death_particle:
		var particle = death_particle.duplicate()
		character.get_parent().add_child(particle)
		particle.global_transform = character.global_transform
		particle.start()

func get_explosion_spread(default_spread := 25.0) -> float:
	if explosions and explosions.process_material is ParticlesMaterial:
		var radius := float(explosions.process_material.emission_sphere_radius)
		if radius > 0.0:
			return clamp(radius, 8.0, 90.0)
	return default_spread
