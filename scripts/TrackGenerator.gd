class_name TrackGenerator
extends RefCounted
## Generates a complete, unique racing circuit from an integer seed, with a
## road ribbon, kerbs, a dashed centre line, guardrails, scenery (MultiMesh),
## CC0 props and buildings, and a start gantry.

const THEMES: Array[Dictionary] = [
	{"name": "Coast",   "sky_top": Color("#2e6fd6"), "sky_horizon": Color("#bfe0ff"), "ground": Color("#4f7a3a"), "road": Color("#3a3f47"), "decor": Color("#2f5d2a"), "fog": Color("#cfe4ff"), "sun": Color("#fff6e0")},
	{"name": "Desert",  "sky_top": Color("#e08a3c"), "sky_horizon": Color("#ffe0a8"), "ground": Color("#c9a05a"), "road": Color("#4a4238"), "decor": Color("#8a6d3a"), "fog": Color("#f3d9a5"), "sun": Color("#fff0c0")},
	{"name": "Night",   "sky_top": Color("#05060d"), "sky_horizon": Color("#141b33"), "ground": Color("#141821"), "road": Color("#22252c"), "decor": Color("#1b2740"), "fog": Color("#0b0e18"), "sun": Color("#9fb6ff")},
	{"name": "Snow",    "sky_top": Color("#7fa8d6"), "sky_horizon": Color("#eaf3ff"), "ground": Color("#e8eef5"), "road": Color("#4a4f57"), "decor": Color("#bcd0e0"), "fog": Color("#eef5ff"), "sun": Color("#ffffff")},
	{"name": "Jungle",  "sky_top": Color("#1f7a5a"), "sky_horizon": Color("#bfe9c8"), "ground": Color("#2f6b32"), "road": Color("#3b4038"), "decor": Color("#1f4a22"), "fog": Color("#c6e8cf"), "sun": Color("#f2ffe6")},
	{"name": "Volcano", "sky_top": Color("#4a1414"), "sky_horizon": Color("#c05a2a"), "ground": Color("#3a2420"), "road": Color("#2a2222"), "decor": Color("#5a2a1a"), "fog": Color("#6b2a1a"), "sun": Color("#ff9a5a")},
	{"name": "Canyon",  "sky_top": Color("#3a6ea8"), "sky_horizon": Color("#f0c9a0"), "ground": Color("#a5643c"), "road": Color("#4a3d34"), "decor": Color("#8a4f2a"), "fog": Color("#e8c19a"), "sun": Color("#ffe6c0")},
	{"name": "Meadow",  "sky_top": Color("#4f9de0"), "sky_horizon": Color("#d6f0ff"), "ground": Color("#5aa64a"), "road": Color("#40444c"), "decor": Color("#3a7a33"), "fog": Color("#dff2ff"), "sun": Color("#fffbe8")},
]

static func theme_count() -> int:
	return THEMES.size()

# ---------------------------------------------------------------- shaders
# Procedural, texture-free materials so the road and ground no longer look
# like flat blocks of colour.

