extends Node
class_name battle_character_factory
var battle_char_obj = preload("res://objects/battle_character_data.tscn")
var alphabet : String = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"

func create_new_character(base : battle_character_base, party, level) -> battle_character_data:
	var chara = battle_char_obj.instantiate()
	chara.new_data(base, level)
	chara.name = base.name
	party.add_child(chara)
	var counter : int = -1
	for cha in party.get_children():
		if cha.assigned_data == base:
			counter += 1
	if counter > 0:
		chara.name = base.name + " " + alphabet[counter - 1]
	if party == PartyMembers:
		if GlobalVariables.get_enabled_party_members_count() <= 5:
			GlobalVariables.enabled_party_members[chara] = true
		else:
			GlobalVariables.enabled_party_members[chara] = false
	return chara
	
