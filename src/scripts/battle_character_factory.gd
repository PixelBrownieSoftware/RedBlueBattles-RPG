extends Node
class_name battle_character_factory

func create_new_character(base : battle_character_base, party, level) -> battle_character_data:
	var chara = battle_character_data.new()
	chara.new_data(base, level)
	chara.name = base.name
	party.add_child(chara)
	return chara
	
