extends PlayerState

# Grounded and moving. Same as idle but also handles the skid (pressing against
# your own momentum) feel, and drops back to idle once you've stopped.

const SMOKE := preload("res://scenes/Smoke.tscn")

var dust_timer := 0.0
var run_dust_timer := 0.0

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
		p.sprite.speed_scale = 0.3 if is_skidding else 1.0

	if is_skidding and not p.was_skidding:
		_spawn_skid_dust()

	if is_skidding:
		dust_timer -= delta
		if dust_timer <= 0.0:
			_spawn_skid_dust()
			dust_timer = 0.15

	p.was_skidding = is_skidding

	if not is_skidding and p.is_on_floor() and absf(p.velocity.x) > 50.0:
		run_dust_timer -= delta
		if run_dust_timer <= 0.0:
			_spawn_run_dust()
			run_dust_timer = 0.2

	return ""

func _spawn_skid_dust() -> void:
	var s := SMOKE.instantiate()
	s.animation = "skid_smoke"
	s.flip_h = p.facing < 0
	p.get_parent().add_child(s)
	s.global_position = p.global_position + Vector2(-12 * p.facing, 8)

func _spawn_run_dust() -> void:
	var s := SMOKE.instantiate()
	s.animation = "runnning_smoke"
	s.flip_h = p.facing < 0
	p.get_parent().add_child(s)
	s.global_position = p.global_position + Vector2(0, 9)
