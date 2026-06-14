class_name Player extends CharacterBody2D

#  PLAYER CONTROLLER
#  Locomotion runs through a node-based state machine (see scripts/state_machine.gd
#  and scripts/states/*): idle / run / jump / fall / dash. Each frame the player
#  gathers input, runs the overlay abilities (attack / parry / stamina), ticks
#  the shared forgiveness timers, then lets the active state set velocity +
#  animation. move_and_slide and landing detection happen here, once, afterwards.
#
#  Attack and parry are NOT states — they're overlays that play on top of any
#  locomotion state, so you can swing while running or airborne.

# Health
# TODO: hook up a UI, items and health bullets.
@export var max_health: int = 5

# Healing (limited charges, refilled on respawn)
@export var max_heal_charges: int = 3
@export var heal_amount: int = 1

# Stamina level
@export var max_stamina: float = 100.0
@export var stamina_regan: float = 15.0
@export var attack_cost: float = 25.0
@export var dash_cost: float  = 25.0

# Attack
@export var attack_cooldown: float = 0.45     # min time between swings (anti-spam)

# Horizontal movement
@export var max_speed: float = 170.0
@export var ground_accel: float = 800.0
@export var ground_friction: float = 1000.0
@export var air_accel: float = 500.0
@export var air_friction: float = 200.0
@export var turn_accel_mult: float = 1.7      # accel is stronger when turning against current velocity

# Jump / gravity
@export var jump_velocity: float = -340.0
@export var max_air_jumps: int = 1            # extra mid-air jumps (1 = double jump; 0 = locked)
@export var gravity_rising: float = 900.0     # while holding jump and moving up
@export var gravity_falling: float = 1600.0   # released, or falling
@export var max_fall_speed: float = 600.0

# Apex hang — lower gravity near the peak so the top of the jump feels floaty.
@export var apex_threshold: float = 80.0
@export var apex_gravity_mult: float = 0.55

# Hard landing — crashing down from height gives a brief input slowdown + bigger squash.
@export var hard_land_velocity: float = 450.0
@export var hard_land_lockout: float = 0.15
@export var landing_control_mult: float = 0.35

# Squash & stretch (visual juice) -
@export var jump_stretch: Vector2 = Vector2(0.92, 1.1)   # tall + thin on takeoff
@export var land_squash: Vector2 = Vector2(1.06, 0.9)    # wide + short on landing
@export var hard_land_squash: Vector2 = Vector2(1.2, 0.78)
@export var squash_duration: float = 0.12

# Forgiveness windows -
@export var coyote_time: float = 0.1          # grace period to still jump after leaving a ledge
@export var jump_buffer_time: float = 0.12    # grace period to queue a jump before landing

# Parry / hit stop-
@export var max_bullets: int = 10
@export var hit_stop_duration: float = 0.08

# Dash -
@export var dash_speed: float = 350.0
@export var dash_duration: float = 0.2
@export var dash_cooldown: float = 0.5
@export var dash_freeze: float = 0.05         # brief windup hang before the burst
@export var dash_iframe_time: float = 0.25    # invincibility window granted by a dash

# Runtime state
var facing := 1                               # last non-zero input direction (-1 / +1)
var bullets: int = 0                          # parry charges remaining

var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var landing_lockout_timer: float = 0.0
var was_on_floor: bool = true                 # floor state last frame, for landing edge-detection
var was_skidding: bool = false                # skid state last frame, for skid edge-detection
var jumped_this_frame: bool = false           # set by the jump state, read by landing detection
var air_jumps: int = 0                        # mid-air jumps left; refilled on landing

var parry_timer := 0.0

var attack_cooldown_timer: float = 0.0        # > 0 while attack is on cooldown

