extends Node
@onready var battle_globals : battle_variables = get_node("..")
signal get_targets(skill)
signal start_process_state()
var guard_move = preload("res://data/Skills/Misc/guard.tres")
const DEFAULT_BEHAVIOURS: Array[String] = [
	"res://data/behaviours/generic_attack.tres",
	"res://data/behaviours/exploit_weakness.tres"
]
#mode 0: decrease resistance mode 1: make a character weak mode 2: do both
func try_alter_weakness(skill : rpg_skill):
	
	if battle_globals.current_character.stamina < skill.get_final_cost(battle_globals.current_character):
		return
	var best_targets : Array[battle_character_data]
	for character in battle_globals.targets:
		var aff_el_skill : float = character.get_elemental_affinity(skill.skill_element)
		if aff_el_skill < 0.8:
			continue
		var bad_target : bool = false
		var great_target : bool = false
		for status in skill.get_all_status_effects():
			for affinity_change : elemental_affinity in status.elemental_affinity_change:
				var aff_el : element = GlobalVariables.get_element(affinity_change.elementalName)
				var aff : float = character.get_elemental_affinity(aff_el)
				var aff_change : float = affinity_change.affinity
				if aff < 2:
					if aff + aff_change < 0.5:
						bad_target = true
						break
					else:
						if aff < 1 && aff + aff_change >= 1:
							great_target = true
						if aff + aff_change >= 1.6:
							great_target = true
			if bad_target:
				break
		if bad_target:
			continue
		if great_target:
			best_targets.append(character)
	return best_targets

func get_all_possible_targets_for_move(skill : rpg_skill) -> Array[battle_character_data]:
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var skills_targets = {}
	var targets :  Array[battle_character_data]
	if battle_globals.current_character.stamina < skill.get_final_cost(battle_globals.current_character):
		return targets
	get_targets.emit(skill)
	for character in battle_globals.targets:
		var is_status :  bool = skill.power == 0
		if character.health > 0:
			targets.append(character)
	if targets.size() == 0:
		return targets
	return targets

#have a function that gets every single possible target for every single move
func get_possible_targets_for_moves(skill : rpg_skill) -> Array[battle_character_data]:
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var skills_targets = {}
	var targets :  Array[battle_character_data]
	var character_skills : Array[rpg_skill] = battle_globals.current_character.get_skills
	if battle_globals.current_character.stamina < skill.get_final_cost(battle_globals.current_character):
		return targets
	var best_targets :  Array[battle_character_data]
	var decent_targets :  Array[battle_character_data]
	var any_targets :  Array[battle_character_data]
	var alter_weaknesses : Array[battle_character_data]
	get_targets.emit(skill)
	for character in battle_globals.targets:
		var is_status :  bool = skill.power == 0
		if character.health > 0:
			if !is_status:
				alter_weaknesses = try_alter_weakness(skill)
				var aff : float = character.get_elemental_affinity(skill.skill_element)
				if aff < 1:
					any_targets.append(character)
				else: if aff >= 1 && aff < 2:
					decent_targets.append(character)
				else: if aff >= 2:
					best_targets.append(character)
			else:
				targets.append(character)
	var intelligence : int = rng.randi_range(0,2) #0 stupid 1 ignore resistances #2 exploit weaknesses
	if best_targets.size() == 0 && intelligence == 2:
		intelligence = 1
		if decent_targets.size() == 0:
			intelligence = 0
	if alter_weaknesses.size() > 0:
		intelligence = rng.randi_range(0,3) #3 try to alter weaknesses
	match intelligence:
		0:
			for character in any_targets:
				targets.append(character)
		1:
			for character in best_targets:
				targets.append(character)
			for character in decent_targets:
				targets.append(character)
		2:
			for character in best_targets:
				targets.append(character)
		3:
			for character in alter_weaknesses:
				targets.append(character)
	if targets.size() == 0:
		return targets
	return targets
	#battle_globals.current_character.chara_behaviour(battle_globals.current_character, skills_targets)

