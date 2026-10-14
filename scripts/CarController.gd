class_name CarController
extends RigidBody3D
## Arcade car built on RigidBody3D + 4 RayCast3D suspension (not VehicleBody3D),
## following the Asphalt-style design: it will not flip on its own, it drifts on
## command, it has a two-state nitro boost and air stabilisation for jumps.
##
## Forward is +Z (the direction the Kenney models face).
## Also owns the VFX: underglow, headlights, brake lights, nitro flames,
## tyre smoke, skid marks and a speed trail.

# ---------------------------------------------------------------- tuning
const SPRING_REST := 0.55
const SPRING_STIFF := 62000.0
const SPRING_DAMP := 2600.0
const ENGINE_POWER := 3200.0          # force per wheel
const MAX_SPEED := 62.0               # m/s (~223 km/h)
const STEER_MAX := deg_to_rad(32.0)
const STEER_SPEED := 8.0
const GRIP := 0.94
const DRIFT_GRIP := 0.52
const NITRO_MULT := 1.5
const NITRO_DRAIN := 30.0
const NITRO_REGEN := 14.0
const NITRO_MAX := 100.0
const AIR_TORQUE := 14000.0

# ---------------------------------------------------------------- state
var car_index: int = 0
var stats: Dictionary = {}
var max_steer: float = STEER_MAX
var last_checkpoint: Transform3D
var can_drive: bool = true

var nitro_charge: float = NITRO_MAX
var nitro_active: bool = false
var steering: float = 0.0
var is_drifting: bool = false
var is_grounded: bool = false

var _rays: Array[RayCast3D] = []
var _wheel_visuals: Array = []        # [{node, radius}]
var _offsets: Array[Vector3] = []     # wheel x/z in car space
var _front: Array[bool] = []
var _wheel_r: float = 0.35
var _size: Vector3 = Vector3(1.8, 1.3, 4.3)
var _steer_angle: float = 0.0

var _body_holder: Node3D
var _brake_mat: StandardMaterial3D
var _brake_light: OmniLight3D
var _smoke: GPUParticles3D
var _flames: GPUParticles3D
var _trail: GPUParticles3D
var _engine_player: AudioStreamPlayer
var _screech_player: AudioStreamPlayer
var _nitro_player: AudioStreamPlayer
var _nitro_played: bool = false

var _skid: MultiMeshInstance3D
var _skid_idx: int = 0
const SKID_MAX := 400

# ---------------------------------------------------------------- build

func configure(index: int) -> void:
	car_index = index
	var data: Dictionary = CarFactory.build_car(index)
	stats = data.stats
	_size = data.collision_size
	add_child(data.body)
	_body_holder = data.body

	mass = float(stats.mass)
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, -0.25, 0)
	angular_damp = 3.0
	linear_damp = 0.05
	continuous_cd = true

	# chassis collider, lifted so it never scrapes the ground
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(_size.x * 0.95, _size.y * 0.9, _size.z * 0.95)
	col.shape = box
	col.position = Vector3(0, 0.2 + box.size.y * 0.5, 0)
	add_child(col)

	# wheels + suspension rays
	for w in data.wheels:
		var pos: Vector3 = w["pos"]
		_wheel_r = float(w["radius"])
		_offsets.append(Vector3(pos.x, 0.0, pos.z))
		_front.append(pos.z > 0.0)   # Kenney front wheels sit at +Z

		var ray := RayCast3D.new()
		ray.position = Vector3(pos.x, 0.0, pos.z)
		ray.target_position = Vector3(0, -(SPRING_REST + _wheel_r + 0.5), 0)
		ray.collision_mask = 1
		ray.enabled = true
		add_child(ray)
		_rays.append(ray)

		if w.get("node") != null:
			_wheel_visuals.append({"node": w["node"], "radius": float(w["radius"])})

	max_steer = lerpf(STEER_MAX, deg_to_rad(24.0), clampf((float(stats.handling) - 0.9) / 0.35, 0.0, 1.0))
	_build_lighting()
	_build_particles()
	_build_audio()

# ---------------------------------------------------------------- lighting VFX

