extends battle_state
class_name battle_end_state
@export var overworld_scene : String
@export var queue_state : battle_state

func start_state():
	var dead_players : int =0
	var dead_enemies : int =0
	for character in PartyMembers.get_children():
		var chara : battle_character_data = character as battle_character_data
		if chara.health <= 0:
			dead_players += 1
	for character in EnemyMembers.get_children():
		var chara : battle_character_data = character as battle_character_data
		if chara.health <= 0:
			for skill in chara.get_learnable_skills:
				GlobalVariables.add_extra_skill(skill)
			dead_enemies += 1

	if dead_players == PartyMembers.get_children().size():
		#TODO: End battle and give everyone EXP
		#death will not go unrewarded
		leave_battle()
		return
	
	if dead_enemies == EnemyMembers.get_children().size():
		#TODO: End battle and put a success flag
		leave_battle()
		return
	change_state.emit(queue_state)

func leave_battle():
	GlobalVariables.expereince_score += $"../../Variables/ExpereinceWatcher".local_exp_score
	for character in EnemyMembers.get_children():
		var chara : battle_character_data = character as battle_character_data
		chara.queue_free()
	await get_tree().create_timer(0.4).timeout
	await FadeScene.fade_bg(Color.BLACK, 0.6)
	get_tree().change_scene_to_file(overworld_scene)
