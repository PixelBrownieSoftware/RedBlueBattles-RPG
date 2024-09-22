extends battle_state
class_name battle_process_state

@export var after_process_state : battle_state
signal put_damage_numbers(user,targ,dmg, pt)
signal notifcation_anim(skill)
signal spawn_battle_fx(anim_name, battle_char)
signal finish_anim()

func start_state():
	var skill : rpg_skill = battle_globals.selected_move
	if skill.name == "Pass":
		battle_globals.final_press_turn_flag= PRESS_TURN.PT.WEAK
		battle_globals.current_character.update_current_status_effects("after_action")
		battle_globals.current_character.on_character_end_turn.emit()
	else:
		await process_move(skill)
	change_state.emit(after_process_state)
	
func process_move(skill : rpg_skill):
	var character_target : battle_character_data = battle_globals.target_character
	var character_user : battle_character_data = battle_globals.current_character
	character_user.stamina -= skill.get_final_cost(character_user)
	await get_tree().create_timer(0.2).timeout
	notifcation_anim.emit(skill)
	await get_tree().create_timer(0.8).timeout
	var actor_user : battle_character_actor = battle_globals.get_actor(character_user)
	battle_globals.final_press_turn_flag = PRESS_TURN.PT.NORMAL
	var num_times : int = randi_range(skill.repeat_min, skill.repeat_max)
	
	for i in range(num_times):
		for anim : rpg_skill_animation in skill.skill_animation:
			match anim.skill_animation:
				anim.SKILL_ANIMATION_TYPE.WAIT:
					await get_tree().create_timer(anim.time_amount).timeout
				anim.SKILL_ANIMATION_TYPE.FX_ANIMATION:
					spawn_battle_fx.emit(anim.animation_name, character_target)
					await finish_anim
					#1. Spawn the FX
					#2. Set the fx done variable to false
					#3. Wait for it to be true
					#pass
				anim.SKILL_ANIMATION_TYPE.ANIMATION:
					if anim.time_amount > 0:
						actor_user.play_animation(anim.animation_name)
						await get_tree().create_timer(anim.time_amount).timeout
						actor_user.play_animation("idle")
					else:
						var play_anim = actor_user.play_animation(anim.animation_name)
						if play_anim != false:
							await actor_user.anim_finish_signal
						actor_user.play_animation("idle")
				anim.SKILL_ANIMATION_TYPE.CALCULATION:
					#TODO: Maybe put in overwhelm
					var attack_result = {}
					if character_target.health > 0:
						attack_result = character_target.damage_character(character_user, skill)
						var damage_num  = attack_result["Amount"]
						var calculated_PT = attack_result["Press_turn"]
						print("Press turn number: " + str(calculated_PT))
						if battle_globals.final_press_turn_flag < calculated_PT:
							battle_globals.final_press_turn_flag = calculated_PT
						print(damage_num)
						if skill.power > 0:							
							if calculated_PT != PRESS_TURN.PT.MISS && calculated_PT != PRESS_TURN.PT.VOID:
								spawn_battle_fx.emit("physical_hit_fx", character_target)
							put_damage_numbers.emit(character_user, character_target, damage_num, calculated_PT)
						await get_tree().create_timer(0.4).timeout
	character_user.update_current_status_effects("after_action")
	character_user.on_character_end_turn.emit()
	
func fx_anim_done():
	finish_anim.emit()
