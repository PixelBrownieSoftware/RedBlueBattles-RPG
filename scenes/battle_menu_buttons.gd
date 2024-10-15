extends VBoxContainer
@export var battle_button = preload("res://objects/UI/battle_select_button.tscn")
signal load_battle(group : battle_group_data)
signal load_battle_level(level_group : battle_level_group)
var selected_battle_level : battle_level_group
var desc : RichTextLabel

func load_battles():
	var index : int = 0
	for battle_group in GlobalVariables.battles_availible:
		var button : button_level = get_child(index)
		if button == null:
			button = battle_button.instantiate()
			add_child(button)
		button.assign_data(battle_group)
		button.load_level.connect(load_battle_level_group)
		index += 1

func load_battle_level_group(battle_G : battle_level_group):
	selected_battle_level = battle_G
	GlobalVariables.current_level = battle_G
	load_battle_level.emit(battle_G)
	
func start_battle():
	var selected: int = randi() % selected_battle_level.battle_groups.size()
	load_battle.emit(selected_battle_level.battle_groups[selected])
