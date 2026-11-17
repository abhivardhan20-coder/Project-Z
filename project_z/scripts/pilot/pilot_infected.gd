extends "res://scripts/neighborhood/neighborhood_infected.gd"

const ANIMATION_PREFIX := "PZ188_Infected_"
const IMPACT_DELAY := 0.38

var animator: AnimationPlayer
var windup := 0.0
var current_clip := ""


func _ready() -> void:
	super._ready()
	collision_mask |= 8
	animator = visual.find_children("*", "AnimationPlayer", true, false).front() as AnimationPlayer
	if animator:
		for clip in ["Idle", "Shamble", "Pursuit"]:
			var animation := animator.get_animation(ANIMATION_PREFIX + clip)
			if animation:
				animation.loop_mode = Animation.LOOP_LINEAR
	_play("Idle")


func _physics_process(delta: float) -> void:
	if health == 0 or not target.active:
		return
	stagger = maxf(stagger - delta, 0.0)
	attack_timer = maxf(attack_timer - delta, 0.0)
	var offset := target.global_position - global_position
	var height_difference := absf(offset.y)
	offset.y = 0.0
	var distance := offset.length()
	var visible := distance < 26.0 and target.unobstructed(global_position + Vector3.UP, target.global_position + Vector3.UP)
	awake = distance < 6.0 or visible or (awake and distance < 44.0)
	var direction := Vector3.ZERO
	var can_reach := visible and distance < 1.53 and height_difference < 1.15
	if windup > 0.0:
		windup = maxf(windup - delta, 0.0)
		if windup == 0.0 and can_reach and stagger == 0.0:
			target.take_damage(damage)
	elif awake and stagger == 0.0 and attack_timer < 0.45:
		if can_reach:
			if attack_timer == 0.0:
				windup = IMPACT_DELAY
				attack_timer = 1.18
				_play("LungeAttack")
		else:
			direction = _pursuit(offset, visible, delta)
	var facing := direction if direction.length_squared() > 0.01 else (offset.normalized() if awake else Vector3.ZERO)
	if facing.length_squared() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(-facing.x, -facing.z), minf(delta * 9.0, 1.0))
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	velocity.y = -0.65 if is_on_floor() else velocity.y - delta * 17.0
	move_and_slide()
	if stagger == 0.0 and windup == 0.0 and attack_timer < 0.45:
		_play(("Pursuit" if distance < 9.0 else "Shamble") if direction.length_squared() > 0.01 else "Idle")


func take_hit(amount: int) -> void:
	if health == 0:
		return
	health = maxi(0, health - amount)
	awake = true
	windup = 0.0
	if health > 0:
		stagger = 0.37
		_play("HitReaction", true)
		return
	remove_from_group("neighborhood_infected")
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	velocity = Vector3.ZERO
	_play("Death")
	killed.emit()


func _play(clip: String, restart: bool = false) -> void:
	if animator == null or (current_clip == clip and not restart):
		return
	current_clip = clip
	if restart:
		animator.stop()
	animator.play(ANIMATION_PREFIX + clip, 0.12 if not restart else 0.04)
