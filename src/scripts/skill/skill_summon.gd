extends rpg_skill
class_name skill_summon
@export var characters_to_summon : Array[battle_group_member]
@export_range(1,3) var amount : int

func get_desc(chara : battle_character_data) -> String:
	return "Summon"

func process_damage(attacker: battle_character_data, target: battle_character_data):
	var return_val = {}
	var party =  PartyMembers if GlobalVariables.is_player_team(attacker) else EnemyMembers
	for i in range(amount):
		if party.get_child_count() == 5:
			break
		var summon_chara : battle_group_member = characters_to_summon.pick_random()
		var rng = RandomNumberGenerator.new()
		rng.randomize()
		var level : int =  rng.randi_range(summon_chara.min_level, summon_chara.max_level)
		var character = CharacterFactory.create_new_character(summon_chara.character, party, level, true)
		for skill in summon_chara.skills:
			character.assign_skill(skill)
	if amount == 1:
		return_val["Press_turn"] = PRESS_TURN.PT.WEAK
	else:
		return_val["Press_turn"] = PRESS_TURN.PT.NORMAL
	return_val["Amount"] = 0
	return_val["No_Anim"] = 1
	return return_val