# func process_behaviour():
# 	var best_behaviours = {}
# 	var character_skills : Array[rpg_skill] = battle_globals.current_character.get_skills
# 	var behaviours : Array[battle_chara_behaviour] = battle_globals.current_character.assigned_data.chara_behaviour
# 	for skill in character_skills:
# 		if skill is skill_summon:
# 			if GlobalVariables.is_player_team(battle_globals.current_character):
# 				if PartyMembers.get_child_count() == 5:
# 					continue
# 			else:
# 				if EnemyMembers.get_child_count() == 5:
# 					continue
# 		if skill.skill_scope == skill.SCOPE.SELF:
# 			var skip_this = true
# 			for status in skill.effects_to_add:
# 				if !battle_globals.current_character.has_status(status.status):
# 					skip_this = false
# 					break
# 			if skip_this:
# 				continue
# 		if battle_globals.current_character.stamina < skill.get_final_cost(battle_globals.current_character):
# 			continue
# 		var targets :  Array[battle_character_data] = get_all_possible_targets_for_move(skill)
# 		if targets == null:
# 			continue
# 		else: if targets.size() == 0:
# 			continue
# 		var skill_behaviours = {}
# 		for behaviour_conds in behaviours:
# 			var behaviour_targs : Array[battle_character_data]
# 			for conds in behaviour_conds.condiitons:
# 				var cond_fuffilled : bool = false
# 				for targ in targets:
# 					if conds.check_cond(battle_globals.current_character,targ,skill, 0):
# 						behaviour_targs.append(targ)
# 						cond_fuffilled = true
# 				if !cond_fuffilled:
# 					break
# 			skill_behaviours.append({chance: behaviour_conds.execution_chance, targets: behaviour_targs})
# 		best_behaviours[skill] = skill_behaviours
			
# 	if best_behaviours.size() > 0:
# 		#Firstly add all the excectuion chances together, find the mean of each one
# 		#pick a random number between 0 - 1.0 and whichever it lands on, pick that behaviour and then pick a random target from the list of targets for that behaviour
# 		var total_chance : float = 0.0
# 		for skill in best_behaviours.keys():
# 			for behaviour in best_behaviours[skill]:
# 				total_chance += behaviour.chance
# 		for skill in best_behaviours.keys():
# 			for behaviour in best_behaviours[skill]:
# 				behaviour.chance = behaviour.chance / total_chance
# 		var rng = RandomNumberGenerator.new()
# 		rng.randomize()
# 		var random_num : float = rng.randf_range(0.0, 1.0)
# 		var current_chance : float = 0.0
# 		for skill in best_behaviours.keys():
# 			for behaviour in best_behaviours[skill]:
# 				current_chance += behaviour.chance
# 				if random_num <= current_chance:
# 					battle_globals.selected_move = skill
# 					behavour_targets = behaviour.targets
# 					if behavour_targets.size() > 0:
# 						var random_targ = behavour_targets.pick_random()
# 						battle_globals.target_character = random_targ
# 		# var random_move = best_behaviours.keys().pick_random()
# 		# battle_globals.selected_move = random_move
# 		# var random_targ = best_behaviours[random_move].pick_random()
# 		# battle_globals.target_character = random_targ
# 	else:
# 		battle_globals.selected_move = guard_move
# 		battle_globals.target_character = battle_globals.current_character
# 	start_process_state.emit()

