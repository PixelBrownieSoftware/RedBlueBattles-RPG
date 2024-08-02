extends battle_state
class_name battle_process_state

@export var after_process_state : battle_state
signal put_damage_numbers(user,targ,dmg, pt)
signal notifcation_anim(skill)

func start_state():
	var skill : rpg_skill = battle_globals.selected_move
	if skill.name == "Pass":
		battle_globals.final_press_turn_flag= PRESS_TURN.PT.WEAK
	else:
		await process_move(skill)
	change_state.emit(after_process_state)
	
func process_move(skill : rpg_skill):
	var character_target : battle_character_data = battle_globals.target_character
	var character_user : battle_character_data = battle_globals.current_character
	character_user.stamina -= skill.stamina_cost
	await get_tree().create_timer(0.2).timeout
	notifcation_anim.emit(skill)
	await get_tree().create_timer(1.2).timeout
	var actor_user : battle_character_actor = battle_globals.get_actor(character_user)
	battle_globals.final_press_turn_flag = PRESS_TURN.PT.NORMAL
	for anim : rpg_skill_animation in skill.skill_animation:
		match anim.skill_animation:
			anim.SKILL_ANIMATION_TYPE.WAIT:
				await get_tree().create_timer(anim.time_amount).timeout
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
				var damage_num : int = character_target.damage_character(character_user, skill)
				var calculated_PT : PRESS_TURN.PT = PRESS_TURN.PT.NORMAL
				print(calculated_PT)
				
				var el_affinity : float = character_target.get_elemental_affinity(skill.skill_element)
				if el_affinity >= 2:
					calculated_PT = PRESS_TURN.PT.WEAK
				else: if el_affinity < 2 && el_affinity > 0:
					calculated_PT = PRESS_TURN.PT.NORMAL
				else: if el_affinity == 0:
					calculated_PT = PRESS_TURN.PT.VOID
				else: if el_affinity < 0 && el_affinity > -2:
					calculated_PT = PRESS_TURN.PT.REFLECT
				else:
					calculated_PT = PRESS_TURN.PT.ABSORB
				if battle_globals.final_press_turn_flag < calculated_PT:
					battle_globals.final_press_turn_flag = calculated_PT
				print(damage_num)
				put_damage_numbers.emit(character_user, character_target, damage_num, calculated_PT)
				await get_tree().create_timer(1.5).timeout
	
