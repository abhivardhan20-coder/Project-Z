extends SkeletonModifier3D

var pitch := 0.0
var shoulder := -1
var arm_pose: Dictionary[int, Quaternion] = {}


func configure(aim: Animation) -> void:
	var rig := get_skeleton()
	shoulder = rig.find_bone("Spine2")
	for track in aim.get_track_count():
		if aim.track_get_type(track) != Animation.TYPE_ROTATION_3D:
			continue
		var path := aim.track_get_path(track)
		if path.get_subname_count() != 1:
			continue
		var bone := String(path.get_subname(0))
		if bone.begins_with("Left") or bone.begins_with("Right"):
			if not ("Shoulder" in bone or "Arm" in bone or "Hand" in bone):
				continue
		elif bone not in ["Spine2", "Neck", "Head"]:
			continue
		var index := rig.find_bone(bone)
		if index >= 0:
			arm_pose[index] = aim.rotation_track_interpolate(track, 0.08)


func _process_modification_with_delta(_delta: float) -> void:
	if influence <= 0.0 or not arm_pose.has(shoulder):
		return
	var rig := get_skeleton()
	for index: int in arm_pose:
		rig.set_bone_pose_rotation(index, arm_pose[index])
	var parent := rig.get_bone_parent(shoulder)
	var axis := rig.get_bone_global_pose(parent).basis.inverse() * Vector3.LEFT
	rig.set_bone_pose_rotation(shoulder, Quaternion(axis.normalized(), pitch) * arm_pose[shoulder])
