extends Node
class_name battle_character_factory
var battle_char_obj = preload("res://objects/battle_character_data.tscn")
var alphabet : String = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
signal create_character_notification(character: battle_character_data)
signal delete_character_notification(character: battle_character_data)

func destroy_character(chara : battle_character_data):
	delete_character_notification.emit(chara)
	#chara.queue_free()

func create_new_character(base : battle_character_base, party, level, permadeath : bool = false) -> battle_character_data:
	var chara : battle_character_data = battle_char_obj.instantiate()
	chara.new_data(base, level)
	chara.name = base.name
	chara.is_permadeath = permadeath
	party.add_child(chara)
	var counter : int = 0
	for cha in party.get_children():
		if cha.assigned_data == base:
			counter += 1
	if counter > 1:
		chara.name = base.name + " " + alphabet[counter - 1]
	if party == PartyMembers:
		if GlobalVariables.get_enabled_party_members_count() <= 5:
			GlobalVariables.enabled_party_members[chara] = true
		else:
			GlobalVariables.enabled_party_members[chara] = false
	create_character_notification.emit(chara)
	return chara
	