var dash_timer: float = 0.0                   # > 0 while a dash is active
var dash_cooldown_timer: float = 0.0
var dash_dir: int = 1                          # direction latched at dash start
var dash_freeze_timer: float = 0.0            # > 0 during the pre-dash windup
var invincible_timer: float = 0.0             # > 0 while immune to damage (dash i-frames)
var dash_available: bool = true               # refilled on the ground, spent on dash (blocks air-dash spam)
var ghost_timer: float = 0.0                  # time gap for spawn ghost

var sprite_tween: Tween                       # active squash tween, killed before restarting

var stamina: float = 100.0                    #stamina make it cost while player have a movement

var health: int                               # set from max_health in _ready
var heal_charges: int                         # remaining heals; refilled on respawn

const PARRY_TIME := 0.2
const SLASH_SCENE := preload("res://scenes/Slash.tscn")
const GHOST_SCENE := preload("res://scenes/Ghost.tscn")
const CURRENCY_DROP_SCENE := preload("res://scenes/CurrencyDrop.tscn")
const GHOST_INTERVAL: float = 0.03

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health_diamonds = get_tree().get_first_node_in_group("health_diamonds")
@onready var stamina_bar = get_tree().get_first_node_in_group("stamina_bar")
@onready var heal_label = get_tree().get_first_node_in_group("heal_label")
@onready var currency_label = get_tree().get_first_node_in_group("currency_label")

var diamond_full = preload("res://ui/playing_ui/health.png")
var diamone_empty = preload("res://ui/playing_ui/health_empty.png")

var state_machine: PlayerStateMachine

signal landed(impact_velocity: float, hard: bool)
signal parry_succeeded

func _ready() -> void:
	add_to_group("player")          # lets enemies identify the player for contact damage

	# Respawn at the last save point (if we've rested), else the scene's start.
	if GameState.has_respawn:
		global_position = GameState.respawn_position

	health = max_health
	air_jumps = max_air_jumps
	heal_charges = max_heal_charges
	update_health_display()
	update_heal_display()
	bullets = max_bullets
	stamina_bar.max_value = max_stamina
	stamina_bar.value = stamina

	# Currency HUD: show current amount and keep it in sync.
	GameState.currency_changed.connect(_update_currency_label)
	_update_currency_label(GameState.currency)

	# If we died with currency, drop the recoverable "shade" at the death spot.
	if GameState.has_dropped:
		_spawn_currency_drop.call_deferred()

	# Build and start the locomotion state machine (begins in "idle").
	state_machine = PlayerStateMachine.new()
	add_child(state_machine)
	state_machine.setup(self)

# Main loop: gather input, run the overlay abilities + shared timers, let the
# active state drive locomotion, then resolve movement and landing once.
func _physics_process(delta: float) -> void:
	var on_floor := is_on_floor()
	var direction := Input.get_axis("move_left", "move_right")
	if direction != 0.0:
		facing = int(signf(direction))

	jumped_this_frame = false

	# Overlay abilities — run every frame regardless of locomotion state.
	_handle_attack(delta)
	_handle_parry(delta)
	_handle_stamina(delta)
	_handle_heal()

	# Shared timers that must tick no matter which state we're in.
	_tick_jump_windows(on_floor, delta)
	dash_cooldown_timer = max(dash_cooldown_timer - delta, 0.0)
	if on_floor:
		dash_available = true                 # touching the ground refills the dash
		air_jumps = max_air_jumps             # ...and the mid-air jumps
	landing_lockout_timer = max(landing_lockout_timer - delta, 0.0)
	invincible_timer = max(invincible_timer - delta, 0.0)

	# Locomotion: the active state sets velocity + animation and may transition.
	state_machine.update(delta)

	# Capture impact velocity before move_and_slide zeroes vy on landing.
	var impact_vy := velocity.y
	move_and_slide()

	# Landing detection: rising-edge floor contact, with a hard-landing branch.
	var on_floor_now := is_on_floor()
	if on_floor_now and not was_on_floor and not jumped_this_frame:
		var hard := impact_vy >= hard_land_velocity
		if hard:
			landing_lockout_timer = hard_land_lockout
			_squash(hard_land_squash)
		else:
			_squash(land_squash)
		landed.emit(impact_vy, hard)
	was_on_floor = on_floor_now


