extends Node
class_name global_variables

@export var debug_mode : bool = false
@export var expereince_score : int = 0
var multilplier: float = 1

func set_multiplier(mul):
	multilplier = mul
	
func reset_multipiler():
	multilplier = 1

@export var extra_skills : Array[rpg_skill]

#Check whether the skill exists in the extra skills bit
func add_extra_skill(skill : rpg_skill) -> bool:
	if extra_skills.rfind(skill) != -1:
		return true
	print(extra_skills.size())
	extra_skills.append(skill)
	print("Gained " + skill.name + "!")
	print(extra_skills.size())
	return false

#func get_all_chara_exsk(chara : battle_character_data) -> Array[rpg_skill]:
	#var skills : Array[rpg_skill] 
	#for skill in extra_skills:
		#if extra_skills[skill] == chara:
			#skills.append(skill)		
	#return skills
	
func assign_skill(chara : battle_character_data, extra_skill : rpg_skill):
	var ind = chara.extra_skills.rfind(extra_skill)
	if ind == -1:
		chara.assign_skill(extra_skill)
	else:
		chara.extra_skills.remove_at(ind)
