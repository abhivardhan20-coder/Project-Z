extends CharacterBody3D

var camera: Camera3D
var active := false
var fly := false
var yaw := 0.0
var pitch := -.05
var fly_speed := 160.0

func _ready() -> void:
	var capsule := CapsuleShape3D.new()
	capsule.radius=.32;capsule.height=1.8
	var collider := CollisionShape3D.new()
	collider.shape=capsule;collider.position.y=.9
	add_child(collider)
	floor_max_angle=deg_to_rad(46)
	floor_snap_length=.5
	collision_layer=2;collision_mask=1

func _unhandled_input(event: InputEvent) -> void:
	if not active:return
	if event is InputEventMouseMotion and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
		yaw-=event.relative.x*.002
		pitch=clampf(pitch-event.relative.y*.002,-1.45,1.45)
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
		Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
		Input.mouse_mode=Input.MOUSE_MODE_VISIBLE

func _physics_process(delta: float) -> void:
	if not active:return
	var input := Vector2(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
	var basis_y := Basis(Vector3.UP,yaw)
	var direction := basis_y*Vector3(input.x,0,input.y).normalized()
	if fly:
		var forward := -Basis.from_euler(Vector3(pitch,yaw,0)).z
		direction=basis_y.x*input.x-forward*input.y
		direction.y+=float(Input.is_physical_key_pressed(KEY_E))-float(Input.is_physical_key_pressed(KEY_Q))
		global_position+=direction*fly_speed*(4 if Input.is_physical_key_pressed(KEY_SHIFT) else 1)*delta
	else:
		var speed := 7.2 if Input.is_physical_key_pressed(KEY_SHIFT) else 3.4
		velocity.x=move_toward(velocity.x,direction.x*speed,delta*15)
		velocity.z=move_toward(velocity.z,direction.z*speed,delta*15)
		if not is_on_floor():velocity.y-=19.6*delta
		elif Input.is_physical_key_pressed(KEY_SPACE):velocity.y=6
		else:velocity.y=-.2
		move_and_slide()
		global_position.x=clampf(global_position.x,-2912,-160)
		global_position.z=clampf(global_position.z,-13152,-10400)
		if global_position.y<0:get_parent().enter_sector()
	camera.global_position=global_position+Vector3.UP*1.65
	camera.rotation=Vector3(pitch,yaw,0)
