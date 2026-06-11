extends Entity

# PATROLLER
# The simplest enemy: walks back and forth at a constant speed, turns around
# when it bumps a wall, and damages the player on contact (via the inherited
# Hitbox). All health / damage / death behaviour comes from Entity.

var _dir: int = 1   # travel direction: +1 right, -1 left

func _behavior(_delta: float) -> void:
	# Just got hit — let the knockback shove carry us instead of overwriting it.
	if is_stunned():
		return

	# Hit a wall (or got shoved into one by knockback)? Turn around.
	if is_on_wall():
		_dir = -_dir

	velocity.x = _dir * move_speed

	# Face the way we're walking (flip the placeholder/sprite horizontally).
	if visual:
		visual.scale.x = absf(visual.scale.x) * _dir