# --- Shared locomotion helpers (called by the states) -----------------------

# Current horizontal input axis (-1 / 0 / +1-ish).
func input_dir() -> float:
	return Input.get_axis("move_left", "move_right")

# Which grounded state to enter based on whether we're moving.
func ground_state() -> String:
	return "run" if input_dir() != 0.0 else "idle"

# Horizontal accel ramp + asymmetric turn boost. Control is reduced briefly
# after a hard landing so it feels weighty. Also flips the sprite to face input.
func apply_horizontal_movement(direction: float, on_floor: bool, delta: float) -> void:
	if direction != 0.0:
		sprite.flip_h = direction < 0.0
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

# Variable gravity with apex hang + fall-speed clamp. Only called by the air
# states (jump / fall), so it never runs while grounded or dashing.
func apply_gravity(delta: float) -> void:
	var jump_held := Input.is_action_pressed("jump")
	var g: float = gravity_rising if (velocity.y < 0.0 and jump_held) else gravity_falling
	if absf(velocity.y) < apex_threshold:
		g *= apex_gravity_mult
	velocity.y += g * delta
	velocity.y = min(velocity.y, max_fall_speed)

# Ticks the coyote + jump-buffer forgiveness windows every frame.
func _tick_jump_windows(on_floor: bool, delta: float) -> void:
	coyote_timer = coyote_time if on_floor else coyote_timer - delta
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer_time
	else:
		jump_buffer_timer -= delta

# True when both forgiveness windows are open — i.e. a grounded/coyote jump may fire.
func can_jump() -> bool:
	return jump_buffer_timer > 0.0 and coyote_timer > 0.0

# True for a mid-air (double) jump: a fresh press, past the coyote window, with
# air jumps still in the tank.
func can_air_jump() -> bool:
	return jump_buffer_timer > 0.0 and coyote_timer <= 0.0 and air_jumps > 0

# Single source of truth for launching a jump. The triggering state calls this,
# then transitions to the "jump" state (which just handles the animation).
func start_jump(is_air_jump: bool = false) -> void:
	if is_air_jump:
		air_jumps -= 1
	velocity.y = jump_velocity
	jump_buffer_timer = 0.0          # consume the buffered press
	coyote_timer = 0.0
	jumped_this_frame = true         # tells landing-detection to ignore this frame
	_squash(jump_stretch)
	if not is_action_animating():
		sprite.play("jump")

# True when a dash may start (the dash state itself spends it).
func wants_dash() -> bool:
	return Input.is_action_just_pressed("dash") and dash_available \
		and dash_cooldown_timer <= 0.0 and dash_timer <= 0.0

# True while an overlay ability owns the sprite, so locomotion states leave the
# animation alone and let the attack/parry swing play out.
func is_action_animating() -> bool:
	var a := sprite.animation
	return (a == "attack1" or a == "parry") and sprite.is_playing()


# --- Overlay abilities ------------------------------------------------------

# Fires the attack animation and spawns a slash hitbox in front of the player.
# TODO: add effect when hurt enemy
func _handle_attack(delta: float) -> void:
	attack_cooldown_timer = max(attack_cooldown_timer - delta, 0.0)
	if not Input.is_action_just_pressed("attack"):
		return
	if attack_cooldown_timer > 0.0:
		return                                 # still cooling down — ignore the press
	attack_cooldown_timer = attack_cooldown
	sprite.play("attack1")
	var slash := SLASH_SCENE.instantiate()
	slash.position = Vector2(15 * facing, 0)
	slash.flip_h = facing < 0
	add_child(slash)
	stamina -= attack_cost


