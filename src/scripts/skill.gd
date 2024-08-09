extends Resource
class_name rpg_skill

enum SCOPE {ALLY, FOE, ALL, NONE = -1}
@export var name : String = "Empty"
@export var learnable : bool = true
@export var power : int = 0
@export var stamina_cost : int = 0
@export var stats : rpg_stats = rpg_stats.new()
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

func requirements_met(chara : battle_character_data) -> bool:
	var str_req : bool = (chara.strength >= stat_requirement.strength)
	var vit_req : bool = (chara.vitality >= stat_requirement.vitality)
	var luc_req : bool = (chara.luck >= stat_requirement.luck)
	var ag_req : bool = (chara.agility >= stat_requirement.agility)
	var mag_req : bool = (chara.magic_pow >= stat_requirement.magic_pow)
	var dex_req : bool = (chara.dexterity >= stat_requirement.dexterity)
	return str_req && vit_req && luc_req && ag_req && mag_req && dex_req

