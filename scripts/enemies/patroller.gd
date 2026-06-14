class_name Patroller
extends Entity

# ── ATTACK ─────────────────────────────────────────────
@export var attack_range: float = 50.0
@export var attack_damage: int = 1
@export var max_attack_timer: float = 0.2
const HIT_DELAY     = 0.4   # gap between hit 1 and hit 2
const COOLDOWN_TIME = 1.0   # rest after full combo


# ── PATROL ─────────────────────────────────────────────
const PATROL_TIME = 2.0
var patrol_timer  = 0.0
var facing        = 1.0   # 1 = right, -1 = left

# ── STATE ──────────────────────────────────────────────
enum State { PATROL, CHASE, ATTACK, COOLDOWN }
var state        = State.PATROL
var attack_step  = 0
var attack_timer = 0.0
var already_hit = false
var is_hurt := false

# ── ANIMATION ──────────────────────────────────────────
@onready var anim = $AnimatedSprite2D

func _ready() -> void:
	super._ready()
	stagger_time = 4.0 # Longer window for this enemy
	parry_window = 0.4

# ── AI (called by Entity every frame) ──────────────────
func _behavior(delta: float) -> void:
	if is_stunned():
		if anim.animation != "hurt":
			anim.play("hurt")
		return

	if is_hurt:
		return

	match state:
		State.PATROL:   _patrol(delta)
		State.CHASE:    _chase()
		State.ATTACK:   _attack(delta)
		State.COOLDOWN: _cooldown(delta)

	# flip sprite to face movement direction
	if facing != 0:
		anim.flip_h = facing < 0
		hitbox.position = Vector2(25 * facing, 4)
		hitbox.scale.x = facing

# ── PATROL ─────────────────────────────────────────────
func _patrol(delta: float) -> void:
	var dir = _player_dir()
	if dir != 0.0:
		state = State.CHASE
		return

	velocity.x = move_speed * facing
	patrol_timer += delta
	if patrol_timer >= PATROL_TIME:
		patrol_timer = 0.0
		facing *= -1
	anim.play("run")

# ── CHASE ──────────────────────────────────────────────
func _chase() -> void:
	var dir = _player_dir()
	if dir == 0.0:
		state = State.PATROL
		return

	facing    = dir
	velocity.x = move_speed * 2.0 * facing

	var player = get_tree().get_first_node_in_group("player") as Node2D
	if player and global_position.distance_to(player.global_position) <= attack_range:
		velocity.x   = 0
		attack_step  = 0
		attack_timer = 0.0
		state = State.ATTACK
		return

	anim.play("run")

# ── ATTACK (2-hit combo) ───────────────────────────────
func _attack(delta: float) -> void:
	velocity.x    = 0
	attack_timer += delta

	if attack_step == 0 and attack_timer >= 0.1:
		anim.play("attack")
		already_hit = false
		_flash_hitbox()
		print("attack 1")
		attack_step  = 1
		attack_timer = 0.0

	elif attack_step == 1 and attack_timer >= HIT_DELAY:
		anim.play("attack2")
		already_hit = false
		_flash_hitbox()
		print("attack 2")
		attack_step  = 2
		attack_timer = 0.0

	elif attack_step == 2 and attack_timer >= 0.2:
		state        = State.COOLDOWN
		attack_timer = 0.0
		already_hit = true

func _flash_hitbox() -> void:
	if already_hit:
		return
	hitbox.monitoring = true
	await get_tree().physics_frame
	var bodies = hitbox.get_overlapping_bodies()
	for body in bodies:
		if body.is_in_group("player") and body.has_method("take_damage"):
			break
	hitbox.monitoring = false

# ── COOLDOWN ───────────────────────────────────────────
func _cooldown(delta: float) -> void:
	velocity.x    = 0
	attack_timer += delta
	anim.play("idle")

	if attack_timer >= COOLDOWN_TIME:
		attack_timer = 0.0
		var player = get_tree().get_first_node_in_group("player") as Node2D
		if player and global_position.distance_to(player.global_position) <= attack_range:
			state = State.ATTACK
		elif _player_dir() != 0.0:
			state = State.CHASE
		else:
			state = State.PATROL

# ── DEATH (override Entity to play animation first) ────
func die() -> void:
	is_dead = true
	velocity = Vector2.ZERO
	anim.play("hurt")
	await anim.animation_finished
	anim.play("death")
	await anim.animation_finished
	super.die()   # calls Entity.die() → adds currency → queue_free

# Overrride (take _damage to play animation when hit to make it connsistant)
func take_damage(amount: int, from: Vector2 = Vector2.INF) -> void:
	if is_dead:
		return
	if is_hurt:
		return
	# Interrupt attack or cooldown
	if state in [State.ATTACK, State.COOLDOWN]:
		state = State.CHASE
		attack_step = 0
		attack_timer = 0.0
	is_hurt = true
	anim.play("hurt")
	await anim.animation_finished
	is_hurt = false
	super.take_damage(amount, from)
