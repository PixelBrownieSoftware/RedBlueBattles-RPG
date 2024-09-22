extends Resource
class_name rpg_skill

enum SCOPE {ALLY, FOE, ALL, SELF, NONE = -1}
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
@export var usable_by_anyone : bool = false	#stuff like pass and anything exclusive for status effects
@export var effects_to_remove : Array[status_effect]
@export var effects_to_add : Array[status_effect_chance]

func get_desc(chara : battle_character_data) -> String:
	var desc : String
	var final_st = get_final_cost(chara)
	desc += name + "\n"
	if power > 0:
		desc += "Power: " + str(power) + "\n"
	if stamina_cost > 0:
		if final_st != stamina_cost:
			var cost_colour = Color.GREEN if stamina_cost > final_st else Color.RED
			desc += "Stamina Cost: [s]" + str(stamina_cost) + "[/s] ([" + "color=" + cost_colour.to_html() + "]" + str(final_st) + "[/color])" + "\n"
		else:
			desc += "Stamina Cost: " + str(stamina_cost) + "\n"
	desc += "Element: " + "[color=" + skill_element.colour.to_html() + "]" + skill_element.name + "[/color]\n"
	var scope : String
	match skill_scope:
		SCOPE.SELF:
			scope= "To user"
		SCOPE.ALLY:
			scope= "To ally"
		SCOPE.FOE:
			scope= "To enemy"
	desc += "Scope: " + scope + "\n\n"
	if skill_element.effects_to_add.size() > 0:
		desc += "Elemental Status inflict:\n"
		for status in skill_element.effects_to_add:
			desc += "	-" + status.status.name + " (" + str(status.chance * 100) + "%)\n"
	if effects_to_add.size() > 0:
		desc += "Status inflict:\n"
		for status in effects_to_add:
			desc += "	-" + status.status.name + " (" + str(status.chance * 100) + "%)\n"
	
	desc +="\n"
	return desc
	
	
func get_final_cost(chara : battle_character_data) -> int:
	var potential : int = chara.get_element_potential_modifiers(self)["stamina_discount"]
	var total: int  = stamina_cost + potential
	if stamina_cost > 0:
		total = clampi(total, 1, 999)
	else:
		total = clampi(total, 0, 999)
	return total

func get_requirements(chara : battle_character_data, stat) -> int:
	var potential : int = chara.get_element_potential_modifiers(self)["requirement_discount"]
	var total: int  = stat + potential
	total = clampi(total, 0, 999)
	return total
	
func requirements_met(chara : battle_character_data):
	#The higher the potential, the lower the requirements
	#It may also do more damage
	var results =  {}
	results["str_req_og"] = stat_requirement.strength
	results["vit_req_og"] = stat_requirement.vitality
	results["luc_req_og"] = stat_requirement.luck
	results["agi_req_og"] = stat_requirement.agility
	results["mag_req_og"] = stat_requirement.magic_pow
	results["dex_req_og"] = stat_requirement.dexterity
	results["stamina_req_og"] = stamina_cost
	
	results["str_req"] = get_requirements(chara,stat_requirement.strength)
	results["vit_req"] = get_requirements(chara,stat_requirement.vitality)
	results["luc_req"] = get_requirements(chara,stat_requirement.luck)
	results["agi_req"] = get_requirements(chara,stat_requirement.agility)
	results["mag_req"] = get_requirements(chara,stat_requirement.magic_pow)
	results["dex_req"] = get_requirements(chara,stat_requirement.dexterity)
	results["stamina_req"] = get_final_cost(chara)
	
	var str_req_sati : bool = (chara.strength >= results["str_req"])
	var vit_req_sati : bool = (chara.vitality >= results["vit_req"])
	var luc_req_sati : bool = (chara.luck >= results["luc_req"])
	var agi_req_sati : bool = (chara.agility >= results["agi_req"])
	var mag_req_sati : bool = (chara.magic_pow >= results["mag_req"])
	var dex_req_sati : bool = (chara.dexterity >= results["dex_req"])
	var stamina_req_sati : bool = (chara.max_stamina >= results["stamina_req"])
	results["req_met"] = str_req_sati && vit_req_sati && luc_req_sati && agi_req_sati && mag_req_sati && dex_req_sati && stamina_req_sati
	return results
