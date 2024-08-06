extends battle_state
class_name battle_end_state
@export var overworld_scene : String
@export var queue_state : battle_state
signal show_exp_results_menu(results_list, total)
var results_list = {}

func start_state():
	var dead_players : int =0
	var dead_enemies : int =0
	results_list = {}
	results_list["Defeated"] = 0
	results_list["Alive"] = 0
	var total_exp : int = 0
	for character in PartyMembers.get_children():
		var chara : battle_character_data = character as battle_character_data
		if chara.health <= 0:
			dead_players += 1
		else:
			results_list["Alive"] += 0.02
				
	for character in EnemyMembers.get_children():
		var chara : battle_character_data = character as battle_character_data
		if chara.health <= 0:
			for skill in chara.get_learnable_skills:
				GlobalVariables.add_extra_skill(skill)
			dead_enemies += 1
			results_list["Defeated"] += 0.04

	if dead_players == PartyMembers.get_children().size():
		total_exp = $"../../Variables/ExpereinceWatcher".local_exp_score + get_bonus()
		show_exp_results_menu.emit(results_list, total_exp)
		return
	
	if dead_enemies == EnemyMembers.get_children().size():
		results_list["All_Defeated"] = 0.1
		total_exp = $"../../Variables/ExpereinceWatcher".local_exp_score + get_bonus()
		show_exp_results_menu.emit(results_list, total_exp)
		return
	change_state.emit(queue_state)

func get_bonus() -> int:
	var bonus_multipler : float = 0
	for bonus in results_list:
		bonus_multipler += results_list[bonus]
	return $"../../Variables/ExpereinceWatcher".local_exp_score * (float)(bonus_multipler)

func leave_battle():
	var bonus : int = get_bonus()
	GlobalVariables.expereince_score += $"../../Variables/ExpereinceWatcher".local_exp_score
	GlobalVariables.expereince_score += bonus
	for character in EnemyMembers.get_children():
		var chara : battle_character_data = character as battle_character_data
		chara.queue_free()
	await get_tree().create_timer(0.4).timeout
	await FadeScene.fade_bg(Color.BLACK, 0.6)
	get_tree().change_scene_to_file(overworld_scene)
