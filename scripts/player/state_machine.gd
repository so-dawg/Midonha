class_name PlayerStateMachine extends Node

# Owns the player's locomotion states and runs exactly one at a time.
# States are built in code (no scene wiring needed) and added as children, so
# they're real nodes in the tree — classic node-based automata.

var player: Player
var current: PlayerState
var states: Dictionary = {}

# Build every state, wire it to the player, and start in "idle".
func setup(owner_player: Player) -> void:
	player = owner_player
	_add("idle", preload("res://scripts/player/states/idle.gd"))
	_add("run",  preload("res://scripts/player/states/run.gd"))
	_add("jump", preload("res://scripts/player/states/jump.gd"))
	_add("fall", preload("res://scripts/player/states/fall.gd"))
	_add("dash", preload("res://scripts/player/states/dash.gd"))
	current = states["idle"]
	current.enter()

func _add(state_name: String, script: GDScript) -> void:
	var s: PlayerState = script.new()
	s.name = state_name
	s.p = player
	add_child(s)
	states[state_name] = s

# Tick the active state; if it returns another state's name, switch to it.
func update(delta: float) -> void:
	var next := current.physics_update(delta)
	if next != "" and next != String(current.name) and states.has(next):
		current.exit()
		current = states[next]
		current.enter()