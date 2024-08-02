extends battle_state

@export var preform_move : battle_state

signal show_targets(targets : Array[battle_character_data])
signal show_skills(targets : Array[rpg_skill])
signal behaviour_call()

func start_state():
	if battle_globals.is_player_team(battle_globals.current_character):
		$"../../Attack Menu".visible = true
		$"../../Target Menu".visible = false
		print("Menu stuff")
		show_skills.emit(battle_globals.current_character.get_skills)
	else:
		print("Behaviour")
		behaviour_call.emit()

func start_processing():
	change_state.emit(preform_move)
