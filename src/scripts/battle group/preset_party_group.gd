class_name present_group_data
extends battle_group_data

@export var preset_members : Array[battle_group_member]

func end_battle():
	for chara : battle_character_data in PartyMembers.get_children():
		if chara.flags.has("hidden"):
			GlobalVariables.enabled_party_members[chara] = true
			chara.flags.erase("hidden")
		if chara.flags.has("temp"):
			chara.queue_free()

func start_battle():
	for chara in PartyMembers.get_children():
		if GlobalVariables.enabled_party_members[chara]:
			GlobalVariables.enabled_party_members[chara] = false
			chara.flags.set("hidden", true)
	for chara in preset_members:
		var rng = RandomNumberGenerator.new()
		rng.randomize()
		var level : int =  rng.randi_range(chara.min_level, chara.max_level)
		var character : battle_character_data = CharacterFactory.create_new_character(chara.character,PartyMembers , level, false, chara.skills)
		character.flags.set("temp", true)
		#for skill in chara.skills:
			#character.assign_skill(skill)
		#character.health = character.health_net
	super()
