extends Node3D

const Catalog := preload("res://scripts/level_catalog.gd")
## Controla o estado da partida: menu, timer, mortes, checkpoints, pausa e vitória.

enum State { MENU, PLAYING, PAUSED, WON }

const SAVE_PATH := "user://tux_obby.cfg"
const SETTINGS_PATH := "user://tux_obby_settings.cfg"

@onready var player: TuxPlayer = $Player
@onready var level: Level = $Level
@onready var hud: Hud = $HUD

var state := State.MENU
var spawn := Vector3.ZERO
var elapsed := 0.0
var deaths := 0
var fish := 0
var current_checkpoint := 0
var respawning := false
var best_time := 0.0
var auto_pause_enabled := true
var current_level_id := 1
var level_best_times: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("game")
	_load_records()
	_load_level(_load_selected_level())

	player.died.connect(_on_player_died)

	hud.show_start(best_time)

	hud.play_pressed.connect(start_game)
	hud.resume_pressed.connect(resume_game)
	hud.restart_pressed.connect(restart_level)
	hud.quit_pressed.connect(quit_game)
	hud.levels_pressed.connect(return_to_levels)
	hud.level_chosen.connect(choose_level)

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Sfx.start_music()


func _load_level(level_id: int) -> void:
	current_level_id = clampi(level_id, 1, Catalog.count())
	level.setup(current_level_id)
	spawn = level.start_spawn
	player.respawn(spawn, 0.0)
	player.set_camera_enabled(false)
	player.set_frozen(true)
	elapsed = 0.0
	deaths = 0
	fish = 0
	current_checkpoint = 0
	respawning = false
	best_time = float(level_best_times.get(current_level_id, 0.0))
	hud.set_time(0.0)
	hud.set_deaths(0)
	hud.set_fish(0, level.total_fish)
	hud.set_checkpoint(0, level.checkpoint_spawns.size() - 1)
	hud.set_best(best_time)
	hud.set_level(current_level_id, level.level_name_key)
	hud.set_level_records(level_best_times)
	_save_selected_level()


func choose_level(level_id: int) -> void:
	if state != State.MENU:
		return
	_load_level(level_id)
	hud.hide_levels(false)
	start_game()


