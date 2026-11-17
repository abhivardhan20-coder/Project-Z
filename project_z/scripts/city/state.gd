extends RefCounted

const DATA := preload("res://scripts/city/layout.gd")
const VERSION := 1
const SAVE := "kaldran.save"
const SETTINGS := "kaldran.settings"
const CAPACITY := 18.0
const CLIP := 8

var base_path := "user://"
var items: Dictionary
var recipes: Dictionary
var inventory: Dictionary = {}
var storage: Dictionary = {}
var objects: Dictionary = {}
var defeated: Dictionary = {}
var discovered: Dictionary = {}
var flags: Dictionary = {}
var stage := 0
var weapon := ""
var rounds := 0
var clock := 0.30
var weather := 0
var quality := 0
var sound := true
var fov := 72.0
var sensitivity := 0.0024
var ui_scale := 1.0
var bindings: Dictionary = {}


func _init() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://resources/survival.json"))
	items = data.items
	recipes = data.recipes
	reset()


func reset() -> void:
	inventory.clear()
	inventory.merge({"water": 1, "food": 1})
	storage.clear()
	objects.clear()
	defeated.clear()
	discovered.clear()
	flags.clear()
	stage = 0
	weapon = ""
	rounds = 0
	clock = 0.30
	weather = 0


func weight(pack: Dictionary) -> float:
	var total := 0.0
	for id in pack:
		total += float(items[id][1]) * int(pack[id])
	return total


func has_all(pack: Dictionary, needed: Dictionary) -> bool:
	for id in needed:
		if int(pack.get(id, 0)) < int(needed[id]):
			return false
	return true


func add(pack: Dictionary, id: String, amount: int) -> void:
	var updated := int(pack.get(id, 0)) + amount
	if updated > 0:
		pack[id] = updated
	else:
		pack.erase(id)


func take(loot: Dictionary) -> bool:
	if weight(inventory) + weight(loot) > CAPACITY:
		return false
	for id: String in loot:
		add(inventory, id, loot[id])
	return true


func transfer(id: String, deposit: bool) -> bool:
	var from := inventory if deposit else storage
	var to := storage if deposit else inventory
	if not from.has(id) or (deposit and id == weapon) or (not deposit and weight(to) + float(items[id][1]) > CAPACITY):
		return false
	add(from, id, -1)
	add(to, id, 1)
	return true


func craft(id: String) -> bool:
	if not recipes.has(id) or not has_all(inventory, recipes[id]):
		return false
	var after := weight(inventory) - weight(recipes[id]) + float(items[id][1])
	if after > CAPACITY:
		return false
	for input: String in recipes[id]:
		add(inventory, input, -int(recipes[id][input]))
	add(inventory, id, 1)
	return true


func save(player: CharacterBody3D, car: Dictionary = {}) -> bool:
	var record := {
		"version": VERSION, "position": player.global_position, "yaw": player.rotation.y,
		"health": player.health, "hunger": player.hunger, "thirst": player.thirst,
		"stamina": player.stamina, "exposure": player.exposure,
		"inventory": inventory, "storage": storage, "objects": objects, "defeated": defeated,
		"discovered": discovered, "flags": flags, "stage": stage, "weapon": weapon,
		"rounds": rounds, "clock": clock, "weather": weather, "car": car,
	}
	return _write(SAVE, record)


func read_save() -> Dictionary:
	for suffix: String in ["", ".bak"]:
		var data := _read(SAVE + suffix)
		if _valid_save(data):
			return data
	return {}


func load_record(data: Dictionary, player: CharacterBody3D) -> void:
	reset()
	inventory.clear()
	inventory.merge(data.inventory)
	storage.merge(data.storage)
	objects.merge(data.objects)
	defeated.merge(data.defeated)
	discovered.merge(data.discovered)
	flags.merge(data.flags)
	stage = int(data.stage)
	weapon = data.weapon
	rounds = int(data.rounds)
	clock = float(data.clock)
	weather = int(data.weather)
	player.position = data.position
	player.rotation.y = float(data.yaw)
	player.velocity = Vector3.ZERO
	player.health = float(data.health)
	player.hunger = float(data.hunger)
	player.thirst = float(data.thirst)
	player.stamina = float(data.stamina)
	player.exposure = float(data.exposure)


