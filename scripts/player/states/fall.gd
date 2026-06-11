extends PlayerState

# Airborne and descending — either past a jump's apex or just walked off a
# ledge. The coyote window means a jump is still allowed for a short grace
# period after leaving the ground.

func enter() -> void:
	if not p.is_action_animating():
		p.sprite.play("jump")   # no dedicated fall anim yet; reuse "jump"

func physics_update(delta: float) -> String:
	var dir := p.input_dir()

	if p.is_on_floor():
		return p.ground_state()
	if p.wants_dash():
		return "dash"
	if p.can_jump():
		p.start_jump()
		return "jump"   # coyote-time jump
	if p.can_air_jump():
		p.start_jump(true)
		return "jump"   # double jump

	p.apply_gravity(delta)
	p.apply_horizontal_movement(dir, false, delta)

	if not p.is_action_animating():
		p.sprite.play("jump")
	return ""