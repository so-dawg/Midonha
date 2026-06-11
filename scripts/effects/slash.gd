extends AnimatedSprite2D

# damage on enemy 
@export var damage: int = 1

# hit count on enemy
var _already_hit: Array[Node] = []

func _ready() -> void:
	#flip_h to make hitbox change direction too
	if flip_h:
		$Area2D.scale.x = -1
	#play the one animation sprite it has 
	play()
	animation_finished.connect(queue_free)

func _on_area_2d_area_entered(area: Area2D) -> void:
	var target := area.get_parent()
	if target in _already_hit:
		return
	_already_hit.append(target)
	if target.has_method("take_damage"):
		# Pass our position so the enemy knows which way to fly on knockback.
		target.take_damage(damage, global_position)
