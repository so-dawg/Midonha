class_name PlayerState extends Node

# Base class for every player locomotion state (classic state-pattern automata).
# Each concrete state lives in its own file under scripts/states/ and overrides
# the hooks below. The StateMachine owns one instance of each and runs one at a
# time. States only handle LOCOMOTION (velocity + animation + transitions);
# attack / parry / stamina are overlays handled by the player every frame.

# Back-reference to the player this state drives. Set by the StateMachine.
var p: Player

# Called once when this state becomes the active one.
func enter() -> void:
	pass

# Called once right before leaving this state.
func exit() -> void:
	pass

# Called every physics frame while active. Return the NAME of the state to
# switch to (e.g. "run"), or "" to stay in this state.
func physics_update(_delta: float) -> String:
	return ""
