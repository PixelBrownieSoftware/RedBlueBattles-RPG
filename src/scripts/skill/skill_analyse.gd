extends rpg_skill
func get_desc(chara : battle_character_data) -> String:
	return "View a characters' stats."

func on_back():
	GlobalVariables.set_flag_raw("is_analyse_select" , 0)
	
func on_select():
	GlobalVariables.set_flag_raw("is_analyse_select" , 1)
