extends Node
class_name battle_character_factory

func create_new_character(base : battle_character_base, party, level) -> battle_character_data:
	var chara = battle_character_data.new()
	chara.new_data(base, level)
	chara.name = base.name
	party.add_child(chara)
	if party == PartyMembers:
		if GlobalVariables.get_enabled_party_members_count() <= 5:
			GlobalVariables.enabled_party_members[chara] = true
		else:
			GlobalVariables.enabled_party_members[chara] = false
	return chara
	
