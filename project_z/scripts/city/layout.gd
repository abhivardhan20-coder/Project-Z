extends RefCounted

const LIMIT := 500
const CHUNK_SIZE := 100
const COUNT := 10
const SEED := 1790805
const PILOT := Vector3(-300, 16.015, -245.45)
const BRIDGE := Vector2(-210, -190)
const PILOT_WEST := -380.0
const PILOT_EAST := -140.0
const RAIL_CENTER := Vector2(327, -332)
const AIRPORT_CENTER := Vector2(435, 76)
const RAIL_SITE := Rect2(277, -373, 83, 91)
const AIRPORT_SITE := Rect2(397, 26, 84, 97)
const CIVIC_PLAZA := Rect2(176, -134, 28, 28)
const OVERLOOK := Vector2(-460, -340)
const OVERLOOK_SITE := Rect2(-488, -367, 62, 56)
const AXES := [-380.0, -250.0, -140.0, 0.0, 140.0, 250.0, 380.0]
const DISTRICTS := ["Hillview Residential", "Civic & Commercial", "Old Market", "Utility & Industrial"]
const PLACES := {
	"safehouse": ["Hillview Steps", -289.18, -237.0],
	"corner_shop": ["Hillview Corner Shop", -300.156, -237.0],
	"residential": ["Fern Court", -354.0, -138.0],
	"police": ["Civic Police Annex", 48.0, -140.0],
	"grocery": ["Northline Grocer", -250.0, 147.0],
	"clinic": ["Mercy Clinic", -138.0, 147.0],
	"warehouse": ["Kaldran Freight", 214.0, 147.0],
	"pump": ["Bank Pumping Station", 47.0, 147.0],
	"garage": ["Municipal Motor Works", 165.0, 257.0],
}
const LANDMARKS := [
	["Ash Lane Cottages", Vector2(-319, -270), Vector2(17, 12), 2],
	["Hillview Terrace", Vector2(-277, -268), Vector2(20, 12), 3],
	["Quarry Road Houses", Vector2(-213, -266), Vector2(15, 11), 2],
	["Municipal Hall", Vector2(190, -157), Vector2(44, 24), 4],
	["Civic Exchange", Vector2(212, -264), Vector2(31, 19), 13],
	["North Civic Offices", Vector2(153, -177), Vector2(20, 21), 12],
	["Civic Hotel", Vector2(223, -179), Vector2(17, 20), 10],
	["Public Health Pharmacy", Vector2(-190, 158), Vector2(19, 16), 2],
	["Kaldran Relief Hall", Vector2(-315, 158), Vector2(31, 23), 2],
	["Electrical Service Yard", Vector2(68, 265), Vector2(33, 19), 1],
	["Fuel and Maintenance", Vector2(319, 154), Vector2(27, 17), 1],
]
const INTERIOR_PADS := [
	Vector2(-354, -138), Vector2(48, -140), Vector2(-250, 147), Vector2(-138, 147),
	Vector2(214, 147), Vector2(47, 147), Vector2(165, 257),
]
const STREET_FEATURES := [Rect2(77, -136, 11, 9), Rect2(110, -137, 10, 10),
	Rect2(164, -135, 16, 15), Rect2(-324, 137, 18, 12), Rect2(67, 272, 22, 20), RAIL_SITE, AIRPORT_SITE, CIVIC_PLAZA, OVERLOOK_SITE]

var noise := FastNoiseLite.new()
static var parcel_cache: Dictionary = {}


func _init() -> void:
	noise.seed = SEED
	noise.frequency = 0.012


static func chunk_for(point: Vector3) -> Vector2i:
	return Vector2i(clampi(floori((point.x + LIMIT) / CHUNK_SIZE), 0, COUNT - 1),
		clampi(floori((point.z + LIMIT) / CHUNK_SIZE), 0, COUNT - 1))


static func origin(key: Vector2i) -> Vector2:
	return Vector2(key * CHUNK_SIZE) - Vector2.ONE * LIMIT


static func district(x: float, z: float) -> int:
	return (1 if x >= 0 else 0) + (2 if z >= 0 else 0)


static func road_x_offset(z: float) -> float:
	return 8.0 * sin(z * 0.018) * smoothstep(32.0, 120.0, absf(z))


static func road_z_offset(x: float, axis: float) -> float:
	if axis == -250.0 and x < 0.0:
		return 6.0 * sin((x + 300.0) * 0.028) * smoothstep(24.0, 78.0, absf(x + 300.0)) * smoothstep(0.0, 65.0, -x)
	return 5.0 * sin(x * 0.015) * smoothstep(30.0, 130.0, absf(x))


