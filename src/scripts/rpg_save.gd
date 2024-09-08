extends Node
var save_path = OS.get_user_data_dir() + "/save.rbb"

func save_game():
	print(save_path)
	var character_equip_skills = { "None" : [] }
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	
	file.store_32(GlobalVariables.expereince_score)
	file.store_16(PartyMembers.get_children().size())
	for player : battle_character_data in PartyMembers.get_children():
		character_equip_skills[player.name] = []
		print("filename " + player.assigned_data.resource_path)
		file.store_pascal_string(player.assigned_data.resource_path)
		file.store_pascal_string(player.name)
		file.store_32(player.max_health)
		file.store_8(player.max_stamina)
		file.store_32(player.current_level)
	
	for skill in GlobalVariables.extra_skills:
		var who_has_skill = GlobalVariables.who_has_equippied_skill(skill)
		if who_has_skill == null:
			character_equip_skills["None"].append(skill.resource_path)
		else:
			character_equip_skills[who_has_skill.name].append(skill.resource_path)
	#GlobalVariables.extra_skills.size()
	file.store_32(character_equip_skills.keys().size())
	for chrEquip in character_equip_skills.keys():
		file.store_pascal_string(chrEquip)
		file.store_32(character_equip_skills[chrEquip].size())
		for skill_name in character_equip_skills[chrEquip]:
			file.store_pascal_string(skill_name)
	file.close()
	
	
		#
	#TODO: Save:
	#- Party members:
	#	- max health X
	#	- exp to next level X
	#	- level X
	
	#- Globals:
	#	- expereince
	#	- extra skills
	#	- who has the extra skills equipped
	
func load_game():
	var file = FileAccess.open(save_path, FileAccess.READ)
	GlobalVariables.expereince_score = file.get_32()
	var party_member_count = file.get_16()
	for i in range(party_member_count):
		var obj_name = file.get_pascal_string()
		var character_name = file.get_pascal_string()
		var max_health = file.get_32()
		var max_stamina = file.get_8()
		var level = file.get_32()
		var load_obj = load(obj_name)
		var character = CharacterFactory.create_new_character(load_obj, PartyMembers, level)
		character.max_health = max_health
		character.max_stamina = max_stamina
		character.name = character_name
	var character_skills_count = file.get_32()
	for i in range(character_skills_count):
		var character_name = file.get_pascal_string()
		var skill_on_character_count = file.get_32()
		for i2 in range(skill_on_character_count):
			var skill_name = file.get_pascal_string()
			var skill_obj =load(skill_name)
			GlobalVariables.add_extra_skill(skill_obj)
			if character_name != "None":
				for chara in PartyMembers.get_children():
					if chara.name == character_name:
						GlobalVariables.assign_skill(chara, skill_obj)
	file.close()