func process_behaviour():
	# Store candidate actions per priority level
	# Map: priority (int) -> Array[Dictionary]
	var candidates_by_priority: Dictionary = {}
	
	var character_skills: Array[rpg_skill] = battle_globals.current_character.get_skills
	var character_data: battle_character_base = battle_globals.current_character.assigned_data
	var behaviours: Array[battle_chara_behaviour] = []

	# Check if override flag is set on the character resource
	if "override_default_behaviours" in character_data and character_data.override_default_behaviours:
		behaviours = character_data.chara_behaviour.duplicate()
	else:
		# Start with default behaviours
		for path in DEFAULT_BEHAVIOURS:
			if ResourceLoader.exists(path):
				var res = load(path)
				if res is battle_chara_behaviour:
					behaviours.append(res)
		
		# Append any custom behaviours assigned to this specific character
		if character_data.chara_behaviour:
			behaviours.append_array(character_data.chara_behaviour)
	
	
	
	var turn_num: int = battle_globals.turn_count if "turn_count" in battle_globals else 0
	var round_num: int = battle_globals.round_number if "turn_count" in battle_globals else 0

	# 1. Loop through behaviours and evaluate conditions
	for behaviour_group in behaviours:
		if behaviour_group == null or behaviour_group.condiitons.is_empty():
			continue

		var group_priority: int = behaviour_group.priority
		var group_percentage: float = behaviour_group.percentage

		for skill in character_skills:
			# Check team member count for summons
			if skill is skill_summon:
				if GlobalVariables.is_player_team(battle_globals.current_character):
					if PartyMembers.get_child_count() >= 5:
						continue
				else:
					if EnemyMembers.get_child_count() >= 5:
						continue

			# Self-buff check: skip if character already has all effects
			if skill.skill_scope == skill.SCOPE.SELF:
				var skip_this := true
				for status in skill.effects_to_add:
					if not battle_globals.current_character.has_status(status.status):
						skip_this = false
						break
				if skip_this:
					continue

			# Check stamina cost
			if battle_globals.current_character.stamina < skill.get_final_cost(battle_globals.current_character):
				continue

			# Get valid targets for the move
			var possible_targets: Array[battle_character_data] = get_all_possible_targets_for_move(skill)
			if possible_targets.is_empty():
				continue

			# Filter targets using ALL conditions in the behaviour group
			var matching_targets: Array[battle_character_data] = []
			for target in possible_targets:
				var target_valid := true
				for condition in behaviour_group.condiitons:
					if not condition.check_cond(battle_globals.current_character, target, skill, turn_num,round_num):
						target_valid = false
						break

				if target_valid:
					matching_targets.append(target)

			# If valid targets were found, add to candidates grouped by priority
			if matching_targets.size() > 0:
				if not candidates_by_priority.has(group_priority):
					candidates_by_priority[group_priority] = []

				candidates_by_priority[group_priority].append({
					"skill": skill,
					"targets": matching_targets,
					"percentage": group_percentage
				})

	# 2. Priority Selection
	if candidates_by_priority.size() > 0:
		# Find the highest priority value that successfully produced valid candidates
		var priorities: Array = candidates_by_priority.keys()
		priorities.sort()
		var highest_priority: int = priorities.back() # Highest int = highest priority
		
		# Restrict candidates ONLY to those at the highest priority level
		var top_candidates: Array = candidates_by_priority[highest_priority]

		# 3. Percentage Roll among top-priority candidates
		var total_weight: float = 0.0
		for candidate in top_candidates:
			total_weight += candidate["percentage"]

		if total_weight > 0.0:
			for candidate in top_candidates:
				candidate["percentage"] = candidate["percentage"] / total_weight

		var rng := RandomNumberGenerator.new()
		rng.randomize()
		var random_val: float = rng.randf_range(0.0, 1.0)
		var cumulative: float = 0.0
		var chosen_candidate: Dictionary = top_candidates[0]

		for candidate in top_candidates:
			cumulative += candidate["percentage"]
			if random_val <= cumulative:
				chosen_candidate = candidate
				break

		# Assign selected move and target
		battle_globals.selected_move = chosen_candidate["skill"]
		var targets_list: Array[battle_character_data] = chosen_candidate["targets"]
		battle_globals.target_character = targets_list.pick_random()

	else:
		# Fallback: Default to guard when no behaviours pass conditions
		battle_globals.selected_move = guard_move
		battle_globals.target_character = battle_globals.current_character

	start_process_state.emit()

