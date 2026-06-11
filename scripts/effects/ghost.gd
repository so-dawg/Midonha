extends Sprite2D

# DASH GHOST (afterimage)
# A single frozen snapshot of the player, spawned repeatedly during a dash
# (see player.gd -> spawn_ghost). It fades out and deletes itself, leaving a
# trailing motion-blur effect. It does nothing on its own — it's purely visual.

# How long the fade-out takes, in seconds. Lower = snappier trail.
@export var fade_time: float = 0.2

# Runs once when the ghost is added to the scene.
func _ready() -> void:
	# Tint the snapshot blue-green and semi-transparent so it reads as a ghost
	# rather than a second player. (r, g, b, alpha) — tweak to taste.
	modulate = Color(0.1, 0.7, 0.4, 0.6)

	# Animate the alpha (modulate:a) from its current value down to 0 = invisible.
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, fade_time)

	# Once the fade finishes, delete this ghost so they don't pile up in the scene.
	# Once the fade finishes, delete this ghost so they don't pile up in the scene.
	tween.tween_callback(queue_free)