func _build_lighting() -> void:
	var half_l: float = _size.z * 0.5
	var half_w: float = _size.x * 0.5
	var car_col: Color = stats.get("color", Color(0.9, 0.3, 0.25))

	var glow := OmniLight3D.new()
	glow.name = "Underglow"
	glow.light_color = car_col
	glow.omni_range = 4.5
	glow.light_energy = 1.6
	glow.position = Vector3(0, -0.15, 0)
	glow.shadow_enabled = false
	add_child(glow)

	for sx in [-1.0, 1.0]:
		var hl := SpotLight3D.new()
		hl.light_color = Color(1.0, 0.96, 0.85)
		hl.spot_range = 45.0
		hl.spot_angle = 32.0
		hl.light_energy = 2.2
		hl.position = Vector3(sx * half_w * 0.62, 0.6, half_l)
		hl.rotation_degrees = Vector3(-8, 0, 0)
		hl.shadow_enabled = false
		add_child(hl)

	_brake_mat = StandardMaterial3D.new()
	_brake_mat.albedo_color = Color(0.6, 0.05, 0.05)
	_brake_mat.emission_enabled = true
	_brake_mat.emission = Color(1.0, 0.12, 0.1)
	_brake_mat.emission_energy_multiplier = 0.6
	_brake_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var bl := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(half_w * 1.5, 0.12, 0.08)
	bl.mesh = bm
	bl.material_override = _brake_mat
	bl.position = Vector3(0, 0.62, -half_l)
	add_child(bl)

	_brake_light = OmniLight3D.new()
	_brake_light.light_color = Color(1.0, 0.15, 0.1)
	_brake_light.omni_range = 5.0
	_brake_light.light_energy = 0.0
	_brake_light.position = Vector3(0, 0.5, -half_l - 0.2)
	_brake_light.shadow_enabled = false
	add_child(_brake_light)

# ---------------------------------------------------------------- particles