const ROAD_SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform float noise_scale = 0.5;
uniform float grain = 0.22;
uniform float rough = 0.82;
uniform float darken = 1.0;
uniform vec3 base : source_color = vec3(0.22, 0.24, 0.27);
varying vec3 wpos;
float hash(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123); }
float vnoise(vec2 p){
	vec2 i = floor(p); vec2 f = fract(p);
	float a = hash(i); float b = hash(i + vec2(1.0,0.0));
	float c = hash(i + vec2(0.0,1.0)); float d = hash(i + vec2(1.0,1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(a,b,u.x), mix(c,d,u.x), u.y);
}
void vertex(){ wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment(){
	float n = vnoise(wpos.xz * noise_scale);
	float n2 = vnoise(wpos.xz * noise_scale * 6.0);
	float g = 1.0 + (n * 0.65 + n2 * 0.35 - 0.5) * grain * 2.0;
	ALBEDO = base * g * darken;
	ROUGHNESS = rough;
	METALLIC = 0.0;
	SPECULAR = 0.15;
}
"""

const GROUND_SHADER := """
shader_type spatial;
uniform vec3 base : source_color = vec3(0.3, 0.45, 0.25);
uniform float noise_scale = 0.08;
uniform float grain = 0.3;
varying vec3 wpos;
float hash(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123); }
float vnoise(vec2 p){
	vec2 i = floor(p); vec2 f = fract(p);
	float a = hash(i); float b = hash(i + vec2(1.0,0.0));
	float c = hash(i + vec2(0.0,1.0)); float d = hash(i + vec2(1.0,1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(a,b,u.x), mix(c,d,u.x), u.y);
}
void vertex(){ wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment(){
	float n = vnoise(wpos.xz * noise_scale);
	float n2 = vnoise(wpos.xz * noise_scale * 4.0);
	float g = 1.0 + (n * 0.6 + n2 * 0.4 - 0.5) * grain * 2.0;
	ALBEDO = base * g * 0.8;
	ROUGHNESS = 0.95;
}
"""

static func _road_material(color: Color) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = ROAD_SHADER
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("base", Vector3(color.r, color.g, color.b))
	return m

static func _ground_material(color: Color) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = GROUND_SHADER
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("base", Vector3(color.r, color.g, color.b))
	return m

static func generate(track_seed: int, theme_index: int, difficulty: float) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = track_seed

	var theme: Dictionary = THEMES[posmod(theme_index, THEMES.size())]
	difficulty = clampf(difficulty, 0.0, 1.0)

	var point_count: int = rng.randi_range(8, 15)
	var base_radius: float = lerpf(150.0, 105.0, difficulty)
	var stretch: Vector2 = Vector2(rng.randf_range(0.8, 1.25), rng.randf_range(0.8, 1.25))
	var rot := rng.randf_range(0.0, TAU)

	var ctrl: Array[Vector3] = []
	for i in range(point_count):
		var ang := TAU * float(i) / float(point_count) + rot
		var r: float = base_radius * rng.randf_range(0.55, 1.05)
		ctrl.append(Vector3(cos(ang) * r * stretch.x, 0.0, sin(ang) * r * stretch.y))

	var curve := Curve3D.new()
	for p in ctrl:
		curve.add_point(p)
	curve.add_point(ctrl[0])
	for i in range(curve.point_count):
		var prev: Vector3 = ctrl[posmod(i - 1, point_count)]
		var next: Vector3 = ctrl[posmod(i + 1, point_count)]
		var dir: Vector3 = (next - prev) * 0.24
		curve.set_point_in(i, -dir)
		curve.set_point_out(i, dir)
	curve.bake_interval = 2.0

	var points: PackedVector3Array = curve.get_baked_points()
	if points.size() > 1 and points[0].distance_to(points[points.size() - 1]) < 0.01:
		points.remove_at(points.size() - 1)

	var length: float = curve.get_baked_length()
	var road_width: float = lerpf(17.0, 10.0, difficulty)

	var root := Node3D.new()
	root.name = "Track"

	var road_mesh := _build_ribbon(points, road_width, 0.02, theme["road"], theme["road"].lightened(0.08))
	var road := MeshInstance3D.new()
	road.name = "Road"
	road.mesh = road_mesh
	road.material_override = _road_material(theme["road"])
	root.add_child(road)

	var road_body := StaticBody3D.new()
	road_body.name = "RoadBody"
	var road_shape := CollisionShape3D.new()
	var rs: ConcavePolygonShape3D = road_mesh.create_trimesh_shape()
	rs.backface_collision = true
	road_shape.shape = rs
	road_body.add_child(road_shape)
	root.add_child(road_body)

	var wall_h: float = 0.9
	var wall_mesh := _build_walls(points, road_width, wall_h, theme["decor"])
	var walls := MeshInstance3D.new()
	walls.name = "Walls"
	walls.mesh = wall_mesh
	walls.material_override = _solid_material_double(theme["decor"])
	root.add_child(walls)

	var wall_body := StaticBody3D.new()
	wall_body.name = "WallBody"
	var wall_shape := CollisionShape3D.new()
	var ws: ConcavePolygonShape3D = wall_mesh.create_trimesh_shape()
	ws.backface_collision = true
	wall_shape.shape = ws
	wall_body.add_child(wall_shape)
	root.add_child(wall_body)

	# red/white rumble strips
	var kerbs := MeshInstance3D.new()
	kerbs.name = "Kerbs"
	kerbs.mesh = _build_kerbs(points, road_width)
	kerbs.material_override = _vertex_material()
	root.add_child(kerbs)

	# dashed painted centre line
	var line := MeshInstance3D.new()
	line.name = "CenterLine"
	line.mesh = _build_centerline(curve, length)
	line.material_override = _vertex_material()
	root.add_child(line)

	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	var pm := PlaneMesh.new()
	pm.size = Vector2(base_radius * 6.0, base_radius * 6.0)
	ground.mesh = pm
	ground.material_override = _ground_material(theme["ground"])
	ground.position = Vector3(0, -0.35, 0)
	root.add_child(ground)

	root.add_child(_build_scenery(points, base_radius, road_width, theme, rng))
	root.add_child(_build_props(curve, length, road_width, rng))

	var start_t := curve.sample_baked_with_rotation(0.0, true, false)
	root.add_child(_build_gantry(start_t, road_width, theme))

	var cp_count: int = max(4, int(length / 45.0))
	var checkpoints: Array[Transform3D] = []
	for i in range(cp_count):
		var off: float = length * float(i) / float(cp_count)
		var t := curve.sample_baked_with_rotation(off, true, false)
		t.origin += Vector3.UP * 0.9
		checkpoints.append(t)

	var start := curve.sample_baked_with_rotation(6.0, true, false)
	start.origin += Vector3.UP * 0.6

	return {
		"node": root,
		"curve": curve,
		"length": length,
		"road_width": road_width,
		"start": start,
		"checkpoints": checkpoints,
		"theme": theme,
	}

# ---------------------------------------------------------------- meshes

static func _build_ribbon(points: PackedVector3Array, width: float, y: float,
		color_a: Color, color_b: Color) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := points.size()
	var half := width * 0.5
	var prev_l := Vector3.ZERO
	var prev_r := Vector3.ZERO
	for i in range(n + 1):
		var idx := i % n
		var p: Vector3 = points[idx] + Vector3.UP * y
		var nxt: Vector3 = points[(idx + 1) % n]
		var prv: Vector3 = points[(idx - 1 + n) % n]
		var fwd: Vector3 = nxt - prv
		if fwd.length() < 0.001:
			fwd = Vector3.FORWARD
		fwd = fwd.normalized()
		var right: Vector3 = Vector3.UP.cross(fwd).normalized()
		var l: Vector3 = p - right * half
		var r: Vector3 = p + right * half
		var col: Color = color_a if (i / 3) % 2 == 0 else color_b
		if i > 0:
			st.set_color(col); st.add_vertex(prev_l)
			st.set_color(col); st.add_vertex(prev_r)
			st.set_color(col); st.add_vertex(l)
			st.set_color(col); st.add_vertex(prev_r)
			st.set_color(col); st.add_vertex(r)
			st.set_color(col); st.add_vertex(l)
		prev_l = l
		prev_r = r
	st.generate_normals()
	return st.commit()

static func _build_walls(points: PackedVector3Array, width: float, height: float,
		color: Color) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := points.size()
	var half := width * 0.5 + 0.1
	var prev: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
	for i in range(n + 1):
		var idx := i % n
		var p: Vector3 = points[idx]
		var nxt: Vector3 = points[(idx + 1) % n]
		var prv: Vector3 = points[(idx - 1 + n) % n]
		var fwd: Vector3 = nxt - prv
		if fwd.length() < 0.001:
			fwd = Vector3.FORWARD
		fwd = fwd.normalized()
		var right: Vector3 = Vector3.UP.cross(fwd).normalized()
		var l_bot: Vector3 = p - right * half
		var l_top: Vector3 = l_bot + Vector3.UP * height
		var r_bot: Vector3 = p + right * half
		var r_top: Vector3 = r_bot + Vector3.UP * height
		var cur: Array[Vector3] = [l_bot, l_top, r_bot, r_top]
		if i > 0:
			_quad(st, prev[0], prev[1], cur[1], cur[0], color)
			_quad(st, prev[2], prev[3], cur[3], cur[2], color)
		prev = cur
	st.generate_normals()
	return st.commit()

static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
	st.set_color(col); st.add_vertex(a)
	st.set_color(col); st.add_vertex(b)
	st.set_color(col); st.add_vertex(c)
	st.set_color(col); st.add_vertex(a)
	st.set_color(col); st.add_vertex(c)
	st.set_color(col); st.add_vertex(d)

static func _strip_quad(st: SurfaceTool, prev_l: Vector3, l: Vector3, prev_r: Vector3, r: Vector3, col: Color) -> void:
	st.set_color(col); st.add_vertex(prev_l)
	st.set_color(col); st.add_vertex(prev_r)
	st.set_color(col); st.add_vertex(l)
	st.set_color(col); st.add_vertex(prev_r)
	st.set_color(col); st.add_vertex(r)
	st.set_color(col); st.add_vertex(l)

static func _build_kerbs(points: PackedVector3Array, road_width: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := points.size()
	var kw := 1.1
	for side in [-1.0, 1.0]:
		var inner: float = road_width * 0.5
		var outer: float = inner + kw
		var prev_i := Vector3.ZERO
		var prev_o := Vector3.ZERO
		for i in range(n + 1):
			var idx := i % n
			var p: Vector3 = points[idx] + Vector3.UP * 0.03
			var nxt: Vector3 = points[(idx + 1) % n]
			var prv: Vector3 = points[(idx - 1 + n) % n]
			var fwd: Vector3 = nxt - prv
			if fwd.length() < 0.001:
				fwd = Vector3.FORWARD
			fwd = fwd.normalized()
			var right: Vector3 = Vector3.UP.cross(fwd).normalized()
			var i_pt: Vector3 = p + right * side * inner
			var o_pt: Vector3 = p + right * side * outer
			var col: Color = Color(0.9, 0.16, 0.14) if (i / 2) % 2 == 0 else Color(0.95, 0.95, 0.95)
			if i > 0:
				_strip_quad(st, prev_i, i_pt, prev_o, o_pt, col)
			prev_i = i_pt
			prev_o = o_pt
	st.generate_normals()
	return st.commit()

static func _build_centerline(curve: Curve3D, length: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dash := 3.0
	var gap := 3.5
	var w := 0.22
	var d := 0.0
	while d + dash < length:
		var mid: Transform3D = curve.sample_baked_with_rotation(d + dash * 0.5, true, false)
		var fwd: Vector3 = -mid.basis.z
		var right: Vector3 = mid.basis.x
		var p0: Vector3 = mid.origin + fwd * (dash * 0.5) + Vector3.UP * 0.035
		var p1: Vector3 = mid.origin - fwd * (dash * 0.5) + Vector3.UP * 0.035
		_strip_quad(st, p1 - right * w, p0 - right * w, p1 + right * w, p0 + right * w, Color(0.93, 0.93, 0.85))
		d += dash + gap
	st.generate_normals()
	return st.commit()

static func _multimesh(mesh: Mesh, mat: Material, xfs: Array) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = xfs.size()
	mm.mesh = mesh
	for i in range(xfs.size()):
		mm.set_instance_transform(i, xfs[i])
	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	node.material_override = mat
	return node

static func _build_scenery(points: PackedVector3Array, base_radius: float, road_width: float,
		theme: Dictionary, rng: RandomNumberGenerator) -> Node3D:
	var holder := Node3D.new()
	holder.name = "Scenery"
	var reach: float = base_radius * 2.2
	var trunk_xf: Array[Transform3D] = []
	var canopy_xf: Array[Transform3D] = []
	var rock_xf: Array[Transform3D] = []
	var placed := 0
	var attempts := 0
	while placed < 130 and attempts < 900:
		attempts += 1
		var pos := Vector3(rng.randf_range(-reach, reach), 0.0, rng.randf_range(-reach, reach))
		var near := false
		for j in range(0, points.size(), 3):
			if pos.distance_to(points[j]) < road_width * 0.5 + 4.0:
				near = true
				break
		if near:
			continue
		if rng.randf() < 0.72:
			var th: float = rng.randf_range(1.6, 3.0)
			var cr: float = rng.randf_range(1.1, 2.1)
			trunk_xf.append(Transform3D(Basis().scaled(Vector3(1.0, th, 1.0)), pos + Vector3.UP * (th * 0.5)))
			canopy_xf.append(Transform3D(Basis().scaled(Vector3(cr, cr, cr)), pos + Vector3.UP * (th + cr * 0.6)))
		else:
			var s: float = rng.randf_range(0.6, 2.2)
			var hh: float = rng.randf_range(0.5, 1.0)
			var b := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3(s, s * hh, s))
			rock_xf.append(Transform3D(b, pos + Vector3.UP * (s * hh * 0.5)))
		placed += 1
	if not trunk_xf.is_empty():
		var tm := CylinderMesh.new()
		tm.top_radius = 0.18
		tm.bottom_radius = 0.26
		tm.height = 1.0
		holder.add_child(_multimesh(tm, _solid_material(theme["decor"].darkened(0.25)), trunk_xf))
	if not canopy_xf.is_empty():
		var cm := SphereMesh.new()
		cm.radius = 1.0
		cm.height = 2.0
		holder.add_child(_multimesh(cm, _solid_material(theme["decor"]), canopy_xf))
	if not rock_xf.is_empty():
		var bm := BoxMesh.new()
		bm.size = Vector3.ONE
		holder.add_child(_multimesh(bm, _solid_material(theme["ground"].darkened(0.15)), rock_xf))
	return holder

static func _build_gantry(t: Transform3D, road_width: float, theme: Dictionary) -> Node3D:
	var holder := Node3D.new()
	holder.name = "StartGantry"
	holder.transform = t
	var half := road_width * 0.5 + 0.4
	var pillar_mat := _solid_material(Color(0.85, 0.85, 0.88))
	var banner_mat := _solid_material(Color(0.1, 0.1, 0.12))
	for sx in [-1.0, 1.0]:
		var pillar := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.3, 6.0, 0.3)
		pillar.mesh = bm
		pillar.material_override = pillar_mat
		pillar.position = Vector3(sx * half, 3.0, 0)
		holder.add_child(pillar)
	var banner := MeshInstance3D.new()
	var bb := BoxMesh.new()
	bb.size = Vector3(half * 2.0, 1.2, 0.3)
	banner.mesh = bb
	banner.material_override = banner_mat
	banner.position = Vector3(0, 6.0, 0)
	holder.add_child(banner)
	return holder

# ---------------------------------------------------------------- CC0 props

static var _prop_cache: Dictionary = {}

static func _load_scene(path: String) -> PackedScene:
	if _prop_cache.has(path):
		return _prop_cache[path]
	var ps: PackedScene = null
	if ResourceLoader.exists(path):
		ps = load(path)
	_prop_cache[path] = ps
	return ps

static func _build_props(curve: Curve3D, length: float, road_width: float,
		rng: RandomNumberGenerator) -> Node3D:
	var holder := Node3D.new()
	holder.name = "Props"
	var specs := [
		{"f": "grandStand", "s": 7.0},
		{"f": "grandStandCovered", "s": 7.0},
		{"f": "billboard", "s": 5.0},
		{"f": "lightPostLarge", "s": 6.0},
		{"f": "flagCheckers", "s": 4.0},
		{"f": "pylon", "s": 3.0},
		{"f": "pitsGarage", "s": 7.0},
		{"f": "fenceStraight", "s": 4.0},
	]
	var n: int = maxi(10, int(length / 50.0))
	for i in range(n):
		var off: float = length * float(i) / float(n)
		var t: Transform3D = curve.sample_baked_with_rotation(off, true, false)
		var right: Vector3 = t.basis.x
		var side: float = 1.0 if i % 2 == 0 else -1.0
		var spec: Dictionary = specs[i % specs.size()]
		var ps: PackedScene = _load_scene("res://assets/props/%s.glb" % String(spec["f"]))
		if ps == null:
			continue
		var node: Node3D = ps.instantiate() as Node3D
		if node == null:
			continue
		var s: float = float(spec["s"])
		node.scale = Vector3(s, s, s)
		var pos: Vector3 = t.origin + right * side * (road_width * 0.5 + 4.0)
		pos.y = 0.0
		node.position = pos
		var dir: Vector3 = t.origin - pos
		dir.y = 0.0
		if dir.length() > 0.01:
			node.rotation.y = atan2(dir.x, dir.z)
		holder.add_child(node)

	# track-side barriers for a proper race look
	var bar_files := ["barrierWhite", "barrierRed"]
	var bar_n: int = maxi(6, int(length / 26.0))
	for i in range(bar_n):
		var boff: float = length * float(i) / float(bar_n)
		var bt: Transform3D = curve.sample_baked_with_rotation(boff, true, false)
		var bright: Vector3 = bt.basis.x
		for side in [-1.0, 1.0]:
			var bps: PackedScene = _load_scene("res://assets/props/%s.glb" % bar_files[i % 2])
			if bps == null:
				continue
			var bnode: Node3D = bps.instantiate() as Node3D
			if bnode == null:
				continue
			var bs: float = 4.5
			bnode.scale = Vector3(bs, bs, bs)
			bnode.position = Vector3(bt.origin.x + bright.x * side * (road_width * 0.5 + 0.8), 0.0,
				bt.origin.z + bright.z * side * (road_width * 0.5 + 0.8))
			bnode.rotation.y = bt.basis.get_euler().y
			holder.add_child(bnode)

	var bfiles := ["building-type-a", "building-type-b", "building-type-c", "building-type-d",
		"building-type-e", "building-type-f", "building-type-g", "building-type-h"]
	var placed := 0
	var attempts := 0
	var reach: float = maxf(120.0, length * 0.3)
	while placed < 24 and attempts < 220:
		attempts += 1
		var bp := Vector3(rng.randf_range(-reach, reach), 0.0, rng.randf_range(-reach, reach))
		var nearest: Vector3 = curve.sample_baked(curve.get_closest_offset(bp))
		if bp.distance_to(nearest) < road_width * 0.5 + 12.0:
			continue
		var bps: PackedScene = _load_scene("res://assets/buildings/%s.glb" % bfiles[rng.randi() % bfiles.size()])
		if bps == null:
			continue
		var bn: Node3D = bps.instantiate() as Node3D
		if bn == null:
			continue
		var bs: float = rng.randf_range(4.0, 9.0)
		bn.scale = Vector3(bs, bs, bs)
		bn.position = bp
		bn.rotation.y = rng.randf_range(0.0, TAU)
		holder.add_child(bn)
		placed += 1
	return holder

# ---------------------------------------------------------------- materials

static func _vertex_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.85
	m.metallic = 0.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

static func _solid_material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.8
	m.metallic = 0.0
	return m

static func _solid_material_double(color: Color) -> StandardMaterial3D:
	var m := _solid_material(color)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m
