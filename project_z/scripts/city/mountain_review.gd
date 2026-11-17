extends "res://scripts/city/kaldran_world.gd"
## Compatibility scene: the normal map now has the same integration.
var mountain_stream: Node3D:
	get:return mountains.streamer if mountains else null
