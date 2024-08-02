extends Node
@onready var battle_globals : battle_variables = get_node("..")
signal get_targets(skill)
signal start_process_state()

func behaviour_process():
	#var behaviours = battle_globals.current_character.assigned_data.behaviour
	var best_behaviours = {}
	var character_skills : Array[rpg_skill] = battle_globals.current_character.get_skills
	for skill in character_skills:
		var targets :  Array[battle_character_data]
		get_targets.emit(skill)
		for character in battle_globals.targets:
			if character.health > 0:
				targets.append(character)
		best_behaviours[skill] = targets
	#for behaviour : battle_move_behaviour in behaviours:
		#var move : Array[rpg_skill] = find_move_behaviour(behaviour)
		#if move != null:
			#best_behaviours[move] = find_target_conditions(behaviour.behaviouir_conditions, move)
		##TODO: Add another for loop for checking behaviours
		##it will also check for costs and if the cost becomes too high, go to the next behaviour
		#
	var random_move = best_behaviours.keys().pick_random()
	battle_globals.selected_move = random_move
	var random_targ = best_behaviours[random_move].pick_random()
	battle_globals.target_character = random_targ
	start_process_state.emit()

func find_target_conditions(conditions : Array[battle_character_behaviour], move : Array[rpg_skill]) -> Array[battle_character_data]:
	var best_score : int = 0
	var targets :  Array[battle_character_data]
	get_targets.emit(move)
	for character in battle_globals.targets:
		var score : int = 0
		print("target: " + character.name)
		for behaviour in conditions:
			match behaviour.condition:
				behaviour.BEHAVIOUR_CONDITION.TARGET_HP:
					if character.health <= (character.max_health * behaviour.percentage):
						score += 1
					else:
						pass
				behaviour.BEHAVIOUR_CONDITION.ELEMENTAL_AFFINITY:
					if character.get_elemental_affinity(behaviour.specific_element) <= behaviour.elemental:
						score += 2
					else:
						pass
	return targets
						
func find_move_behaviour(behaviour : battle_move_behaviour) -> Array[rpg_skill]:
	var skills : Array[rpg_skill]
	var character_skills : Array[rpg_skill] = battle_globals.current_character.get_skills
	match behaviour.condition:
			battle_move_behaviour.MOVE_BEHAVIOUR_CONDITION.SPECIFIC:
				for skill in character_skills:
					if skill == behaviour.specific_skill:
						skills.append(skill)
						return skills
					
			battle_move_behaviour.MOVE_BEHAVIOUR_CONDITION.ELEMENT:
				#TODO: look through all the elements of this type
				for skill in character_skills:
					if skill.skill_element == behaviour.specific_element:
						skills.append(skill)
	return skills
