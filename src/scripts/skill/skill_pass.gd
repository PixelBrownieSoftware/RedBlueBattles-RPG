extends rpg_skill
class_name skill_pass

func get_desc(chara : battle_character_data) -> String:
	return "Passes turn to the next user.\nTurns any full turn icon into a blinking one."

func process_damage(attacker: battle_character_data, target: battle_character_data):
	var return_val = {}
	return_val["Press_turn"] = PRESS_TURN.PT.WEAK
	return_val["Amount"] = 0
	return_val["No_Anim"] = 1
	return return_val
