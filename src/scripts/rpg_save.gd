extends Node

var os_path = OS.get_user_data_dir() 

func get_slot_path(slot_index: int) -> String:
	return os_path + "/save_slot_" + str(slot_index) + ".rbb"

func save_exists(slot_index: int) -> bool:
	return FileAccess.file_exists(get_slot_path(slot_index))

func get_slot_summary(slot_index: int) -> Dictionary:
	if not save_exists(slot_index):
		return {}

	var file = FileAccess.open(get_slot_path(slot_index), FileAccess.READ)
	if file == null:
		return {}

	# Read headers
	var exp_score = file.get_64()
	var extra_skills_limit = file.get_8()
	var battles_count = file.get_16()
	for i in range(battles_count):
		file.get_pascal_string()

	var party_count = file.get_16()
	var party_members_info: Array[Dictionary] = []

	for i in range(party_count):
		var char_path = file.get_pascal_string()
		var char_name = file.get_pascal_string()
		var max_hp = file.get_32()
		var max_stam = file.get_8()
		var lvl = file.get_32()

		# Load base resource to retrieve character color
		var char_color_html := "ffffff"
		if ResourceLoader.exists(char_path):
			var base_res = load(char_path) as battle_character_base
			if base_res and "character_colour" in base_res:
				char_color_html = base_res.character_colour.to_html()

		party_members_info.append({
			"name": char_name,
			"level": lvl,
			"max_health": max_hp,
			"color_html": char_color_html
		})

	file.close()

	return {
		"party": party_members_info
	}

func delete_slot(slot_index: int) -> bool:
	var path := get_slot_path(slot_index)
	if FileAccess.file_exists(path):
		var err := DirAccess.remove_absolute(path)
		return err == OK
	return false

func save_game(slot_index: int = 0):
	var character_equip_skills = { "None" : [] }
	var file = FileAccess.open(get_slot_path(slot_index), FileAccess.WRITE_READ)
	file.store_64(GlobalVariables.expereince_score)
	file.store_8(GlobalVariables.extra_skills_limit)
	file.store_16(GlobalVariables.battles_availible.size())
	for battle : battle_level_group in GlobalVariables.battles_availible:
		file.store_pascal_string(battle.resource_path)
	file.store_16(PartyMembers.get_children().size())
	for player : battle_character_data in PartyMembers.get_children():
		character_equip_skills[player.name] = []
		file.store_pascal_string(player.assigned_data.resource_path)
		file.store_pascal_string(player.name)
		file.store_32(player.max_health)
		file.store_8(player.max_stamina)
		file.store_32(player.current_level)
	
	for skill in GlobalVariables.extra_skills:
		var who_has_skill = GlobalVariables.who_has_equippied_skill(skill)
		var move_name : String = str(skill.resource_path.get_file())
		move_name = move_name.replace(".tres", "")
		var skill_UID = GlobalVariables.skill_uid_lookup[move_name]
		if who_has_skill == null:
			character_equip_skills["None"].append(skill.resource_path)
		else:
			character_equip_skills[who_has_skill.name].append(skill.resource_path)

	file.store_32(character_equip_skills.keys().size())
	for chrEquip in character_equip_skills.keys():
		file.store_pascal_string(chrEquip)
		file.store_32(character_equip_skills[chrEquip].size())
		for skill_name in character_equip_skills[chrEquip]:
			file.store_pascal_string(skill_name)

	for flag in GlobalVariables.global_flags:
		file.store_8(GlobalVariables.global_flags[flag])
	file.close()

func load_game(slot_index: int = 0):
	if not save_exists(slot_index):
		return

	var file = FileAccess.open(get_slot_path(slot_index), FileAccess.READ)
	GlobalVariables.expereince_score = file.get_64()
	GlobalVariables.extra_skills_limit = file.get_8()
	var availiable_battles_count = file.get_16()
	for i in range(availiable_battles_count):
		var battle_path = file.get_pascal_string()
		var load_obj = load(battle_path)
		GlobalVariables.battles_availible.append(load_obj)
	var party_member_count = file.get_16()
	for i in range(party_member_count):
		var character_path = file.get_pascal_string()
		var character_name = file.get_pascal_string()
		var max_health = file.get_32()
		var max_stamina = file.get_8()
		var level = file.get_32()
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
			var skill_name = file.get_pascal_string()
			var skill_obj = load(skill_name)
			GlobalVariables.add_extra_skill(skill_obj)
			if character_name != "None":
				for chara in PartyMembers.get_children():
					if chara.name == character_name:
						GlobalVariables.assign_skill(chara, skill_obj)
					chara.health = chara.health_net
	for flag in GlobalVariables.global_flags:
		GlobalVariables.set_flag_raw(flag, file.get_8()) 
	file.close()
