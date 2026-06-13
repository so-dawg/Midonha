extends Sprite2D

# Skid dust puff. Fades out then deletes itself. The spawner (run.gd) sets our
# flip_h so the puff faces the same way the player does — flip_h is a built-in
# Sprite2D property, so just setting it mirrors the texture automatically.

func _ready() -> void:
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	tween.tween_callback(queue_free)
