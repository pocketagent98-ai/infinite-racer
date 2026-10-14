class_name CarFactory
extends RefCounted
## Builds cars from the CC0 Kenney Car Kit GLB models (assets/cars/*.glb).
## The models expose named wheel nodes, so physics wheels align exactly to the
## visible wheels. Kenney models face +Z, which is also the direction Godot's
## VehicleBody3D drives with positive engine force, so no rotation is applied.
## 100 entries come from cycling the roster with a per-entry colour tint.

const TOTAL_CARS := 100
const CAR_SCALE := 1.8

const CAR_MODELS: Array[Dictionary] = [
	{"f": "race", "label": "Race", "perf": 0.95},
	{"f": "race-future", "label": "Race Future", "perf": 0.92},
	{"f": "sedan-sports", "label": "Sedan Sport", "perf": 0.85},
	{"f": "hatchback-sports", "label": "Hatch Sport", "perf": 0.80},
	{"f": "police", "label": "Police", "perf": 0.78},
	{"f": "kart-oozi", "label": "Kart Oozi", "perf": 0.74},
	{"f": "kart-oopi", "label": "Kart Oopi", "perf": 0.72},
	{"f": "kart-ooli", "label": "Kart Ooli", "perf": 0.70},
	{"f": "kart-oobi", "label": "Kart Oobi", "perf": 0.68},
	{"f": "kart-oodi", "label": "Kart Oodi", "perf": 0.66},
	{"f": "sedan", "label": "Sedan", "perf": 0.60},
	{"f": "suv-luxury", "label": "SUV Luxury", "perf": 0.55},
	{"f": "suv", "label": "SUV", "perf": 0.50},
	{"f": "taxi", "label": "Taxi", "perf": 0.45},
	{"f": "delivery-flat", "label": "Delivery Flat", "perf": 0.40},
	{"f": "delivery", "label": "Delivery", "perf": 0.38},
	{"f": "van", "label": "Van", "perf": 0.36},
	{"f": "ambulance", "label": "Ambulance", "perf": 0.35},
	{"f": "truck-flat", "label": "Truck Flat", "perf": 0.32},
	{"f": "truck", "label": "Truck", "perf": 0.30},
	{"f": "tractor-police", "label": "Tractor Police", "perf": 0.30},
	{"f": "firetruck", "label": "Firetruck", "perf": 0.29},
	{"f": "garbage-truck", "label": "Garbage", "perf": 0.28},
	{"f": "tractor", "label": "Tractor", "perf": 0.25},
	{"f": "tractor-shovel", "label": "Tractor Shovel", "perf": 0.22},
]

const PALETTE: Array[Color] = [
	Color("#e8443a"), Color("#2f6fed"), Color("#f5c542"), Color("#39b54a"),
	Color("#9b5de5"), Color("#ff8c42"), Color("#00bcd4"), Color("#e91e63"),
]

static var _cache: Dictionary = {}

static func _load(path: String) -> PackedScene:
	if _cache.has(path):
		return _cache[path]
	var ps: PackedScene = null
	if ResourceLoader.exists(path):
		ps = load(path)
	_cache[path] = ps
	return ps

static func _rel_transform(root: Node, node: Node) -> Transform3D:
	var xf := Transform3D()
	var cur: Node = node
	while cur != null and cur != root:
		if cur is Node3D:
			xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf

static func _aabb(root: Node3D) -> AABB:
	var out := AABB()
	var first := true
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			var a: AABB = (n as MeshInstance3D).get_aabb()
			a = _rel_transform(root, n) * a
			out = a if first else out.merge(a)
			first = false
		for c in n.get_children():
			stack.append(c)
	return out

static func _collect_wheels(node: Node, out: Dictionary) -> void:
	for c in node.get_children():
		var nm: String = String(c.name).to_lower()
		if nm.contains("wheel") and c is Node3D:
			out[nm] = c
		_collect_wheels(c, out)

# ---------------------------------------------------------------- public API

static func car_model_label(index: int) -> String:
	var i: int = posmod(index, TOTAL_CARS)
	return String(CAR_MODELS[i % CAR_MODELS.size()]["label"])

static func car_color(index: int) -> Color:
	var i: int = posmod(index, TOTAL_CARS)
	return PALETTE[(i / CAR_MODELS.size() + i) % PALETTE.size()]

static func car_name(index: int) -> String:
	var i: int = posmod(index, TOTAL_CARS)
	var variant: int = i / CAR_MODELS.size()
	var suffix: String = ["", " GT", " RS", " Turbo"][variant % 4]
	return car_model_label(i) + suffix

