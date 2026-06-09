extends CharacterBody2D

# Health
# TODO: Make a ui, items and health bullets
@export var health: int = 100

# Horizontal movement
@export var max_speed: float = 170.0
@export var ground_accel: float = 800.0
@export var ground_friction: float = 1000.0
@export var air_accel: float = 500.0
@export var air_friction: float = 200.0
@export var turn_accel_mult: float = 1.7  # accel against current velocity is stronger

# Jump / gravity
@export var jump_velocity: float = -340.0
@export var gravity_rising: float = 900.0    # while holding jump and going up
@export var gravity_falling: float = 1600.0  # released, or falling
@export var max_fall_speed: float = 600.0

# Apex hang — lower gravity near the peak so the top of the jump feels floaty
@export var apex_threshold: float = 80.0
@export var apex_gravity_mult: float = 0.55

# Hard landing — when you crash down from height, brief input slowdown + bigger squash
@export var hard_land_velocity: float = 450.0
@export var hard_land_lockout: float = 0.15
@export var landing_control_mult: float = 0.35

# Squash & stretch (visual juice)
@export var jump_stretch: Vector2 = Vector2(0.92, 1.1)     # tall + thin on takeoff
@export var land_squash: Vector2 = Vector2(1.06, 0.9)      # wide + short on landing
@export var hard_land_squash: Vector2 = Vector2(1.2, 0.78)
@export var squash_duration: float = 0.12

# Forgiveness windows
@export var coyote_time: float = 0.1
@export var jump_buffer_time: float = 0.12

# Parry bullets and hit stop duration
@export var max_bullets: int = 10
@export var hit_stop_duration: float = 0.08

var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var landing_lockout_timer: float = 0.0
var was_on_floor: bool = true
var was_skidding: bool = false
var sprite_tween: Tween
var facing := 1
var parry_timer := 0.0
var bullets: int = 0

const PARRY_TIME := 0.2
const SlashScene := preload("res://scenes/Slash.tscn")

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

signal landed(impact_velocity: float, hard: bool)
signal parry_succeeded

func _ready() -> void:
	bullets = max_bullets

func _physics_process(delta: float) -> void:
	var on_floor := is_on_floor()
	var direction := Input.get_axis("move_left", "move_right")
	if direction != 0.0:
		facing = int(signf(direction))

	_handle_attack()
	_handle_parry(delta)

	var jumped := _handle_jump(on_floor, delta)
	landing_lockout_timer = max(landing_lockout_timer - delta, 0.0)

	# Horizontal movement — accel ramp + asymmetric turn boost.
	# Reduced control briefly after a hard landing so it feels weighty.
	var control_mult: float = landing_control_mult if landing_lockout_timer > 0.0 else 1.0
	var target := direction * max_speed * control_mult
	var accel: float = ground_accel if on_floor else air_accel
	var friction: float = ground_friction if on_floor else air_friction

	if direction != 0.0:
		var opposing := signf(direction) != signf(velocity.x) and velocity.x != 0.0
		var a := accel * (turn_accel_mult if opposing else 1.0)
		velocity.x = move_toward(velocity.x, target, a * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)

	# Capture impact velocity before move_and_slide zeroes vy on landing.
	var impact_vy := velocity.y

	# Skid: grounded, pressing against current velocity, still moving fast.
	var is_skidding := on_floor \
		and direction != 0.0 \
		and signf(direction) != signf(velocity.x) \
		and absf(velocity.x) > max_speed * 0.4

	# Animation
	if direction != 0.0:
		sprite.flip_h = direction < 0.0
	var attacking := sprite.animation == "attack1" and sprite.is_playing()
	var parrying := sprite.animation == "parry" and sprite.is_playing()
	if attacking or parrying:
		pass
	elif not on_floor:
		sprite.play("jump")
	elif is_skidding:
		# Placeholder: drag the run animation until a real skid anim exists.
		sprite.play("run")
		sprite.speed_scale = 0.3
	elif absf(velocity.x) > 5.0:
		sprite.play("run")
		sprite.speed_scale = 1.0
	else:
		sprite.play("idle")
		sprite.speed_scale = 1.0

	# Rising edge: hook for skid VFX/SFX once you have them.
	if is_skidding and not was_skidding:
		pass  # TODO: emit dust particles, play scuff sfx
	was_skidding = is_skidding

	move_and_slide()

	# Landing detection: rising-edge floor contact, with hard-landing branch.
	var on_floor_now := is_on_floor()
	if on_floor_now and not was_on_floor and not jumped:
		var hard := impact_vy >= hard_land_velocity
		if hard:
			landing_lockout_timer = hard_land_lockout
			_squash(hard_land_squash)
		else:
			_squash(land_squash)
		landed.emit(impact_vy, hard)
	was_on_floor = on_floor_now

func _handle_jump(on_floor: bool, delta: float) -> bool:
	# Variable gravity + apex hang.
	var jump_held := Input.is_action_pressed("jump")
	var g: float = gravity_rising if (velocity.y < 0.0 and jump_held) else gravity_falling
	if not on_floor and absf(velocity.y) < apex_threshold:
		g *= apex_gravity_mult
	if not on_floor:
		velocity.y += g * delta
		velocity.y = min(velocity.y, max_fall_speed)

	# Coyote + jump buffer.
	coyote_timer = coyote_time if on_floor else coyote_timer - delta
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer_time
	else:
		jump_buffer_timer -= delta

	# Execute jump if both windows are open.
	if jump_buffer_timer > 0.0 and coyote_timer > 0.0:
		velocity.y = jump_velocity
		jump_buffer_timer = 0.0
		coyote_timer = 0.0
		_squash(jump_stretch)
		return true
	return false

func _handle_attack() -> void:
	if not Input.is_action_just_pressed("attack"):
		return
	sprite.play("attack1")
	var slash := SlashScene.instantiate()
	slash.position = Vector2(15 * facing, 0)
	slash.flip_h = facing < 0
	add_child(slash)

func _handle_parry(delta: float) -> void:
	parry_timer = max(parry_timer - delta, 0.0)
	if not Input.is_action_just_pressed("parry"):
		return
	if bullets <= 0 or parry_timer > 0.0:
		return
	sprite.play("parry")
	bullets -= 1
	parry_timer = PARRY_TIME

func is_parrying() -> bool:
	return parry_timer > 0.0
 
func try_parry() -> bool:
	if not is_parrying():
		return false
	parry_timer = 0.0
	parry_succeeded.emit()
	_hit_stop(hit_stop_duration)
	return true

func _hit_stop(duration: float) -> void:
	if Engine.time_scale < 1.0:
		return
	Engine.time_scale = 0.05
	await get_tree().create_timer(duration, true,false, true).timeout
	Engine.time_scale = 1.0

func _squash(scale_target: Vector2) -> void:
	if sprite_tween and sprite_tween.is_valid():
		sprite_tween.kill()
	sprite.scale = scale_target
	sprite_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	sprite_tween.tween_property(sprite, "scale", Vector2.ONE, squash_duration)
