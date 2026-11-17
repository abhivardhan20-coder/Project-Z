extends "res://scripts/city/city.gd"

const MOUNTAINS := preload("res://scripts/city/mountain_world.gd")
var mountains: Node3D
var travelling := false

func _ready() -> void:
	super._ready()
	for name in ["AlpineBasin","EasternSkyline","BasinApartmentBands","FoothillConifers"]:
		var old_scenery := layout.get_node_or_null(name)
		if old_scenery:old_scenery.queue_free()
	mountains=MOUNTAINS.new();mountains.name="KaldranMountains";add_child(mountains)
	mountains.configure(player.camera,player,city_layout)
	ui.mountain_travel_available=true

func _process(delta: float) -> void:
	super._process(delta)
	if not mountains:return
	mountains.update_weather(sky.wetness,sky.environment.fog_light_color,.000013+float(state.weather)*.000005,state.quality)
	ui.at_mountain_trail=mountains.in_mountains(player.global_position)

func _command(command: String,value: Variant) -> void:
	if command=="mountain_travel":
		travel_to_trail()
	elif command=="city_travel":
		return_to_city()
	else:super._command(command,value)

func travel_to_trail() -> void:
	if not playing or travelling:return
	travelling=true
	if player.driving:_exit_car()
	state.flags["mountain_return"]={"position":player.global_position,"yaw":player.rotation.y}
	player.playable=false
	mountains.ensure_sector()
	player.global_position=mountains.trail_spawn()
	player.rotation.y=float(mountains.cfg.spawn_yaw)
	player.eye.rotation.x=-.05
	player.velocity=Vector3.ZERO;player.last_fall_speed=0
	for i in 4:await get_tree().physics_frame
	_open("");ui.announce("Crown Approach · Mountain trail")
	_checkpoint(false)
	travelling=false

func return_to_city() -> void:
	if not playing or travelling:return
	var saved: Dictionary=state.flags.get("mountain_return",{})
	var point: Vector3=saved.get("position",SPAWN)
	if not point.is_finite() or absf(point.x)>=PLAN.LIMIT or absf(point.z)>=PLAN.LIMIT or absf(point.y)>140:point=SPAWN
	stream.refresh(point,true)
	player.global_position=point
	player.rotation.y=float(saved.get("yaw",2.47))
	player.velocity=Vector3.ZERO;player.last_fall_speed=0
	player.eye.rotation.x=0
	state.flags.erase("mountain_return")
	mountains.release_sector()
	_open("");ui.announce("Returned to Kaldran City")
	_checkpoint(false)

func _begin() -> void:
	if mountains:
		if mountains.in_mountains(player.global_position):mountains.ensure_sector()
		else:mountains.release_sector()
	super._begin()

func _outside_playable_world(point: Vector3) -> bool:
	if point.x > -2752 and point.x < -320 and point.z > -12992 and point.z < -10560 and point.y > 0 and point.y < 2500:
		return false
	return super._outside_playable_world(point)

func _update_hud() -> void:
	super._update_hud()
	if mountains and mountains.in_mountains(player.global_position):
		ui.field_label.text="KALDRAN MOUNTAINS"
		ui.district_label.text="Crown Approach · Alpine trail"
	else:ui.field_label.text="KALDRAN CITY"
