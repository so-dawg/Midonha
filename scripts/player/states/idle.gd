extends PlayerState

# Grounded and (nearly) still. Waits for input to run, jump, dash, or to fall
# off a ledge.

func enter() -> void:
	if not p.is_action_animating():
		p.sprite.play("idle")
		p.sprite.speed_scale = 1.0

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
	if dir != 0.0:
		return "run"

	if not p.is_action_animating():
		p.sprite.play("idle")
		p.sprite.speed_scale = 1.0
	return ""