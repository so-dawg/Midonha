extends Area2D

# SAVE POINT (bench)
# While the player is standing in it, pressing "interact" rests: it records this
# spot as the respawn point, then reloads the area. The reload respawns all
# enemies and refills the player to full health + vials (the player's _ready
# resets those), and the player reappears here.

var _player_in_range: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = true

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = false

func _process(_delta: float) -> void:
	if _player_in_range and Input.is_action_just_pressed("interact"):
		_rest()

func _rest() -> void:
	GameState.set_respawn(global_position)
	# TODO: fade to black for feel. Reload refills + respawns enemies.
	get_tree().reload_current_scene.call_deferred()