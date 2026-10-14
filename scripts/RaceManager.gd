extends Node3D
## Owns one race: builds the track, spawns racers, runs the distance goal,
## checkpoints, camera, HUD, environment and results.

signal exit_to_menu
signal next_level(level: int, car_index: int)

var level: int = 1
var car_index: int = 0

var track: Dictionary = {}
var curve: Curve3D
var curve_length: float = 1.0
var road_width: float = 14.0

var player: CarController
var ai_drivers: Array[AIDriver] = []
var checkpoints: Array[Area3D] = []
var next_cp: int = 1
var lap: int = 1
var total_laps: int = 3
var target_distance: float = 1000.0
var race_time: float = 0.0
var racing: bool = false
var finished: bool = false
var race_position: int = 1
var lobby: bool = true
var _menu_overlay: Node = null

var camera: Camera3D
var hud: HUD
var _environment: Environment
var _sun: DirectionalLight3D
var _cam_mode: int = 0
var _look: Vector3 = Vector3.ZERO
var _shake: float = 0.0
var _prev_speed: float = 0.0
var _distance_accum: float = 0.0
var _progress_m: float = 0.0
var _last_offset: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_world()
	_build_racers()
	_build_checkpoints()
	_build_camera()
	_build_hud()
	# seamless start-line lobby: the cars sit on the grid until the player holds
	racing = false
	player.can_drive = false
	hud.set_lobby(true)
	if OS.has_feature("web"):
		var q: Variant = JavaScriptBridge.eval("window.location.search", true)
		if typeof(q) == TYPE_STRING and String(q).contains("auto=1"):
			_start_race()

