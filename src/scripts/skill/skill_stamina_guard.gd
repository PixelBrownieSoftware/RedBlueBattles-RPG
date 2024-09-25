extends rpg_skill
class_name skill_stamina_guard

func get_desc(chara : battle_character_data) -> String:
	return "Increases physical resistance as well as conserves a stamina point."

func process_damage(attacker: battle_character_data, target: battle_character_data):
	var return_val = {}
	target.change_stamina(power)
	status_apply(target)
	return_val["Press_turn"] = PRESS_TURN.PT.NORMAL
	return_val["Amount"] = 0
	return_val["No_Anim"] = 1
	return return_val
