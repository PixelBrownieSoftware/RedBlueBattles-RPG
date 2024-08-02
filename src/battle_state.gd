extends Node
class_name battle_state
signal change_state(state)
@onready var battle_globals : battle_variables = get_node("../../Variables")

func start_state():
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
