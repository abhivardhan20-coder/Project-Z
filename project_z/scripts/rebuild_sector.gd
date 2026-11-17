extends "res://scripts/build_native.gd"

func _build() -> void:
	await _build_near()
	print("NATIVE_SECTOR_REBUILT")
	quit(0)
