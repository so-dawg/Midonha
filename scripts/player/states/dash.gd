extends PlayerState

# Fixed-speed horizontal burst with a short windup freeze. Owns velocity fully
# while active: no gravity and no normal horizontal control, so it can't be
# fought by movement or dragged down by gravity. Spawns afterimage ghosts.

func enter() -> void:
	p.dash_available = false           # spent — no air-dash refill until grounded
	p.dash_timer = p.dash_duration
	p.dash_freeze_timer = p.dash_freeze
	p.dash_cooldown_timer = p.dash_cooldown
	p.dash_dir = p.facing              # latch direction at start
	p.invincible_timer = p.dash_iframe_time   # i-frames: immune to damage while dashing
	p.ghost_timer = 0.0                # spawn the first afterimage immediately
	p.sprite.flip_h = p.dash_dir < 0.0
	p.sprite.play("dash")
	if p.is_on_floor():
		p._spawn_smoke("dash_smoke")
	p.stamina -= p.dash_cost

func physics_update(delta: float) -> String:
	p.dash_timer -= delta

	if p.dash_freeze_timer > 0.0:
		# Windup: hang in place so the launch reads as an explosive burst.
		p.dash_freeze_timer -= delta
		p.velocity = Vector2.ZERO
	else:
		# Burst: fixed horizontal speed, no vertical drift, trailing ghosts.
		p.ghost_timer -= delta
		if p.ghost_timer <= 0.0:
			p.ghost_timer = p.GHOST_INTERVAL
			p.spawn_ghost()
		p.velocity.x = p.dash_dir * p.dash_speed
		p.velocity.y = 0.0

	# Dash over — fall if airborne, otherwise resume idle/run.
	if p.dash_timer <= 0.0:
		return p.ground_state() if p.is_on_floor() else "fall"
	return ""
