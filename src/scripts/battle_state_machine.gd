extends Node

var current_state : battle_state
@export
var starting_state : battle_state

func _ready():
	change_state(starting_state)

func change_state(state : battle_state):
	current_state = state
	current_state.start_state()

