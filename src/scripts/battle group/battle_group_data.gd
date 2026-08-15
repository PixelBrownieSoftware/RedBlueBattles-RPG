extends Resource
class_name battle_group_data
@export var opponents : Array[battle_group_member]
@export var rewards : Array[battle_group_reward]

func end_battle():
	pass
	
func start_battle():
	for battle_character_member : battle_group_member in opponents:
		if !battle_character_member.check_flags():
			continue
		var rng = RandomNumberGenerator.new()
		rng.randomize()
		var level : int =  rng.randi_range(battle_character_member.min_level, battle_character_member.max_level)
		var character : battle_character_data = CharacterFactory.create_new_character(battle_character_member.character,EnemyMembers , level)
		character.is_permadeath = battle_character_member.perma_death
		for skill in battle_character_member.skills:
			character.assign_skill(skill)