static func car_stats(index: int) -> Dictionary:
	var i: int = posmod(index, TOTAL_CARS)
	var spec: Dictionary = CAR_MODELS[i % CAR_MODELS.size()]
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242 + i
	var perf: float = float(spec["perf"]) * rng.randf_range(0.94, 1.06)
	perf = clampf(perf, 0.2, 1.0)
	var mass: float = lerpf(1500.0, 950.0, perf) + rng.randf_range(-40.0, 40.0)
	var accel: float = lerpf(6.0, 12.5, perf)
	return {
		"name": car_name(i),
		"color": car_color(i),
		"perf": perf,
		"top_speed_kmh": lerpf(170.0, 330.0, perf),
		"engine_force": mass * accel / 4.0,
		"brake_force": mass * lerpf(9.0, 13.0, perf) / 4.0,
		"handling": lerpf(0.92, 1.2, rng.randf()),
		"grip": lerpf(0.95, 1.2, rng.randf()),
		"mass": mass,
	}

static func build_car(index: int) -> Dictionary:
	var i: int = posmod(index, TOTAL_CARS)
	var spec: Dictionary = CAR_MODELS[i % CAR_MODELS.size()]
	var stats: Dictionary = car_stats(i)
	var path := "res://assets/cars/%s.glb" % String(spec["f"])
	var ps: PackedScene = _load(path)
	if ps == null:
		return _procedural(i, stats)
	var model: Node3D = ps.instantiate() as Node3D
	if model == null:
		return _procedural(i, stats)

	var ab: AABB = _aabb(model)
	var s: float = CAR_SCALE
	model.scale = Vector3(s, s, s)
	# no rotation: the model's +Z front already matches the physics forward

	var wheel_nodes: Dictionary = {}
	_collect_wheels(model, wheel_nodes)
	var wheel_r: float = 0.32 * s
	if not wheel_nodes.is_empty():
		var any_wheel: Node3D = wheel_nodes.values()[0]
		var wa: AABB = _aabb(any_wheel)
		wheel_r = maxf(0.15, wa.size.y * 0.5 * s)

	var wheels: Array[Dictionary] = []
	for key in wheel_nodes.keys():
		var wn: Node3D = wheel_nodes[key]
		var rel: Transform3D = _rel_transform(model, wn)
		var pos := Vector3(rel.origin.x * s, rel.origin.y * s, rel.origin.z * s)
		wheels.append({"pos": pos, "radius": wheel_r, "node": wn, "key": String(key)})

	if wheels.is_empty():
		var wx: float = ab.size.x * 0.5 * s * 0.8
		var wz: float = ab.size.z * 0.33 * s
		for p in [Vector3(-wx, wheel_r, -wz), Vector3(wx, wheel_r, -wz),
				Vector3(-wx, wheel_r, wz), Vector3(wx, wheel_r, wz)]:
			wheels.append({"pos": p, "radius": wheel_r, "node": null, "key": "wheel"})

	var variant: int = i / CAR_MODELS.size()
	# always polish (shinier paint); tint only the later variants
	_polish(model, stats["color"], wheel_nodes, 0.45 if variant > 0 else 0.0)

	var holder := Node3D.new()
	holder.name = "Body"
	holder.add_child(model)

	var size := Vector3(ab.size.x * s, ab.size.y * s, ab.size.z * s)
	var offset := Vector3(0, wheel_r + size.y * 0.5, 0)

	return {
		"body": holder,
		"wheels": wheels,
		"stats": stats,
		"name": stats["name"],
		"collision_size": size,
		"collision_offset": offset,
	}

## Gives the paint a cleaner, shinier look and optionally tints it.
static func _polish(root: Node, color: Color, skip: Dictionary, tint_amount: float) -> void:
	var skip_nodes: Array = skip.values()
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D and not skip_nodes.has(n):
			var mi: MeshInstance3D = n
			var mesh: Mesh = mi.mesh
			if mesh != null:
				for si in range(mesh.get_surface_count()):
					var mat: Material = mi.get_active_material(si)
					if mat is StandardMaterial3D:
						var m2: StandardMaterial3D = (mat as StandardMaterial3D).duplicate()
						if tint_amount > 0.0:
							m2.albedo_color = m2.albedo_color.lerp(color, tint_amount)
						m2.roughness = 0.42
						m2.metallic = 0.3
						mi.set_surface_override_material(si, m2)
		for c in n.get_children():
			stack.append(c)

static func _procedural(index: int, stats: Dictionary) -> Dictionary:
	var root := Node3D.new()
	root.name = "Body"
	var mat := StandardMaterial3D.new()
	mat.albedo_color = stats["color"]
	mat.metallic = 0.35
	mat.roughness = 0.4
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.9, 0.7, 4.2)
	body.mesh = bm
	body.material_override = mat
	body.position = Vector3(0, 0.75, 0)
	root.add_child(body)
	var wheel_r := 0.34
	var wheels: Array[Dictionary] = []
	for p in [Vector3(-0.95, wheel_r, -1.4), Vector3(0.95, wheel_r, -1.4),
			Vector3(-0.95, wheel_r, 1.4), Vector3(0.95, wheel_r, 1.4)]:
		wheels.append({"pos": p, "radius": wheel_r, "node": null, "key": "wheel"})
	return {
		"body": root,
		"wheels": wheels,
		"stats": stats,
		"name": stats["name"],
		"collision_size": Vector3(1.9, 1.2, 4.2),
		"collision_offset": Vector3(0, wheel_r + 0.6, 0),
	}
