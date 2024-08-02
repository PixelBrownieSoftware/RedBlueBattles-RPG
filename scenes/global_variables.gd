extends Node
class_name global_variables

@export var expereince_score : int = 0
var multilplier: float = 1

func set_multiplier(mul):
	multilplier = mul
	
func reset_multipiler():
	multilplier = 1

@export var extra_skills = {}

func add_extra_skill(skill : rpg_skill):
	if extra_skills.find_key(skill):
		return
	print(extra_skills.size())
	extra_skills[skill] = null
	print("Gained " + skill.name + "!")
	print(extra_skills.size())

func get_all_chara_exsk(chara : battle_character_data) -> Array[rpg_skill]:
	var skills : Array[rpg_skill] 
	for skill in extra_skills:
		if extra_skills[skill] == chara:
			skills.append(skill)		
	return skills
	
func assign_skill(chara : battle_character_data, extra_skill : rpg_skill):
	extra_skills[extra_skill] = chara
