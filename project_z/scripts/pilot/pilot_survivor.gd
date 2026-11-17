extends "res://scripts/neighborhood/neighborhood_survivor.gd"

const DRIVER := preload("res://scripts/pilot/pilot_driver.gd")

var sedan: DRIVER
var driving := false


func _ready() -> void:
	super._ready()
	collision_mask |= DRIVER.VEHICLE_LAYER
	camera.far = 1400.0


func _unhandled_input(event: InputEvent) -> void:
	if active and not finished and event.is_action_pressed("neighborhood_interact") and not event.is_echo():
		if driving:
			_exit_vehicle()
			get_viewport().set_input_as_handled()
			return
		if sedan and sedan.can_board(self, camera):
			_enter_vehicle()
			get_viewport().set_input_as_handled()
			return
	if not driving or not active or event.is_action_pressed("neighborhood_pause"):
		super._unhandled_input(event)


func _physics_process(delta: float) -> void:
	if driving:
		sedan.controls_enabled = active and not finished
		global_position = sedan.seat.global_position
		return
	super._physics_process(delta)


func take_damage(amount: int) -> void:
	if not driving:
		super.take_damage(amount)


func _enter_vehicle() -> void:
	driving = true
	focused = null
	velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 0
	sedan.board()
	announce("Sedan running. WASD to drive, Space to brake, E to exit.")
	state_changed.emit()


func _exit_vehicle() -> void:
	var candidate: Variant = sedan.safe_exit(self)
	if candidate == null:
		announce("Stop the sedan and leave room by the door.")
		return
	driving = false
	sedan.leave()
	global_position = candidate
	rotation.y = sedan.rotation.y + PI
	camera.rotation.x = 0.0
	camera.make_current()
	collision_layer = 2
	collision_mask = 1 | 4 | DRIVER.VEHICLE_LAYER
	announce("Exited sedan.")
	state_changed.emit()
