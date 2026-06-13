class_name Entity
extends CharacterBody2D

# BASE ENEMY
# Shared guts for every enemy: health, taking damage (with white hit-flash and
# knockback), death, and gravity. Concrete enemies (Patroller, Ranged, Brute...)
# extend this and implement _behavior() for their own movement / AI — they do
# NOT touch damage or death, they inherit it.

@export var max_health: int = 3
@export var move_speed: float = 40.0
@export var gravity: float = 1200.0
@export var contact_damage: int = 1          # damage dealt to the player on touch
@export var currency_reward: int = 5         # currency granted to the player on death
@export var knockback_force: float = 220.0   # horizontal shove when hit
@export var knockback_time: float = 0.12     # how long the enemy's AI is suspended after a hit
@export var stagger_time: float = 0.8        # how long the enemy is stunned after a parry
@export var detection_range: float = 120.0

var health: int
var knockback_timer: float = 0.0          # > 0 while being knocked back (AI yields)

@onready var hitbox: Area2D = get_node_or_null("Hitbox")  # optional contact-damage area

signal died
signal health_changed(current: int, maximum: int)
signal staggered

func _ready() -> void:
	health = max_health
	# If the enemy has a Hitbox area, hurt the player when they walk into it.
	if hitbox:
		hitbox.body_entered.connect(_on_hitbox_body_entered)

# Base movement loop: gravity + whatever the subclass does + move_and_slide.
# Subclasses override _behavior(), not this.
func _physics_process(delta: float) -> void:
	knockback_timer = max(knockback_timer - delta, 0.0)
	if not is_on_floor():
		velocity.y += gravity * delta
	_behavior(delta)
	move_and_slide()


# Per-enemy AI / movement. Default does nothing (a stationary enemy).
# Subclasses should bail out early while is_stunned() so knockback can carry.
func _behavior(_delta: float) -> void:
	pass

# True briefly after taking a hit — the AI should not drive velocity now, or it
# would instantly overwrite the knockback shove.
func is_stunned() -> bool:
	return knockback_timer > 0.0

# Called by the player's slash (slash.gd). `from` is the attacker's position,
# used to decide which way to knock the enemy back.
func take_damage(amount: int, from: Vector2 = Vector2.INF) -> void:
	health -= amount
	health_changed.emit(health, max_health)
	_knockback(from)
	if health <= 0:
		die()


# Shove away from the damage source. Skipped if no source was given.
func _knockback(from: Vector2) -> void:
	if from == Vector2.INF:
		return
	var dir := signf(global_position.x - from.x)
	if dir == 0.0:
		dir = 1.0
	velocity.x = dir * knockback_force
	knockback_timer = knockback_time

# Stunned in place after a successful player parry — long enough to punish.
# Reuses the knockback/stun timer so _behavior() yields (see is_stunned()).
func stagger() -> void:
	velocity.x = 0.0
	knockback_timer = stagger_time
	staggered.emit()

# Override in subclasses to drop loot / play an effect. Default: vanish.
func die() -> void:
	GameState.add_currency(currency_reward)
	died.emit()
	queue_free()

# Contact damage to the player. Only the player has both take_damage and the
# "player" group, so world tiles / other enemies are ignored.
func _on_hitbox_body_entered(body: Node) -> void:
	if not (body.is_in_group("player") and body.has_method("take_damage")):
		return
	# If the player is parrying, they negate the hit and stagger us instead.
	if body.has_method("try_parry") and body.try_parry():
		stagger()

func _player_dir() -> float:
	var p := get_tree().get_first_node_in_group("player") as Node2D
	if not p:
		print("NO PLAYER FOUND")
		return 0.0
	var dist := global_position.distance_to(p.global_position)
	if dist > detection_range:
		return 0.0
	return signf(p.global_position.x - global_position.x)
