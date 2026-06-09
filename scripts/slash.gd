extends AnimatedSprite2D

@export var damage: int = 1

var _already_hit: Array[Node] = []


func _ready() -> void:
	play()
	animation_finished.connect(queue_free)


func _on_area_2d_area_entered(area: Area2D) -> void:
	var target := area.get_parent()
	if target in _already_hit:
		return
	_already_hit.append(target)
	if target.has_method("take_damage"):
		target.take_damage(damage)
