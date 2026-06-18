extends AnimatedSprite2D

func _ready() -> void:
	play()
	if sprite_frames.get_frame_count(animation) <= 1:
		var tween := create_tween()
		tween.tween_property(self, "modulate:a", 0.0, 0.4)
		tween.tween_callback(queue_free)
	else:
		animation_finished.connect(_on_animation_finished)

func _on_animation_finished() -> void:
	queue_free()
