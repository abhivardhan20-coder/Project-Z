extends RefCounted

const DATA := preload("res://scripts/city/layout.gd")
const STATE := preload("res://scripts/city/state.gd")
const NAMES := ["Wake up", "Scavenge", "Secure shelter", "Restore water", "The signal", "Survive the night", "Safehouse established"]
const DESTINATIONS := ["safehouse", "corner_shop", "safehouse", "pump", "police", "safehouse", "safehouse"]

var state: STATE
var plan: DATA
var changed: Callable


func _init(progress: STATE, world_layout: DATA, on_changed: Callable) -> void:
	state = progress
	plan = world_layout
	changed = on_changed


func objective() -> String:
	match state.stage:
		0:
			if not state.objects.has("starter_cache"):
				return "Search the wooden supply case in the lobby."
			if not state.flags.has("crowbar_equipped"):
				return "Open your pack and equip the crowbar."
			return "Leave Hillview Steps through the lobby door."
		1: return "Cross P06 and search the corner shop's stock case for provisions and repair supplies."
		2: return "Craft a reinforcement kit and a generator repair kit. Use both at Hillview Steps."
		3:
			if state.objects.has("pump_cache"):
				return "Craft a water filter, then fit it to the safehouse water barrel."
			return "Recover a filter assembly at Bank Pumping Station in the Utility district."
		4:
			if state.objects.has("police_cache"):
				return "Return to Hillview and install the receiver in the safehouse radio."
			return "Find a receiver in the Civic Police Annex. Check its station log."
		5:
			if state.flags.has("siege"):
				return "Hold Hillview Steps. Survive the infected approaching from P06."
			return "Use the safehouse bed to wait for night."
		_: return "Shelter, water, power and radio are online. Explore Kaldran at your own pace."


func marker() -> Vector3:
	var id: String = DESTINATIONS[state.stage]
	if (state.stage == 3 and state.objects.has("pump_cache")) or (state.stage == 4 and state.objects.has("police_cache")):
		id = "safehouse"
	return plan.place(id)


func evaluate(player: CharacterBody3D) -> void:
	var next := false
	match state.stage:
		0: next = state.objects.has("starter_cache") and state.flags.has("crowbar_equipped") and player.global_position.z < -241.1
		1: next = state.objects.has("shop_cache")
		2: next = state.flags.has("power") and state.flags.has("barrier")
		3: next = state.flags.has("water")
		4: next = state.flags.has("radio")
		5: next = state.defeated.has("night_1") and state.defeated.has("night_2") and state.defeated.has("night_3")
	if next:
		state.stage += 1
		changed.call(state.stage)
