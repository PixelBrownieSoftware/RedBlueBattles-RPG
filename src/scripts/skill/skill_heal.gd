extends rpg_skill
class_name skill_heal

func get_desc(chara : battle_character_data) -> String:
	return "Heals target."

func damage_formula(attacker: battle_character_data, target: battle_character_data) -> int:
	var modifiers = attacker.get_element_potential_modifiers(self)
	print("Multiplier " + str(modifiers["damage_multipler"]))
	var stat_element = calculate_raw_power(attacker)["output"]
	return (((stat_element * power)) * modifiers["damage_multipler"]) * -1

func process_damage(attacker: battle_character_data, target: battle_character_data):
	var return_val = {}
	var damage_amount : int = damage_formula(attacker, target)
	target.damage(damage_amount)
	return_val["Press_turn"] = PRESS_TURN.PT.NORMAL
	return_val["Amount"] = 0
	return_val["No_Anim"] = 1
	return return_val
