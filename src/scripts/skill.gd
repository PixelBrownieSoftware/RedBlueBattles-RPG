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
@export var custom_icon : Texture2D

func get_desc(chara : battle_character_data) -> String:
	var desc : String
	var final_st = get_final_cost(chara)
	var element_icon = ""
	if skill_element.icon != null:
		element_icon = " [img=20]" + skill_element.icon.resource_path + "[/img]"
	desc +="[color=" + skill_element.colour.to_html() + "]" + name + "[/color]" +element_icon+ "\n"
	if power > 0:
		desc += "Power: " + str(power) + "\n"
	if stamina_cost > 0:
		if final_st != stamina_cost:
			var cost_colour = Color.GREEN if stamina_cost > final_st else Color.RED
			desc += "Stamina Cost: [s]" + str(stamina_cost) + "[/s] ([" + "color=" + cost_colour.to_html() + "]" + str(final_st) + "[/color])" + "\n"
		else:
			desc += "Stamina Cost: " + str(stamina_cost) + "\n"
	#if skill_element.name != "None":
		#desc += "Element: [img=16]" + skill_element.icon.resource_path + "[/img] [color=" + skill_element.colour.to_html() + "]" + skill_element.name + "[/color]\n"
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
			desc += "	-[img=16]" + status.status.icon.resource_path + "[/img] " + status.status.name + " (" + str(status.chance * 100) + "%)\n"
	if effects_to_add.size() > 0:
		desc += "Status inflict:\n"
		for status in effects_to_add:
			desc += "	-[img=16]"+ status.status.icon.resource_path+ "[/img] " + status.status.name + " (" + str(status.chance * 100) + "%)\n"
	
	desc +="\n"
	return desc

func get_all_status_inflicts():
	pass
func get_all_status_effects():
	var status_array : Array[status_effect]
	for status in effects_to_add:
		status_array.append(status.status)
	for status in skill_element.effects_to_add:
		status_array.append(status.status)
	return status_array

func damage_formula(attacker: battle_character_data, target: battle_character_data) -> int:
	var modifiers = attacker.get_element_potential_modifiers(self)
	print("Multiplier " + str(modifiers["damage_multipler"]))
	
	var str = (attacker.strength_net * skill_element.stats.strength)
	var agi = (attacker.agility_net * skill_element.stats.agility)
	var vit = (attacker.vitality_net * skill_element.stats.vitality)
	var mag = (attacker.magic_pow_net * skill_element.stats.magic_pow)
	var dex = (attacker.dexterity_net * skill_element.stats.dexterity)
	var luc = (attacker.luck_net * skill_element.stats.luck)
	var stat_element = ((str+ dex + luc + agi + mag + vit)/6) * (power)
	var elem_aff = target.get_elemental_affinity(skill_element)
	return (((stat_element * power) / target.vitality_net ) * modifiers["damage_multipler"]) * elem_aff

func process_damage(attacker: battle_character_data, target: battle_character_data):
	var calculated_Press_Turn
	var return_val = {}
	var damage_amount : int = damage_formula(attacker, target)

	var dodge_chance : float = attacker.dexterity_net
	var will_hit = target.stat_chance(attacker.dexterity_net, target.agility_net, 0.95)
	
	var is_lucky = target.stat_chance(attacker.luck_net, target.luck_net, 0.1)
	var calculated_PT : PRESS_TURN.PT = PRESS_TURN.PT.NORMAL
	var el_affinity : float = target.get_elemental_affinity(skill_element)
	if el_affinity >= 2:
		calculated_PT = PRESS_TURN.PT.WEAK
	else: if el_affinity < 2 && el_affinity > 0:
		calculated_PT = PRESS_TURN.PT.NORMAL
	else: if el_affinity == 0:
		damage_amount = 0
		calculated_PT = PRESS_TURN.PT.VOID
	else: if el_affinity < 0:
		calculated_PT = PRESS_TURN.PT.REFLECT
	if calculated_PT < PRESS_TURN.PT.VOID:
		if is_lucky && el_affinity >= 1:
			damage_amount *= 1.4
			if calculated_PT == PRESS_TURN.PT.WEAK:
				calculated_PT = PRESS_TURN.PT.WEAK_LUCKY
			else:
				calculated_PT = PRESS_TURN.PT.LUCKY
			#target.put_damage_numbers.emit(attacker, self, damage_amount, calculated_PT)
	if power == 0 || skill_element.name == "None":	#crude assumption of status move
		will_hit = 99
		calculated_PT = PRESS_TURN.PT.NORMAL
	if !will_hit:
		damage_amount = 0
		calculated_PT = PRESS_TURN.PT.MISS
		#target.put_damage_numbers.emit(attacker, self, damage_amount, calculated_PT)
	else:
		if calculated_PT != PRESS_TURN.PT.VOID:
			status_apply(target)
		calculated_Press_Turn = calculated_PT
		if power > 0:
			if calculated_PT != PRESS_TURN.PT.VOID:
				target.damage(damage_amount)
	return_val["Press_turn"] = calculated_PT
	return_val["Amount"] = damage_amount
	return_val["No_Anim"] = 0	#Damage number stuff
	return return_val

func status_apply(target: battle_character_data):
	target.apply_status_effects(skill_element.effects_to_add)
	target.remove_status_effects(skill_element.effects_to_remove)
	target.apply_status_effects(effects_to_add)
	target.remove_status_effects(effects_to_remove)

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
	
func requirements_met_simulated(chara : battle_character_data, stats):
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
	
	var str_req_sati : bool = (stats["strength"] >= results["str_req"])
	var vit_req_sati : bool = (stats["vitality"] >= results["vit_req"])
	var luc_req_sati : bool = (stats["luck"] >= results["luc_req"])
	var agi_req_sati : bool = (stats["agility"] >= results["agi_req"])
	var mag_req_sati : bool = (stats["magic_pow"] >= results["mag_req"])
	var dex_req_sati : bool = (stats["dexterity"] >= results["dex_req"])
	var stamina_req_sati : bool = (stats["max_stamina"] >= results["stamina_req"])
	results["req_met"] = str_req_sati && vit_req_sati && luc_req_sati && agi_req_sati && mag_req_sati && dex_req_sati && stamina_req_sati
	return results
	
func on_select():
	pass
	
func on_back():
	pass

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
