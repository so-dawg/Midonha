extends Area2D

# CURRENCY DROP (shade)
# Spawned at the spot where the player last died (see player.gd). Walk into it
# to reclaim the currency that was dropped. The amount lives in GameState; this
# node is just the pickup trigger.

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		GameState.recover_currency()
		queue_free()