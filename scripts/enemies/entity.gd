class_name Entity
extends CharacterBody2D

@export var max_health: int = 4
@export var move_speed: float = 40.0
@export var gravity: float = 1200.0
@export var currency_reward: int = 5
@export var knockback_force: float = 220.0
@export var knockback_time: float = 0.12
@export var detection_range: float = 80.0
@export var parry_window: float = 0.2

var health: int
var knockback_timer: float = 0.0
var is_dead := false
var contact_timer: float = 0.0
var can_contact_damage: bool = true

@onready var hitbox: Area2D = get_node_or_null("Hitbox")

signal died

func _ready() -> void:
	health = max_health

func _physics_process(delta: float) -> void:
	knockback_timer = max(knockback_timer - delta, 0.0)
	contact_timer = max(contact_timer - delta, 0.0)

	if not is_on_floor():
		velocity.y += gravity * delta
	if not is_dead:
		_behavior(delta)

	_handle_contact_damage()
	move_and_slide()

func _handle_contact_damage() -> void:
	if not can_contact_damage or contact_timer > 0.0:
		return

	var bodies = hitbox.get_overlapping_bodies()
	if bodies.is_empty():
		return

	var body = bodies[0]
	if not (body.is_in_group("player") and body.has_method("take_damage")):
		return

	if body.has_method("try_parry") and body.try_parry():
		return

	contact_timer = 0.5
	body.take_damage(1)

func _behavior(_delta: float) -> void:
	pass

func is_stunned() -> bool:
	return knockback_timer > 0.0

func take_damage(amount: int, from: Vector2 = Vector2.INF) -> void:
	if is_dead:
		return
	health -= amount
	_knockback(from)
	if health <= 0:
		die()

func _knockback(from: Vector2) -> void:
	if from == Vector2.INF:
		return
	var dir := signf(global_position.x - from.x)
	if dir == 0.0:
		dir = 1.0
	velocity.x = dir * knockback_force
	knockback_timer = knockback_time

func die() -> void:
	GameState.add_currency(currency_reward)
	died.emit()
	queue_free()

func _player_dir() -> float:
	var p := get_tree().get_first_node_in_group("player") as Node2D
	if not p:
		return 0.0
	var dist := global_position.distance_to(p.global_position)
	if dist > detection_range:
		return 0.0
	return signf(p.global_position.x - global_position.x)