static func road_distance(x: float, z: float) -> float:
	var distance := minf(absf(x) - 5.4, absf(z) - 5.4)
	for axis: float in AXES:
		if axis == 0.0:
			continue
		distance = minf(distance, absf(x - axis - road_x_offset(z)) - 3.25)
		distance = minf(distance, absf(z - axis - road_z_offset(x, axis)) - 3.25)
	# Preserve the full two-lane approach, including the gutter at the pilot.
	if x >= PILOT_WEST - 6.0 and x <= PILOT_EAST + 6.0:
		distance = minf(distance, absf(z + 250.0 - road_z_offset(x, -250.0)) - 4.55)
	return distance


static func base_grade(x: float, z: float) -> float:
	var slope := 8.5 - x * 0.017 - z * 0.014 + 1.6 * sin(z * 0.013)
	var pilot_weight := (1.0 - smoothstep(27.0, 77.0, absf(x + 290.0))) * (1.0 - smoothstep(27.0, 67.0, absf(z + 245.0)))
	return lerpf(slope, 16.0, pilot_weight)


static func bridge_center(x: float) -> float:
	return -250.0 + road_z_offset(x, -250.0)


static func cross_street_x(axis: float, z: float) -> float:
	return axis + (0.0 if axis == 0.0 else road_x_offset(z))


func height(x: float, z: float) -> float:
	var distance := road_distance(x, z)
	var terrace := base_grade(x, z)
	var slope := smoothstep(4.0, 26.0, distance)
	var hill := (noise.get_noise_2d(x, z) * 8.0 + 3.0 * sin(x * 0.032) * cos(z * 0.023)) * slope
	var pilot_flat := (1.0 - smoothstep(29.0, 48.0, absf(x + 290.0))) * (1.0 - smoothstep(25.0, 40.0, absf(z + 245.0)))
	var gully := (1.0 - smoothstep(4.0, 12.0, absf(x + 200.0))) * (1.0 - smoothstep(8.0, 30.0, absf(z + 247.0)))
	var edge := smoothstep(477.0, 500.0, maxf(absf(x), absf(z))) * 13.0
	var hills := 5.4 * sin(x * 0.010 + z * 0.004) + 4.2 * cos(z * 0.013 - x * 0.005)
	hill += hills * smoothstep(24.0, 54.0, distance)
	var ground := terrace + hill * (1.0 - pilot_flat) - gully * 4.3 + edge
	for pad: Vector2 in INTERIOR_PADS:
		var offset := Vector2(x - pad.x, z - pad.y - 6.5).abs()
		if offset.x < 15.0 and offset.y < 15.0:
			var weight := (1.0 - smoothstep(9.0, 15.0, offset.x)) * (1.0 - smoothstep(8.5, 15.0, offset.y))
			ground = lerpf(ground, base_grade(pad.x, pad.y) - 0.03, weight)
	var point := Vector2(x, z)
	if RAIL_SITE.has_point(point):
		ground = lerpf(ground, base_grade(RAIL_CENTER.x, RAIL_CENTER.y), _pad_weight(RAIL_SITE, point))
	if AIRPORT_SITE.has_point(point):
		ground = lerpf(ground, base_grade(AIRPORT_CENTER.x, AIRPORT_CENTER.y), _pad_weight(AIRPORT_SITE, point))
	if CIVIC_PLAZA.has_point(point):
		ground = lerpf(ground, base_grade(190.0, -120.0), _pad_weight(CIVIC_PLAZA, point))
	var overlook := ((point - OVERLOOK) / Vector2(66, 47)).length()
	ground += (1.0 - smoothstep(0.20, 1.0, overlook)) * smoothstep(5.0, 19.0, distance) * 38.0
	return ground


static func _pad_weight(rect: Rect2, point: Vector2) -> float:
	var reach := (point - rect.get_center()).abs()
	return smoothstep(0.0, 8.0, minf(rect.size.x * 0.5 - reach.x, rect.size.y * 0.5 - reach.y))


func place(id: String) -> Vector3:
	var entry: Array = PLACES[id]
	var x: float = entry[1]
	var z: float = entry[2]
	return Vector3(x, height(x, z), z)


static func parcels(key: Vector2i) -> Array[Dictionary]:
	if not parcel_cache.has(key):
		parcel_cache[key] = _build_parcels(key)
	return parcel_cache[key]