func _make_particles(pname: String, pos: Vector3, color: Color, amount: int,
		vel: float, pscale: float, life: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = pname
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3(0, 1, 0)
	m.spread = 35.0
	m.initial_velocity_min = vel * 0.6
	m.initial_velocity_max = vel
	m.gravity = Vector3(0, 0.5, 0)
	m.scale_min = pscale * 0.6
	m.scale_max = pscale
	m.color = color
	var qm := QuadMesh.new()
	qm.size = Vector2(1, 1)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	qm.material = mat
	p.process_material = m
	p.draw_pass_1 = qm
	p.amount = amount
	p.lifetime = life
	p.emitting = false
	p.position = pos
	add_child(p)
	return p

func _build_particles() -> void:
	var half_l: float = _size.z * 0.5
	_smoke = _make_particles("TyreSmoke", Vector3(0, 0.25, -1.2), Color(0.85, 0.85, 0.85, 0.45), 24, 1.6, 1.0, 0.9)
	_flames = _make_particles("NitroFlames", Vector3(0, 0.45, -half_l - 0.1), Color(1.0, 0.55, 0.15, 0.9), 40, 6.0, 0.5, 0.35)
	_trail = _make_particles("SpeedTrail", Vector3(0, 0.6, -half_l), Color(0.6, 0.85, 1.0, 0.35), 30, 2.0, 0.6, 0.5)

# ---------------------------------------------------------------- audio

func _build_audio() -> void:
	var vol: float = clampf(GameState.volume, 0.001, 1.0)
	_engine_player = AudioStreamPlayer.new()
	_engine_player.name = "EngineSfx"
	_engine_player.stream = Sfx.engine_loop()
	_engine_player.volume_db = linear_to_db(vol * 0.45)
	add_child(_engine_player)
	_engine_player.play()

	_screech_player = AudioStreamPlayer.new()
	_screech_player.name = "ScreechSfx"
	_screech_player.stream = Sfx.screech_loop()
	_screech_player.volume_db = -80.0
	add_child(_screech_player)
	_screech_player.play()

	_nitro_player = AudioStreamPlayer.new()
	_nitro_player.name = "NitroSfx"
	_nitro_player.stream = Sfx.nitro_burst()
	_nitro_player.volume_db = linear_to_db(vol * 0.8)
	add_child(_nitro_player)

func _update_audio() -> void:
	if _engine_player != null:
		var top: float = maxf(60.0, float(stats.get("top_speed_kmh", 220.0)))
		var ratio: float = clampf(speed_kmh() / top, 0.0, 1.0)
		_engine_player.pitch_scale = lerpf(0.7, 2.6, ratio) + (0.25 if nitro_active else 0.0)
	if _screech_player != null:
		var target_db: float = -80.0
		if is_grounded and (is_drifting or absf(steering) * speed_kmh() > 120.0) and speed_kmh() > 12.0:
			target_db = linear_to_db(clampf(GameState.volume, 0.001, 1.0) * 0.5)
		_screech_player.volume_db = lerpf(_screech_player.volume_db, target_db, 0.15)
	if _nitro_player != null:
		if nitro_active and not _nitro_played:
			_nitro_player.play()
			_nitro_played = true
		elif not nitro_active:
			_nitro_played = false

# ---------------------------------------------------------------- helpers

func speed_kmh() -> float:
	return linear_velocity.length() * 3.6

func forward_speed() -> float:
	return linear_velocity.dot(global_transform.basis.z)

func point_velocity(p: Vector3) -> Vector3:
	return linear_velocity + angular_velocity.cross(p - global_position)

func reset_to_checkpoint() -> void:
	global_transform = last_checkpoint
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO

# ---------------------------------------------------------------- physics

func _physics_process(delta: float) -> void:
	if not can_drive:
		steering = 0.0
		_steer_angle = lerpf(_steer_angle, 0.0, STEER_SPEED * delta)
		_suspension(delta, 0.0, false, true)
		if _flames != null:
			_flames.emitting = false
		if _smoke != null:
			_smoke.emitting = false
		if _screech_player != null:
			_screech_player.volume_db = lerpf(_screech_player.volume_db, -80.0, 0.2)
		if _engine_player != null:
			_engine_player.pitch_scale = lerpf(_engine_player.pitch_scale, 0.7, 0.1)
		return

	_read_input(delta)
	_suspension(delta, _steer_angle, is_drifting, false)
	_air_stabilization(delta)
	_visuals(delta)

func _read_input(delta: float) -> void:
	# one-touch: holding the screen accelerates, dragging steers (keyboard still works)
	var throttle: float = maxf(Input.get_action_strength("accelerate"), 1.0 if GameState.touch_drive else 0.0)
	var brake_in: float = Input.get_action_strength("brake")
	var steer_in: float = clampf(Input.get_action_strength("steer_left") - Input.get_action_strength("steer_right") + GameState.touch_steer, -1.0, 1.0)

	var speed_factor: float = clampf(1.0 - speed_kmh() / 420.0, 0.45, 1.0)
	_steer_angle = lerpf(_steer_angle, steer_in * max_steer * speed_factor, clampf(STEER_SPEED * delta, 0.0, 1.0))
	steering = _steer_angle

	_throttle = throttle
	_brake_input = brake_in

	is_drifting = Input.is_action_pressed("handbrake") and is_grounded and linear_velocity.length() > 6.0

	if Input.is_action_pressed("nitro") and nitro_charge > 0.0 and throttle > 0.01:
		nitro_active = true
		nitro_charge = maxf(0.0, nitro_charge - NITRO_DRAIN * delta)
	else:
		nitro_active = false
		var regen: float = NITRO_REGEN * (2.0 if is_drifting else 1.0)
		nitro_charge = minf(NITRO_MAX, nitro_charge + regen * delta)

var _throttle: float = 0.0
var _brake_input: float = 0.0

func _suspension(delta: float, steer_angle: float, drifting: bool, coasting: bool) -> void:
	var grounded: int = 0
	var grip: float = DRIFT_GRIP if drifting else GRIP
	var speed_cap: float = MAX_SPEED * (NITRO_MULT if nitro_active else 1.0)
	var top: float = float(stats.get("top_speed_kmh", 220.0)) / 3.6

	for i in range(_rays.size()):
		var ray: RayCast3D = _rays[i]
		var offset: Vector3 = _offsets[i]
		var wheel_basis: Basis = global_transform.basis
		if _front[i]:
			wheel_basis = wheel_basis.rotated(global_transform.basis.y, steer_angle)

		if ray.is_colliding():
			grounded += 1
			var contact: Vector3 = ray.get_collision_point()
			var normal: Vector3 = ray.get_collision_normal()
			var dist: float = ray.global_position.distance_to(contact)
			var compression: float = SPRING_REST - dist
			var tire_vel: Vector3 = point_velocity(contact)
			var spring_vel: float = normal.dot(tire_vel)
			var f: float = (compression * SPRING_STIFF) - (spring_vel * SPRING_DAMP)
			apply_force(normal * maxf(0.0, f), contact - global_position)

			# drive
			if not coasting and _throttle > 0.01 and linear_velocity.length() < minf(speed_cap, top):
				var drive: Vector3 = wheel_basis.z * _throttle * ENGINE_POWER
				if nitro_active:
					drive *= 1.35
				apply_force(drive, contact - global_position)
			elif not coasting and _brake_input > 0.01:
				if forward_speed() > 1.0:
					apply_force(-wheel_basis.z * _brake_input * ENGINE_POWER * 1.2, contact - global_position)
				else:
					apply_force(-wheel_basis.z * _brake_input * ENGINE_POWER * 0.5, contact - global_position)

			# lateral grip
			var lateral: Vector3 = wheel_basis.x
			var lat_vel: float = lateral.dot(tire_vel)
			var friction: Vector3 = -lateral * lat_vel * grip * mass * 0.25
			apply_force(friction / delta, contact - global_position)

			# steering + visual wheel placement
			if _front[i]:
				_rotate_visual(i, steer_angle)
			_place_wheel(i, -dist)
		else:
			_place_wheel(i, -SPRING_REST)

	is_grounded = grounded >= 2

func _place_wheel(i: int, y: float) -> void:
	if i < _wheel_visuals.size():
		var n: Node3D = _wheel_visuals[i]["node"]
		if n != null and is_instance_valid(n):
			var r: float = float(_wheel_visuals[i]["radius"])
			var local: Vector3 = n.position
			n.position = Vector3(local.x, y + r, local.z)

func _rotate_visual(i: int, steer_angle: float) -> void:
	if i < _wheel_visuals.size():
		var n: Node3D = _wheel_visuals[i]["node"]
		if n != null and is_instance_valid(n):
			var e: Vector3 = n.rotation
			n.rotation = Vector3(e.x, steer_angle, e.z)

func _air_stabilization(delta: float) -> void:
	if is_grounded:
		return
	var up: Vector3 = global_transform.basis.y
	var axis: Vector3 = up.cross(Vector3.UP)
	apply_torque(axis * AIR_TORQUE * delta)

func _visuals(delta: float) -> void:
	var braking: bool = _brake_input > 0.01
	if _brake_mat != null:
		_brake_mat.emission_energy_multiplier = 2.4 if braking else 0.6
	if _brake_light != null:
		_brake_light.light_energy = 2.0 if braking else 0.0
	if _flames != null:
		_flames.emitting = nitro_active
	if _trail != null:
		_trail.emitting = speed_kmh() > float(stats.get("top_speed_kmh", 220.0)) * 0.6

	# wheel spin
	for i in range(_wheel_visuals.size()):
		var n: Node3D = _wheel_visuals[i]["node"]
		if n != null and is_instance_valid(n):
			var r: float = maxf(0.1, float(_wheel_visuals[i]["radius"]))
			n.rotate_x(forward_speed() / r * delta)

	# chassis roll / pitch
	if _body_holder != null:
		var lean: float = clampf(steering * speed_kmh() * 0.0022, -0.16, 0.16)
		var pitch: float = clampf(-_throttle * 0.05 + _brake_input * 0.05, -0.06, 0.06)
		_body_holder.rotation.z = lerpf(_body_holder.rotation.z, -lean, clampf(delta * 5.0, 0.0, 1.0))
		_body_holder.rotation.x = lerpf(_body_holder.rotation.x, pitch, clampf(delta * 5.0, 0.0, 1.0))

	_update_audio()

	# drift smoke + skid marks
	if (is_drifting or absf(steering) * speed_kmh() > 120.0) and speed_kmh() > 12.0:
		if _smoke != null:
			_smoke.emitting = true
		_drop_skids()
	elif _smoke != null:
		_smoke.emitting = false

	if global_transform.origin.y < -12.0 or Input.is_action_just_pressed("reset_car"):
		reset_to_checkpoint()

# ---------------------------------------------------------------- skid marks

func _ensure_skid() -> void:
	if _skid != null:
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = SKID_MAX
	var q := QuadMesh.new()
	q.size = Vector2(0.32, 0.9)
	mm.mesh = q
	_skid = MultiMeshInstance3D.new()
	_skid.name = "SkidMarks"
	_skid.multimesh = mm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.04, 0.04, 0.05, 0.6)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_skid.material_override = mat
	var hide := Transform3D(Basis(), Vector3(0, -1000, 0))
	for i in range(SKID_MAX):
		mm.set_instance_transform(i, hide)
	var parent: Node = get_parent()
	if parent != null:
		parent.add_child(_skid)

func _drop_skids() -> void:
	_ensure_skid()
	if _skid == null:
		return
	var yaw: float = global_transform.basis.get_euler().y
	var flat := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -PI * 0.5)
	for i in range(_wheel_visuals.size()):
		if _front[i]:
			continue
		var n: Node3D = _wheel_visuals[i]["node"]
		if n == null or not is_instance_valid(n):
			continue
		var wp: Vector3 = n.global_position
		var t := Transform3D(flat, Vector3(wp.x, wp.y - float(_wheel_visuals[i]["radius"]) + 0.03, wp.z))
		_skid.multimesh.set_instance_transform(_skid_idx, t)
		_skid_idx = (_skid_idx + 1) % SKID_MAX
