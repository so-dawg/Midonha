extends PlayerState

# Rising half of a jump. Launches on enter, then hands off to "fall" at the
# apex (when vertical velocity turns positive).

func enter() -> void:
	# The impulse was already applied by player.start_jump() before we got here;
	# this state just owns the rising animation.
	if not p.is_action_animating():
		p.sprite.play("jump")

func physics_update(delta: float) -> String:
	var dir := p.input_dir()

	if p.wants_dash():
		return "dash"

	# Double jump mid-rise: refresh upward velocity, stay in this state.
	if p.can_air_jump():
		p.start_jump(true)

	p.apply_gravity(delta)
	p.apply_horizontal_movement(dir, false, delta)

	if p.velocity.y >= 0.0:
		return "fall"
	if p.is_on_floor():
		return p.ground_state()

	if not p.is_action_animating():
		p.sprite.play("jump")
	return ""