func _build_world() -> void:
	var difficulty: float = clampf(float(level - 1) / 45.0, 0.0, 1.0)
	target_distance = minf(900.0 + float(level - 1) * 180.0, 4500.0)
	var theme_index: int = posmod(level - 1, TrackGenerator.theme_count())
	var seed_val: int = int(abs((level * 2654435761) % 2147483647))
	track = TrackGenerator.generate(seed_val, theme_index, difficulty)
	add_child(track["node"])
	curve = track["curve"]
	curve_length = float(track["length"])
	road_width = float(track["road_width"])
	total_laps = maxi(2, int(ceil(target_distance / maxf(1.0, curve_length))))

	var theme: Dictionary = track["theme"]
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var skm := ProceduralSkyMaterial.new()
	skm.sky_top_color = theme["sky_top"]
	skm.sky_horizon_color = theme["sky_horizon"]
	skm.ground_bottom_color = theme["ground"]
	skm.ground_horizon_color = theme["ground"]
	skm.sun_angle_max = 25.0
	skm.sun_curve = 0.15
	skm.energy_multiplier = 1.0
	sky.sky_material = skm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.28
	env.fog_enabled = true
	env.fog_light_color = theme["fog"]
	env.fog_density = 0.0018
	env.glow_enabled = true
	env.glow_intensity = 0.18
	env.glow_bloom = 0.12
	env.glow_hdr_threshold = 1.5
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.62
	env.fog_enabled = true
	env.fog_light_color = theme["fog"]
	env.fog_light_energy = 0.9
	env.fog_density = 0.008
	env.fog_aerial_perspective = 0.15
	env.fog_sky_affect = 0.25
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.18
	env.adjustment_contrast = 1.08
	env.adjustment_brightness = 1.02
	we.environment = env
	add_child(we)
	_environment = env

	var sun := DirectionalLight3D.new()
	sun.light_color = theme["sun"]
	sun.light_energy = 1.05
	sun.rotation_degrees = Vector3(-52, -35, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 180.0
	sun.shadow_bias = 0.05
	sun.shadow_normal_bias = 1.5
	sun.light_angular_distance = 0.6
	add_child(sun)
	_sun = sun
	_apply_quality()

func _apply_quality() -> void:
	if _sun != null:
		_sun.shadow_enabled = GameState.quality >= 1
	if _environment != null:
		_environment.glow_enabled = GameState.quality >= 2
		_environment.fog_enabled = GameState.quality >= 1
	var msaa: int = [0, 1, 2][clampi(GameState.quality, 0, 2)]
	get_viewport().msaa_3d = msaa as Viewport.MSAA

func _build_racers() -> void:
	player = CarController.new()
	player.name = "Player"
	add_child(player)
	player.configure(car_index)
	var start: Transform3D = track["start"]
	# the track's -Z runs along the racing line; the car drives along +Z,
	# so rotate the spawn 180 deg to face down the track
	start.basis = start.basis.rotated(Vector3.UP, PI)
	player.global_transform = start
	player.last_checkpoint = start
	_last_offset = curve.get_closest_offset(start.origin)
	_progress_m = 0.0

	var difficulty: float = clampf(float(level - 1) / 45.0, 0.0, 1.0)
	var ai_count: int = 3 + int(round(difficulty * 4.0))
	var base_speed: float = lerpf(26.0, 34.0, difficulty)
	for i in range(ai_count):
		var ai := AIDriver.new()
		add_child(ai)
		var start_dist: float = -12.0 - float(i) * 7.0 + curve_length
		var lane: float = road_width * 0.22 * (1.0 if i % 2 == 0 else -1.0)
		var spd: float = base_speed * randf_range(0.9, 1.12)
		ai.configure((car_index + 7 + i * 13) % CarFactory.TOTAL_CARS, curve, start_dist, spd, lane)
		ai_drivers.append(ai)

func _build_checkpoints() -> void:
	var cps: Array = track["checkpoints"]
	for i in range(cps.size()):
		var t: Transform3D = cps[i]
		var area := Area3D.new()
		area.transform = t
		area.monitoring = true
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(road_width + 8.0, 7.0, 1.5)
		cs.shape = box
		area.add_child(cs)
		area.body_entered.connect(_on_checkpoint_entered.bind(i))
		add_child(area)
		checkpoints.append(area)

func _build_camera() -> void:
	camera = Camera3D.new()
	camera.fov = 74.0
	add_child(camera)
	camera.current = true
	camera.global_position = player.global_position - player.global_transform.basis.z * 8.5 + Vector3.UP * 4.0
	_look = player.global_position + Vector3.UP * 1.2

func _build_hud() -> void:
	hud = HUD.new()
	add_child(hud)
	hud.set_level(level)
	hud.retry_requested.connect(_on_retry)
	hud.next_requested.connect(_on_next)
	hud.menu_requested.connect(_on_menu)
	hud.resume_requested.connect(_on_resume)
	hud.ride_requested.connect(_start_race)
	hud.garage_requested.connect(func(): _open_menu("garage"))
	hud.levels_requested.connect(func(): _open_menu("levels"))
	hud.settings_requested.connect(func(): _open_menu("settings"))

func _start_race() -> void:
	if not lobby:
		return
	lobby = false
	racing = true
	player.can_drive = true
	hud.set_lobby(false)
	hud.flash("GO!")

func _open_menu(panel: String) -> void:
	if _menu_overlay != null and is_instance_valid(_menu_overlay):
		_menu_overlay.show_panel(panel)
		return
	var MS: GDScript = load("res://scripts/Menu.gd")
	_menu_overlay = MS.new()
	_menu_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_menu_overlay)
	_menu_overlay.show_panel(panel)
	_menu_overlay.quit_requested.connect(_close_menu)
	_menu_overlay.start_level.connect(func(l, c):
		_close_menu()
		next_level.emit(l, c))
	get_tree().paused = true

func _close_menu() -> void:
	get_tree().paused = false
	if _menu_overlay != null and is_instance_valid(_menu_overlay):
		_menu_overlay.queue_free()
	_menu_overlay = null

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("pause"):
		_toggle_pause()
		return
	if get_tree().paused:
		return

	if Input.is_action_just_pressed("camera_change"):
		_cam_mode = (_cam_mode + 1) % 2

	if racing and not finished:
		race_time += delta
		_distance_accum += player.linear_velocity.length() * delta
		_update_progress()
		_update_ranking()
		var prog: float = _progress()
		hud.set_progress(prog, target_distance)
		hud.update_state(player.speed_kmh(), lap, total_laps, race_time, race_position, ai_drivers.size() + 1)
		hud.set_speed(player.speed_kmh(), float(player.stats.get("top_speed_kmh", 300.0)))
		hud.set_nitro(player.nitro_charge)
		var top: float = maxf(80.0, float(player.stats.get("top_speed_kmh", 240.0)))
		var sl: float = clampf((player.speed_kmh() / top - 0.2) / 0.5, 0.0, 1.0)
		if player.nitro_active:
			sl = minf(1.0, sl + 0.35)
		hud.set_speedlines(sl)
		if prog >= target_distance:
			_finish()

	var spd: float = player.speed_kmh()
	if spd < _prev_speed - 35.0:
		_shake = minf(0.6, _shake + 0.35)
	_prev_speed = spd
	_shake = maxf(0.0, _shake - delta * 1.6)

	_update_camera(delta)