static func _build_parcels(key: Vector2i) -> Array[Dictionary]:
	var result := _original_parcels(key)
	var corner := origin(key)
	var zone := district(corner.x + 50, corner.y + 50)
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + key.x * 4519 + key.y * 6079
	var candidates: Array[Dictionary] = []
	for z: float in [16, 33, 50, 67, 84]:
		for x: float in [16, 33, 50, 67, 84]:
			var at := corner + Vector2(x, z) + Vector2(rng.randf_range(-2.0, 2.0), rng.randf_range(-2.0, 2.0))
			candidates.append({"at": at, "score": absf(road_distance(at.x, at.y) - 15.0) + rng.randf_range(0, 8)})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.score < b.score)
	var target: int = [4, 6, 5, 4][zone]
	var limit := LIMIT - 45
	for candidate: Dictionary in candidates:
		if result.size() >= target:
			break
		var at: Vector2 = candidate.at
		if at.abs().x > limit or at.abs().y > limit:
			continue
		var size := Vector2(rng.randf_range(8.0, 13.0), rng.randf_range(8.0, 12.5))
		if zone == 3:
			size = Vector2(rng.randf_range(13.0, 18.0), rng.randf_range(10.0, 15.0))
		var box := Rect2(at - size * 0.5, size)
		if not roadside_clear(box, 3.8) or not available(box, result, 3.5):
			continue
		var levels := rng.randi_range(2, 4) if zone == 1 else (rng.randi_range(1, 3) if zone == 2 else rng.randi_range(1, 2))
		var facing := road_facing(at)
		result.append({"center": at, "size": size, "levels": levels, "zone": zone, "finish": rng.randi_range(0, 3),
			"infill": true, "facing": facing})
	return result


static func roadside_clear(bounds: Rect2, margin: float) -> bool:
	for u: float in [0.0, 0.5, 1.0]:
		for v: float in [0.0, 0.5, 1.0]:
			var p := bounds.position + bounds.size * Vector2(u, v)
			if road_distance(p.x, p.y) < margin:
				return false
	return true


static func available(bounds: Rect2, built: Array[Dictionary], padding: float) -> bool:
	# Reserve the full authored Hillview corridor, station ramps, and landmark yards.
	if bounds.intersects(Rect2(-391, -263, 261, 32)):
		return false
	for entry: Array in PLACES.values():
		if bounds.intersects(Rect2(entry[1] - 13.0, entry[2] - 10.0, 26.0, 29.0)):
			return false
	for entry: Array in LANDMARKS:
		var size: Vector2 = entry[2] + Vector2.ONE * 10.0
		if bounds.intersects(Rect2(entry[1] - size * 0.5, size)):
			return false
	for site: Rect2 in STREET_FEATURES:
		if bounds.intersects(site):
			return false
	for parcel: Dictionary in built:
		var size: Vector2 = parcel.size + Vector2.ONE * padding * 2.0
		if bounds.intersects(Rect2(parcel.center - size * 0.5, size)):
			return false
	return true


static func road_facing(point: Vector2) -> Vector2:
	var direction := Vector2.DOWN
	var nearest := INF
	for axis: float in AXES:
		var across := cross_street_x(axis, point.y) - point.x
		var along := axis + (road_z_offset(point.x, axis) if axis != 0.0 else 0.0) - point.y
		if absf(across) < nearest:
			nearest = absf(across)
			direction = Vector2(signf(across), 0)
		if absf(along) < nearest:
			nearest = absf(along)
			direction = Vector2(0, signf(along))
	return direction


static func _original_parcels(key: Vector2i) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + key.x * 983 + key.y * 6599
	var result: Array[Dictionary] = []
	var corner := origin(key)
	var zone := district(corner.x + 50, corner.y + 50)
	var target := [2, 2, 2, 1][zone] as int
	for index in 8:
		if result.size() >= target:
			break
		var footprint := Vector2(rng.randf_range(10, 18), rng.randf_range(10, 18))
		var candidate := corner + Vector2(rng.randf_range(17, 83), rng.randf_range(17, 83))
		if zone == 1 or zone == 2:
			var front := 0.0
			for axis: float in AXES:
				if absf(axis - candidate.y) < absf(front - candidate.y):
					front = axis
			var roadside := front + (0.0 if front == 0.0 else road_z_offset(candidate.x, front)) + rng.randf_range(15.0, 21.0) * signf(candidate.y - front)
			if roadside > corner.y + 12.0 and roadside < corner.y + 88.0:
				candidate.y = roadside
		if candidate.abs().x > 461 or candidate.abs().y > 461 or road_distance(candidate.x, candidate.y) < 15:
			continue
		if candidate.x > -390 and candidate.x < -130 and absf(candidate.y + 250) < 23:
			continue
		var occupied := false
		for entry: Array in PLACES.values():
			if candidate.distance_to(Vector2(entry[1], entry[2])) < 27:
				occupied = true
		for entry: Array in LANDMARKS:
			if candidate.distance_to(entry[1]) < 30:
				occupied = true
		var bounds := Rect2(candidate - footprint * 0.5, footprint)
		if bounds.intersects(RAIL_SITE) or bounds.intersects(AIRPORT_SITE) or bounds.intersects(CIVIC_PLAZA) or bounds.intersects(OVERLOOK_SITE):
			occupied = true
		for other in result:
			if candidate.distance_to(other.center) < 26:
				occupied = true
		if not occupied:
			result.append({"center": candidate, "size": footprint, "levels": rng.randi_range(1, 4 if zone < 2 else 2),
				"zone": zone, "finish": rng.randi_range(0, 3)})
	return result
