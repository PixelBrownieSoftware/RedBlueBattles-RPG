extends battle_state
class_name battle_end_state
@export var overworld_scene : String
@export var queue_state : battle_state
signal show_exp_results_menu(results_list, total)
signal show_moves_learned(moves_learned)
signal show_other_rewards(rewards)
var results_list = {}

func start_state():
	var dead_players : int =0
	var dead_enemies : int =0
	var new_moves_learned : Array[rpg_skill]
	results_list = {}
	var total_exp : int = 0
	for character in PartyMembers.get_children():
		var chara : battle_character_data = character as battle_character_data
		if chara.health <= 0:
			dead_players += 1
		else:
			if !results_list.has("Alive"):
				results_list["Alive"] = 0.02
			else:
				results_list["Alive"] += 0.02
				
	for character in EnemyMembers.get_children():
		var chara : battle_character_data = character as battle_character_data
		if chara.health <= 0:
			if chara.health <= -(chara.max_health /2):
				if !results_list.has("Overwhelm"):
					results_list["Overwhelm"] = 0.08
				else:
					results_list["Overwhelm"] += 0.08
			for skill in chara.get_learnable_skills:
				var ex_skills = GlobalVariables.add_extra_skill(skill)
				if !ex_skills:
					new_moves_learned.append(skill)
			dead_enemies += 1
			if !results_list.has("Defeated"):
				results_list["Defeated"] = 0.04
			else:
				results_list["Defeated"] += 0.04

	if dead_players == GlobalVariables.get_characters(PartyMembers).size():
		total_exp = $"../../Variables/ExpereinceWatcher".local_exp_score + get_bonus()
		show_moves_learned.emit(new_moves_learned)
		show_exp_results_menu.emit(results_list, total_exp)
		return
	
	if dead_enemies == EnemyMembers.get_children().size():
		results_list["All_Defeated"] = 0.1
		total_exp = $"../../Variables/ExpereinceWatcher".local_exp_score + get_bonus()
		var gained_rewards : Array[String]
		
		for reward in GlobalVariables.current_battle.rewards:
			print("Flag name: " + reward.flag_req.name + " " + str(reward.flag_req.flag))
			if GlobalVariables.check_flag(reward.flag_req):
				reward.give_reward()
				gained_rewards.append(reward.return_message())
		
		
		#for character in GlobalVariables.current_battle.unlockables:
			#for member : battle_character_data in PartyMembers.get_children():
				#if member.assigned_data == character:
					#break
				#else:
					#if gained_characters.rfind(character) == -1:
						#gained_characters.append(character)
						#CharacterFactory.create_new_character(character,PartyMembers, 1)
		show_moves_learned.emit(new_moves_learned)
		show_exp_results_menu.emit(results_list, total_exp)
		show_other_rewards.emit(gained_rewards)
		change_level_stuff()
		return
	change_state.emit(queue_state)

func change_level_stuff():
	for level in GlobalVariables.current_level.battle_groups_remove:
		var remove_battle_ind = GlobalVariables.battles_availible.rfind(level.name)
		if remove_battle_ind != -1:
			GlobalVariables.battles_availible.remove_at(remove_battle_ind)
	if GlobalVariables.current_level.self_destruct_after_win:
		var self_dest_index = GlobalVariables.battles_availible.rfind(GlobalVariables.current_level)
		GlobalVariables.battles_availible.remove_at(self_dest_index)
	for level in GlobalVariables.current_level.battle_groups_unlock:
		GlobalVariables.battles_availible.append(level)

func get_bonus() -> int:
	var bonus_multipler : float = 0
	for bonus in results_list:
		bonus_multipler += results_list[bonus]
	return $"../../Variables/ExpereinceWatcher".local_exp_score * (float)(bonus_multipler)

func leave_battle():
	var bonus : int = get_bonus()
	GlobalVariables.expereince_score += $"../../Variables/ExpereinceWatcher".local_exp_score
	GlobalVariables.expereince_score += bonus
	for character in PartyMembers.get_children():
		var chara : battle_character_data = character as battle_character_data
		chara.health = chara.max_health
		chara.stamina = 0
		chara.status_effects.clear()
	for character in EnemyMembers.get_children():
		var chara : battle_character_data = character as battle_character_data
		chara.queue_free()
	SaveSystem.save_game()
	await get_tree().create_timer(0.4).timeout
	await FadeScene.fade_bg(Color.BLACK, 0.6)
	get_tree().change_scene_to_file(overworld_scene)
