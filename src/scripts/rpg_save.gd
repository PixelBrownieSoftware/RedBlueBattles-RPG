extends Node
var os_path = OS.get_user_data_dir() 
var save_path ="/RedBlueBattles/"
var save_file_name = "/save.rbb"
func save_game():
	print(os_path + save_file_name)
	var character_equip_skills = { "None" : [] }
	var file = FileAccess.open(os_path + save_file_name, FileAccess.WRITE_READ)
	file.store_64(GlobalVariables.expereince_score)
	file.store_8(GlobalVariables.extra_skills_limit)
	file.store_16(GlobalVariables.battles_availible.size())
	for battle : battle_level_group in GlobalVariables.battles_availible:
		file.store_pascal_string(battle.resource_path)
	file.store_16(PartyMembers.get_children().size())
	for player : battle_character_data in PartyMembers.get_children():
		character_equip_skills[player.name] = []
		#print("filename character: " + str(GlobalVariables.character_uid_lookup[player.name]))
		#file.store_64(GlobalVariables.character_uid_lookup[player.name])
		file.store_pascal_string(player.assigned_data.resource_path)
		file.store_pascal_string(player.name)
		file.store_32(player.max_health)
		file.store_8(player.max_stamina)
		file.store_32(player.current_level)
	
	for skill in GlobalVariables.extra_skills:
		var who_has_skill = GlobalVariables.who_has_equippied_skill(skill)
		#print("filename character" + str(GlobalVariables.skill_uid_lookup[skill.name]))
		var move_name : String = str(skill.resource_path.get_file())
		move_name = move_name.replace(".tres", "")
		var skill_UID = GlobalVariables.skill_uid_lookup[move_name]
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
			#file.store_64(skill_name)
	for flag in GlobalVariables.global_flags:
		file.store_8(GlobalVariables.global_flags[flag])
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
	var file = FileAccess.open(os_path + save_file_name, FileAccess.READ)
	GlobalVariables.expereince_score = file.get_64()
	GlobalVariables.extra_skills_limit = file.get_8()
	var availiable_battles_count = file.get_16()
	for i in range(availiable_battles_count):
		var battle_path = file.get_pascal_string()
		var load_obj = load(battle_path)
		GlobalVariables.battles_availible.append(load_obj)
	var party_member_count = file.get_16()
	for i in range(party_member_count):
		#var obj_uid = file.get_64()
		#print(ResourceUID.id_to_text(obj_uid))
		var character_path = file.get_pascal_string()
		var character_name = file.get_pascal_string()
		var max_health = file.get_32()
		var max_stamina = file.get_8()
		var level = file.get_32()
		#var resource_loc = ResourceUID.id_to_text(obj_uid)
		var load_obj = load(character_path)
		var character = CharacterFactory.create_new_character(load_obj, PartyMembers, level)
		character.max_health = max_health
		character.health = character.max_health
		character.max_stamina = max_stamina
		character.name = character_name
	var character_skills_count = file.get_32()
	for i in range(character_skills_count):
		var character_name = file.get_pascal_string()
		var skill_on_character_count = file.get_32()
		for i2 in range(skill_on_character_count):
			#var skill_name = file.get_64()
			#var skill_obj =load(ResourceUID.id_to_text(skill_name))
			var skill_name = file.get_pascal_string()
			var skill_obj =load(skill_name)
			GlobalVariables.add_extra_skill(skill_obj)
			if character_name != "None":
				for chara in PartyMembers.get_children():
					if chara.name == character_name:
						GlobalVariables.assign_skill(chara, skill_obj)
	for flag in GlobalVariables.global_flags:
		GlobalVariables.set_flag_raw(flag, file.get_8()) 
	file.close()
