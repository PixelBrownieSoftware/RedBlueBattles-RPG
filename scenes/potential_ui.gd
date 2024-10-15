extends HBoxContainer


func display_character_aff(battle_char : battle_character_data):
	for elemental in get_children():
		elemental.character = battle_char
		elemental.set_potential()
