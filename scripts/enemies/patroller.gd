class_name Patroller
extends Entity

# ── CONSTANTS ──────────────────────────────────────────────
const PATROL_TIME = 2.0
const HIT_DELAY = 0.4
const COOLDOWN_TIME = 1.0

# ── ATTACK ─────────────────────────────────────────────
@export var attack_range: float = 50.0
@export var attack_damage: int = 1

# ── STATE ──────────────────────────────────────────────
enum State { PATROL, CHASE, ATTACK, COOLDOWN }
var state = State.PATROL
var attack_step = 0
var attack_timer = 0.0
var already_hit = false
var is_hurt := false

# ── MOVEMENT ───────────────────────────────────────────
var patrol_timer = 0.0
var facing = 1.0

# ── ANIMATION ──────────────────────────────────────────
@onready var anim = $AnimatedSprite2D

func _ready() -> void:
	super._ready()
	parry_window = 0.4
	can_contact_damage = false

func _behavior(delta: float) -> void:
	if is_stunned():
		if anim.animation != "hurt":
			anim.play("hurt")
		return

	if is_hurt:
		return

	match state:
		State.PATROL:
			_patrol(delta)
		State.CHASE:
			_chase()
		State.ATTACK:
			_attack(delta)
		State.COOLDOWN:
			_cooldown(delta)

	_update_sprite()

func _update_sprite() -> void:
	if facing != 0:
		anim.flip_h = facing < 0
		hitbox.position = Vector2(25 * facing, 4)
		hitbox.scale.x = facing

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

func _chase() -> void:
	var dir = _player_dir()
	if dir == 0.0:
		state = State.PATROL
		return

	var player = get_tree().get_first_node_in_group("player") as Node2D
	if not player:
		return

	if not _can_move_to(dir):
		state = State.PATROL
		return

	facing = dir
	velocity.x = move_speed * 2.0 * facing

	if player and global_position.distance_to(player.global_position) <= attack_range:
		velocity.x = 0
		attack_step = 0
		attack_timer = 0.0
		can_contact_damage = false
		state = State.ATTACK
		return

	anim.play("run")

func _attack(delta: float) -> void:
	velocity.x = 0
	attack_timer += delta

	if attack_step == 0 and attack_timer >= 0.1:
		anim.play("attack")
		already_hit = false
		_perform_attack()
		attack_step = 1
		attack_timer = 0.0

	elif attack_step == 1 and attack_timer >= HIT_DELAY:
		anim.play("attack2")
		already_hit = false
		_perform_attack()
		attack_step = 2
		attack_timer = 0.0

	elif attack_step == 2 and attack_timer >= 0.2:
		state = State.COOLDOWN
		attack_timer = 0.0

func _cooldown(delta: float) -> void:
	velocity.x = 0
	attack_timer += delta
	anim.play("idle")

	if attack_timer >= COOLDOWN_TIME:
		attack_timer = 0.0
		if _player_dir() != 0.0:
			state = State.CHASE
		else:
			state = State.PATROL

func _perform_attack() -> void:
	if already_hit:
		return

	var bodies = hitbox.get_overlapping_bodies()
	if bodies.is_empty():
		return

	var body = bodies[0]
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(attack_damage)
		already_hit = true

func die() -> void:
	is_dead = true
	velocity = Vector2.ZERO
	anim.play("hurt")
	await anim.animation_finished
	anim.play("death")
	await anim.animation_finished
	super.die()

func take_damage(amount: int, from: Vector2 = Vector2.INF) -> void:
	if is_dead or is_hurt:
		return

	if state in [State.ATTACK, State.COOLDOWN]:
		state = State.CHASE
		attack_step = 0
		attack_timer = 0.0

	is_hurt = true
	anim.play("hurt")
	await anim.animation_finished
	is_hurt = false
	super.take_damage(amount, from)

func _can_move_to(direction: float) -> bool:
	var ahead = global_position + Vector2(direction * 30, 0)
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(ahead, ahead + Vector2(0, 100))
	var result = space_state.intersect_ray(query)
	return result != null  # ground exists