func _update_camera(delta: float) -> void:
	if camera == null or player == null:
		return
	var basis: Basis = player.global_transform.basis
	var target: Vector3 = player.global_transform.origin
	var speed_ratio: float = clampf(player.speed_kmh() / 300.0, 0.0, 1.0)
	var desired: Vector3
	var look: Vector3
	if _cam_mode == 0:
		desired = target - basis.z * lerpf(8.5, 10.0, speed_ratio) + Vector3.UP * 3.6
		look = target + Vector3.UP * 1.2
	else:
		desired = target - basis.z * 0.4 + Vector3.UP * 1.35
		look = target + basis.z * 20.0 + Vector3.UP * 1.2
	camera.global_position = camera.global_position.lerp(desired, clampf(delta * 6.0, 0.0, 1.0))
	_look = _look.lerp(look, clampf(delta * 7.0, 0.0, 1.0))
	if camera.global_position.distance_to(_look) > 0.05:
		camera.look_at(_look)
	camera.fov = lerpf(camera.fov, lerpf(70.0, 90.0, speed_ratio), clampf(delta * 3.0, 0.0, 1.0))
	camera.rotate_object_local(Vector3.FORWARD, -player.steering * 0.22)
	var sh: float = 0.0
	if GameState.shake_enabled:
		sh = _shake * 0.03 + speed_ratio * 0.0015
	camera.h_offset = randf_range(-sh, sh)
	camera.v_offset = randf_range(-sh, sh)

func _progress() -> float:
	return _progress_m

func _update_progress() -> void:
	var off: float = curve.get_closest_offset(player.global_position)
	var d: float = off - _last_offset
	if d > curve_length * 0.5:
		d -= curve_length
	elif d < -curve_length * 0.5:
		d += curve_length
	_progress_m = maxf(0.0, _progress_m + d)
	_last_offset = off

func _update_ranking() -> void:
	var player_prog: float = _progress_m
	var p: int = 1
	for ai in ai_drivers:
		if ai.progress() > player_prog:
			p += 1
	race_position = p

func _on_checkpoint_entered(body: Node3D, index: int) -> void:
	if not racing or finished:
		return
	if body != player:
		return
	if index != next_cp:
		return
	if index == 0:
		lap += 1
		next_cp = 1
		hud.flash("LAP %d" % lap)
	else:
		next_cp = (index + 1) % checkpoints.size()

func _finish() -> void:
	finished = true
	racing = false
	player.can_drive = false
	var stars_earned := _compute_stars()
	GameState.add_distance(_distance_accum)
	GameState.register_level_complete(level, race_time, stars_earned)
	hud.show_results(race_time, stars_earned, level)

func _compute_stars() -> int:
	var par: float = target_distance / 26.0
	var s: int = 1
	if race_position <= 3:
		s = 2
	if race_position == 1:
		s = 3
	if race_time < par * 0.85 and s < 3:
		s += 1
	return clampi(s, 1, 3)

func _toggle_pause() -> void:
	var p: bool = not get_tree().paused
	get_tree().paused = p
	if p:
		hud.show_pause()
	else:
		hud.hide_pause()

func _on_resume() -> void:
	get_tree().paused = false
	hud.hide_pause()

func _on_retry() -> void:
	get_tree().paused = false
	next_level.emit(level, car_index)

func _on_next() -> void:
	get_tree().paused = false
	next_level.emit(level + 1, car_index)

func _on_menu() -> void:
	get_tree().paused = false
	exit_to_menu.emit()
