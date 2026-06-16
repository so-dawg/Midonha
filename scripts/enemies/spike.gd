extends Sprite2D

@export var damage: int = 1
@export var contact_cooldown: float = 0.5

var contact_timer: float = 0.0
@onready var area: Area2D = $Area2D

func _physics_process(delta: float) -> void:
	contact_timer = max(contact_timer - delta, 0.0)
	_handle_contact_damage()

func _handle_contact_damage() -> void:
	if contact_timer > 0.0:
		return

	var bodies = area.get_overlapping_bodies()
	if bodies.is_empty():
		return

	var body = bodies[0]

	if not (body.is_in_group("player") and body.has_method("take_damage")):
		return

	if body.has_method("try_parry") and body.try_parry():
		return

	contact_timer = contact_cooldown
	body.take_damage(damage)
	if body.health <= 0:
		get_tree().reload_current_scene()