func load_settings() -> void:
	var data := _read(SETTINGS)
	if data.is_empty():
		data = _read(SETTINGS + ".bak")
	quality = clampi(int(data.get("quality", quality)), 0, 2)
	sound = bool(data.get("sound", sound))
	fov = clampf(float(data.get("fov", fov)), 58, 93)
	sensitivity = clampf(float(data.get("sensitivity", sensitivity)), 0.0008, 0.007)
	ui_scale = clampf(float(data.get("ui_scale", ui_scale)), 0.8, 1.3)
	var keys: Variant = data.get("bindings", {})
	if keys is Dictionary:
		bindings = keys


func save_settings() -> bool:
	return _write(SETTINGS, {"quality": quality, "sound": sound, "fov": fov, "sensitivity": sensitivity,
		"ui_scale": ui_scale, "bindings": bindings})


func _valid_save(data: Dictionary) -> bool:
	if data.get("version") != VERSION or not data.get("position") is Vector3:
		return false
	var point: Vector3 = data.position
	var in_city := absf(point.x) < DATA.LIMIT and absf(point.z) < DATA.LIMIT and absf(point.y) <= 140.0
	var on_trail := point.x > -2752 and point.x < -320 and point.z > -12992 and point.z < -10560 and point.y > 0 and point.y < 2500
	if not point.is_finite() or not (in_city or on_trail):
		return false
	var car: Variant = data.get("car", {})
	if not car is Dictionary:
		return false
	if not car.is_empty():
		var parked: Variant = car.get("position")
		var heading: Variant = car.get("yaw")
		if not parked is Vector3 or not parked.is_finite() or absf(parked.x) >= DATA.LIMIT or absf(parked.z) >= DATA.LIMIT or absf(parked.y) > 140.0:
			return false
		if not heading is float or not is_finite(heading) or not car.get("headlights") is bool or not car.get("driving") is bool:
			return false
	for key in ["inventory", "storage", "objects", "defeated", "discovered", "flags"]:
		if not data.get(key) is Dictionary or data[key].size() > 4096:
			return false
	for pack: Dictionary in [data.inventory, data.storage]:
		for id in pack:
			if not items.has(id) or not pack[id] is int or pack[id] < 1 or pack[id] > 10000:
				return false
	for key in ["health", "hunger", "thirst", "stamina", "exposure", "yaw", "stage", "rounds", "clock", "weather"]:
		if not (data.get(key) is float or data.get(key) is int) or not is_finite(float(data[key])):
			return false
	for key in ["health", "hunger", "thirst", "stamina", "exposure"]:
		if data[key] < 0 or data[key] > 100:
			return false
	return data.health > 0 and data.stage in range(7) and data.rounds in range(CLIP + 1) and data.weather in range(3) and data.clock >= 0.0 and data.clock < 1.0 and data.get("weapon") in ["", "crowbar", "pistol"]


func _read(name: String) -> Dictionary:
	var path := base_path.path_join(name)
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() < 4 or file.get_length() > 1024 * 1024:
		return {}
	var bytes := file.get_32()
	if bytes != file.get_length() - 4:
		return {}
	var data: Variant = bytes_to_var(file.get_buffer(bytes))
	return data if data is Dictionary else {}


func _write(name: String, payload: Dictionary) -> bool:
	var path := base_path.path_join(name)
	var staging := path + ".tmp"
	var file := FileAccess.open(staging, FileAccess.WRITE)
	if file == null:
		return false
	file.store_var(payload, false)
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		return false
	if FileAccess.file_exists(path):
		# Keep the last valid primary as the recovery copy.
		var old := _read(name)
		if not old.is_empty() and (name != SAVE or _valid_save(old)):
			if DirAccess.copy_absolute(path, path + ".bak") != OK:
				return false
	return DirAccess.rename_absolute(staging, path) == OK
