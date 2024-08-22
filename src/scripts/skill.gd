extends Resource
class_name rpg_skill

enum SCOPE {ALLY, FOE, ALL, NONE = -1}
@export var name : String = "Empty"
@export var learnable : bool = true
@export var power : int = 0
@export var stamina_cost : int = 0
@export var repeat_min : int = 1
@export var repeat_max : int = 1
@export var stat_requirement : rpg_stats = rpg_stats.new()
@export var skill_scope : SCOPE = SCOPE.FOE
@export var skill_element : element = preload("res://data/elements/None.tres")
@export var skill_animation : Array[rpg_skill_animation]

func get_desc() -> String:
	var desc : String
	desc += name + "\n"
	desc += "Power: " + str(power) + "\n"
	desc += "Stamina Cost: " + str(stamina_cost) + "\n"
	desc += "Element: " + skill_element.name + "\n"
	var scope : String
	match skill_scope:
		SCOPE.FOE:
			scope= "To enemy"
	desc += "Scope: " + scope + "\n"
	return desc

func get_requirements(chara : battle_character_data, stat) -> int:
	var potential : int = chara.get_element_potential_modifiers(self)["requirement_discount"]
	var total: int  = stat + potential
	total = clampi(total, 0, 999)
	return total
	
func requirements_met(chara : battle_character_data):
	#The higher the potential, the lower the requirements
	#It may also do more damage
	var results =  {}
	results["str_req"] = get_requirements(chara,stat_requirement.strength)
	results["vit_req"] = get_requirements(chara,stat_requirement.vitality)
	results["luc_req"] = get_requirements(chara,stat_requirement.luck)
	results["agi_req"] = get_requirements(chara,stat_requirement.agility)
	results["mag_req"] = get_requirements(chara,stat_requirement.magic_pow)
	results["dex_req"] = get_requirements(chara,stat_requirement.dexterity)
	
	var str_req_sati : bool = (chara.strength >= results["str_req"])
	var vit_req_sati : bool = (chara.vitality >= results["vit_req"])
	var luc_req_sati : bool = (chara.luck >= results["luc_req"])
	var agi_req_sati : bool = (chara.agility >= results["agi_req"])
	var mag_req_sati : bool = (chara.magic_pow >= results["mag_req"])
	var dex_req_sati : bool = (chara.dexterity >= results["dex_req"])
	results["req_met"] = str_req_sati && vit_req_sati && luc_req_sati && agi_req_sati && mag_req_sati && dex_req_sati
	return results

