extends Area2D

# Kills the player and restarts the level after a short delay.

@export var max_killzone_time: float = 0.5  # delay before reload

var killzone_timer: float = 0.0
var dying: bool = false  # true once the player has fallen in

func _ready() -> void:
	body_entered.connect(_on_body_entered)  # wire up the trigger

# player fell in -> start the death countdown
func _on_body_entered(_body: Node2D) -> void:
	dying = true
	killzone_timer = max_killzone_time
	print("u died")

# tick the countdown each frame, reload at zero
func _physics_process(delta: float) -> void:
	if not dying:
		return
	killzone_timer -= delta
	if killzone_timer <= 0.0:
		get_tree().reload_current_scene.call_deferred()