# Consumes a bullet to start a parry window (see is_parrying / try_parry).
# TODO: add parry effect like spark
func _handle_parry(delta: float) -> void:
	parry_timer = max(parry_timer - delta, 0.0)
	if not Input.is_action_just_pressed("parry"):
		return
	if bullets <= 0 or parry_timer > 0.0:
		return
	sprite.play("parry")
	bullets -= 1
	parry_timer = PARRY_TIME


# True while the parry window is open.
func is_parrying() -> bool:
	return parry_timer > 0.0

# Called by attackers: if we're parrying, eat the hit, trigger hit stop, and
# report success. Returns true when the parry connected.
func try_parry(_parry_window: float = PARRY_TIME) -> bool:
	if not is_parrying():
		return false
	parry_timer = 0.0
	parry_succeeded.emit()
	_hit_stop(hit_stop_duration)
	return true


# Briefly slows time for impact feel. Ignores re-entry while already active.
func _hit_stop(duration: float) -> void:
	if Engine.time_scale < 1.0:
		return
	Engine.time_scale = 0.05
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0


# Snaps the sprite to a target scale, then eases it back to normal — the
# squash-&-stretch juice on takeoff / landing.
func _squash(scale_target: Vector2) -> void:
	if sprite_tween and sprite_tween.is_valid():
		sprite_tween.kill()
	sprite.scale = scale_target
	sprite_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	sprite_tween.tween_property(sprite, "scale", Vector2.ONE, squash_duration)


# Spawns a frozen snapshot of the current sprite frame for the dash trail.
func spawn_ghost() -> void:
	var ghost = GHOST_SCENE.instantiate()
	ghost.texture = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	ghost.global_position = sprite.global_position
	ghost.flip_h = sprite.flip_h
	get_parent().add_child(ghost)


# TODO: add items to increase stamina in temp time
func _handle_stamina(delta):
	stamina += stamina_regan * delta
	stamina = clampf(stamina, 0.0, max_stamina)
	stamina_bar.value = stamina

# True while immune to damage (e.g. dash i-frames).
func is_invincible() -> bool:
	return invincible_timer > 0.0

# amount will reuse by difference enitity
# TODO: add hurt effect
func take_damage(amount):
	if is_invincible():
		return                                 # i-frames: ignore the hit
	health -= amount
	update_health_display()
	if health <= 0:
		die()

# Death: drop carried currency at this spot (recoverable), then respawn by
# reloading the scene — which sends us to the last save point with full health,
# full vials, and freshly respawned enemies.
func die():
	GameState.drop_currency(global_position)
	# Deferred: die() is often called from a physics callback (enemy contact /
	# killzone), and reloading frees this body mid-physics, which Godot forbids.
	get_tree().reload_current_scene.call_deferred()

# 9999999 damage apply
func fall() -> void:
	die()

func update_health_display():
	var diamonds = health_diamonds.get_children()
	for i in range(diamonds.size()):
		if i < health:
			diamonds[i].texture = diamond_full
		else:
			diamonds[i].texture = diamone_empty


# Drink a potion: spend one charge to restore HP. Wasted presses (no charges or
# already full health) are ignored, so you can't burn a charge for nothing.
func _handle_heal() -> void:
	if not Input.is_action_just_pressed("heal"):
		return
	if heal_charges <= 0 or health >= max_health:
		return
	heal_charges -= 1
	health = min(health + heal_amount, max_health)
	update_health_display()
	update_heal_display()

func update_heal_display():
	if heal_label:
		heal_label.text = "Heals: %d" % heal_charges

func _update_currency_label(amount: int) -> void:
	if currency_label:
		currency_label.text = "Currency: %d" % amount

# Drops the recoverable currency pickup at the spot we died (stored in GameState).
func _spawn_currency_drop() -> void:
	var drop = CURRENCY_DROP_SCENE.instantiate()
	get_parent().add_child(drop)
	drop.global_position = GameState.dropped_position
