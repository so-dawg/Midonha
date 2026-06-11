extends Node

# GAME STATE (autoload singleton)
# Persistent data that must survive a scene reload. Both resting at a save point
# and dying reload the current scene (which respawns enemies and, via the
# player's _ready, refills health + vials); this node keeps the data that the
# reload would otherwise wipe — the respawn point and the currency.

signal currency_changed(amount: int)

# --- Respawn ---------------------------------------------------------------
var has_respawn: bool = false                 # false until the first rest
var respawn_position: Vector2 = Vector2.ZERO  # where the player reappears

# --- Currency --------------------------------------------------------------
var currency: int = 0                         # what the player is carrying

# Currency dropped at the spot of the last death, waiting to be picked back up.
var has_dropped: bool = false
var dropped_amount: int = 0
var dropped_position: Vector2 = Vector2.ZERO

# Reward earned (e.g. from killing an enemy).
func add_currency(amount: int) -> void:
	currency += amount
	currency_changed.emit(currency)

# Resting at a save point: remember where to reappear.
func set_respawn(pos: Vector2) -> void:
	has_respawn = true
	respawn_position = pos

# Death: drop everything carried at the death spot. A previous, unrecovered
# drop is overwritten (lost) — same as Hollow Knight's shade.
func drop_currency(pos: Vector2) -> void:
	if currency <= 0:
		return                                # nothing to drop — no shade spawns
	has_dropped = true
	dropped_amount = currency
	dropped_position = pos
	currency = 0
	currency_changed.emit(currency)

# Reached the dropped currency: take it back.
func recover_currency() -> void:
	if not has_dropped:
		return
	currency += dropped_amount
	has_dropped = false
	dropped_amount = 0
	currency_changed.emit(currency)