func behaviour_process():
	#var behaviours
	#if battle_globals.current_character.override_behaviour != null:
		#behaviours = battle_globals.current_character.override_behaviour
	#else:
		#behaviours = battle_globals.current_character.assigned_data.behaviour
		
	var best_behaviours = {}
	var character_skills : Array[rpg_skill] = battle_globals.current_character.get_skills
	for skill in character_skills:
		if skill is skill_summon:
			if GlobalVariables.is_player_team(battle_globals.current_character):
				if PartyMembers.get_child_count() == 5:
					continue
			else:
				if EnemyMembers.get_child_count() == 5:
					continue
		if skill.skill_scope == skill.SCOPE.SELF:
			var skip_this = true
			for status in skill.effects_to_add:
				if !battle_globals.current_character.has_status(status.status):
					skip_this = false
					break
			if skip_this:
				continue
		if battle_globals.current_character.stamina < skill.get_final_cost(battle_globals.current_character):
			continue
		var targets :  Array[battle_character_data] = get_possible_targets_for_moves(skill)
		if targets == null:
			continue
		else: if targets.size() == 0:
			continue
		best_behaviours[skill] = targets
	if best_behaviours.size() > 0:
		var random_move = best_behaviours.keys().pick_random()
		battle_globals.selected_move = random_move
		var random_targ = best_behaviours[random_move].pick_random()
		battle_globals.target_character = random_targ
	else:
		battle_globals.selected_move = guard_move
		battle_globals.target_character = battle_globals.current_character
	#for behaviour : battle_move_behaviour in behaviours:
		#var move : Array[rpg_skill] = find_move_behaviour(behaviour)
		#if move != null:
			#best_behaviours[move] = find_target_conditions(behaviour.behaviouir_conditions, move)
		##TODO: Add another for loop for checking behaviours
		##it will also check for costs and if the cost becomes too high, go to the next behaviour
		#
	
	start_process_state.emit()

func search_target_weaknesses(el : element, num : float):
	var potential_targs : Array[battle_character_data]
	for target in battle_globals.targets:
		if target.get_elemental_affinity(el) >= num:
			potential_targs.append(target)
	return potential_targs
	
func search_target_weaknesses_hp_pc(el : element, num : float, hp_perc : float):
	var potential_targs : Array[battle_character_data] = search_target_weaknesses(el, num)
	var best_HP : int = 9999
	var chosen_target : battle_character_data
	for target in potential_targs:
		if target.health < target.max_health * hp_perc:
			if target.health < best_HP:
				best_HP = target.health
				chosen_target = target
	return chosen_target
	
func search_target_weaknesses_hp_lowest(el : element, num : float):
	var potential_targs : Array[battle_character_data] = search_target_weaknesses(el, num)
	var best_HP : int = 9999
	var chosen_target : battle_character_data
	for target in potential_targs:
		if target.health < best_HP:
			best_HP = target.health
			chosen_target = target
	return chosen_target
	
func exploit_weaknesses(skill : rpg_skill):
	search_target_weaknesses_hp_lowest(skill.skill_element, 2)

#I'll probably clean this up and modularise it
func greenler_behaviour():
	if GlobalVariables.get_permadeath_characters(EnemyMembers).size() == 0:
		pass
	

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
	var chara = battle_globals.current_character
	var character_skills : Array[rpg_skill] = chara.get_skills
	for skill in skills:
		if chara.stamina < skill.get_final_cost(chara):
			skills.remove_at(skills.rfind(skill))
	match behaviour.condition:
			battle_move_behaviour.MOVE_BEHAVIOUR_CONDITION.SPECIFIC:
				for skill in character_skills:
					if chara.stamina < skill.get_final_cost(chara):
						continue
					if skill == behaviour.specific_skill:
						skills.append(skill)
						return skills
					
			battle_move_behaviour.MOVE_BEHAVIOUR_CONDITION.ELEMENT:
				#TODO: look through all the elements of this type
				for skill in character_skills:
					if chara.stamina < skill.get_final_cost(chara):
						continue
					if skill.skill_element == behaviour.specific_element:
						skills.append(skill)
	return skills
