extends Button
class_name button_group

@export
var selected_group : battle_group_data
signal load_battle(group : battle_group_data)

func _ready():
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func _on_pressed():
	load_battle.emit(selected_group)