func return_to_levels() -> void:
	if state != State.PLAYING and state != State.PAUSED and state != State.WON:
		return
	get_tree().paused = false
	_clear_confetti()
	state = State.MENU
	respawning = false
	player.set_frozen(true)
	player.set_camera_enabled(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.hide_pause()
	hud.hide_win()
	_load_level(current_level_id)
	hud.show_levels()
	Sfx.unduck_music()
	Sfx.start_music()


func _process(delta: float) -> void:
	if state != State.PLAYING or respawning:
		return
	elapsed += delta
	hud.set_time(elapsed)
	if not player.dead and player.global_position.y < level.kill_y:
		player.kill()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if state == State.PLAYING:
			pause_game()
		elif state == State.PAUSED:
			resume_game()
		elif state == State.MENU and hud.level_overlay.visible:
			hud.hide_levels()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("quit") and (state == State.PAUSED or state == State.WON):
		quit_game()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("respawn"):
		if state == State.PLAYING:
			manual_respawn()
		elif state == State.PAUSED or state == State.WON:
			restart_level()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_accept"):
		if state == State.MENU:
			start_game()
		elif state == State.WON:
			restart_level()
		get_viewport().set_input_as_handled()
		return

	if state == State.PLAYING and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		if event is InputEventMouseButton and event.pressed:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if auto_pause_enabled and state == State.PLAYING and not respawning:
			pause_game()


# --------------------------------------------------------------------------
# Fluxo de jogo
# --------------------------------------------------------------------------

func start_game() -> void:
	if state != State.MENU:
		return
	state = State.PLAYING
	respawning = false
	hud.hide_start()
	hud.hide_pause()
	hud.hide_win()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	player.set_camera_enabled(true)
	player.unfreeze()
	Sfx.play("click", -12.0)
	Sfx.unduck_music()
	Sfx.start_music()


func pause_game() -> void:
	if state != State.PLAYING or respawning:
		return
	state = State.PAUSED
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.set_camera_enabled(false)
	hud.show_pause()
	Sfx.play("click", -12.0)
	Sfx.duck_music()


func resume_game() -> void:
	if state != State.PAUSED:
		return
	get_tree().paused = false
	state = State.PLAYING
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	player.set_camera_enabled(true)
	hud.hide_pause()
	Sfx.play("click", -12.0)
	Sfx.unduck_music()


func restart_level() -> void:
	if state != State.PLAYING and state != State.PAUSED and state != State.WON:
		return
	get_tree().paused = false
	Sfx.play("click", -10.0)
	_clear_confetti()
	_load_level(current_level_id)
	state = State.MENU
	hud.hide_pause()
	hud.hide_win()
	start_game()


func quit_game() -> void:
	get_tree().quit()


func reach_checkpoint(index: int, position: Vector3) -> void:
	if state != State.PLAYING or player.dead or respawning:
		return
	if index <= current_checkpoint:
		return
	current_checkpoint = index
	spawn = position
	hud.set_checkpoint(index, level.checkpoint_spawns.size() - 1)


func collect_fish() -> void:
	if state != State.PLAYING:
		return
	fish += 1
	hud.set_fish(fish, level.total_fish)
	if fish == level.total_fish:
		hud.notify(Loc.t("notify_all_fish"), Color("ffb03a"))


func finish() -> void:
	if state != State.PLAYING or respawning:
		return
	state = State.WON
	player.set_frozen(true)
	player.set_camera_enabled(false)
	player.model.double_jump_spin()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var new_record := best_time <= 0.0 or elapsed < best_time
	if new_record:
		best_time = elapsed
		level_best_times[current_level_id] = best_time
		_save_records()
	hud.set_best(best_time)
	hud.set_level_records(level_best_times)
	hud.show_win(elapsed, deaths, fish, level.total_fish, new_record, best_time)
	hud.fade_black(0.4, 0.0)
	Sfx.play("win", -3.0)
	Sfx.fade_out_music(1.5)
	_confetti()


func _on_player_died() -> void:
	if state != State.PLAYING or respawning:
		return
	respawning = true
	deaths += 1
	hud.set_deaths(deaths)
	hud.flash_death()
	hud.notify(Loc.t("notify_fall"), Color("ff6262"))
	await get_tree().create_timer(0.6).timeout
	if state != State.PLAYING:
		return
	hud.fade_black(0.2, 0.9)
	await get_tree().create_timer(0.24).timeout
	player.respawn(spawn, 0.0)
	hud.fade_black(0.35, 0.0)
	await get_tree().create_timer(0.18).timeout
	if state == State.PLAYING:
		player.unfreeze()
	respawning = false


func manual_respawn() -> void:
	if state != State.PLAYING or respawning or player.dead:
		return
	respawning = true
	Sfx.play("click", -12.0)
	hud.fade_black(0.18, 1.0)
	await get_tree().create_timer(0.2).timeout
	player.respawn(spawn, 0.0)
	hud.fade_black(0.3, 0.0)
	await get_tree().create_timer(0.15).timeout
	if state == State.PLAYING:
		player.unfreeze()
	respawning = false


# --------------------------------------------------------------------------
# Recordes e efeitos
# --------------------------------------------------------------------------

func _load_selected_level() -> int:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return 1
	return clampi(int(config.get_value("ui", "level", 1)), 1, Catalog.count())


func _save_selected_level() -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("ui", "level", current_level_id)
	config.save(SETTINGS_PATH)


func _record_key(level_id: int) -> String:
	return "best_time" if level_id == 1 else "best_time_%d" % level_id


func _load_records() -> void:
	level_best_times.clear()
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	for level_id in Catalog.ids():
		var value := float(config.get_value("records", _record_key(level_id), 0.0))
		if value > 0.0:
			level_best_times[level_id] = value


func _save_records() -> void:
	var config := ConfigFile.new()
	config.load(SAVE_PATH)
	for level_id in Catalog.ids():
		config.set_value("records", _record_key(level_id), float(level_best_times.get(level_id, 0.0)))
	var legacy_fish := int(config.get_value("records", "fish_total", 0))
	if current_level_id == 1:
		legacy_fish = fish
	config.set_value("records", "fish_total", legacy_fish)
	config.set_value("records", "fish_total_%d" % current_level_id, fish)
	config.save(SAVE_PATH)


func _confetti() -> void:
	var colors := [Color("5cf0cc"), Color("ffb03a"), Color("ff7f6e"), Color("b8ef63")]
	for i in colors.size():
		var particles := CPUParticles3D.new()
		particles.one_shot = true
		particles.emitting = false
		particles.amount = 48
		particles.lifetime = 2.6
		particles.explosiveness = 1.0
		particles.direction = Vector3(0, 1, 0)
		particles.spread = 70.0
		particles.initial_velocity_min = 6.0
		particles.initial_velocity_max = 13.0
		particles.gravity = Vector3(0, -11.0, 0)
		particles.scale_amount_min = 0.6
		particles.scale_amount_max = 1.4
		particles.angular_velocity_min = -220.0
		particles.angular_velocity_max = 220.0
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.12, 0.16, 0.02)
		particles.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = colors[i]
		mat.emission_enabled = true
		mat.emission = colors[i]
		mat.emission_energy_multiplier = 1.4
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		particles.material_override = mat
		particles.position = player.global_position + Vector3((i - 1.5) * 0.9, 2.0, 0)
		particles.add_to_group("confetti")
		add_child(particles)
		particles.emitting = true
		get_tree().create_timer(4.0).timeout.connect(particles.queue_free)


func _clear_confetti() -> void:
	for node in get_tree().get_nodes_in_group("confetti"):
		node.queue_free()
