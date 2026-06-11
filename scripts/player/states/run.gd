extends PlayerState

# Grounded and moving. Same as idle but also handles the skid (pressing against
# your own momentum) feel, and drops back to idle once you've stopped.

func exit() -> void:
	p.was_skidding = false

func physics_update(delta: float) -> String:
	var dir := p.input_dir()

	if p.wants_dash():
		return "dash"

	p.apply_horizontal_movement(dir, true, delta)

	if p.can_jump():
		p.start_jump()
		return "jump"
	if not p.is_on_floor():
		return "fall"
	if dir == 0.0 and absf(p.velocity.x) <= 5.0:
		return "idle"

	# Skid: pressing against current velocity while still moving fast.
	var is_skidding := dir != 0.0 \
		and signf(dir) != signf(p.velocity.x) \
		and absf(p.velocity.x) > p.max_speed * 0.4

	if not p.is_action_animating():
		p.sprite.play("run")
		# Placeholder: drag the run anim to fake a skid until a real one exists.
		p.sprite.speed_scale = 0.3 if is_skidding else 1.0

	# Rising edge of a skid — hook for VFX/SFX once you have them.
	if is_skidding and not p.was_skidding:
		pass  # TODO: emit dust particles, play scuff sfx
	p.was_skidding = is_skidding
	return ""