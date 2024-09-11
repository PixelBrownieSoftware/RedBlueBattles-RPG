extends Button
class_name button_group

@export var battle_groups : Array[battle_group_data]
#TODO: Maybe put a flag requirement
signal load_battle(group : battle_group_data)

func _on_pressed():
	var selected: int = randi() % battle_groups.size()
	load_battle.emit(battle_groups[selected])
