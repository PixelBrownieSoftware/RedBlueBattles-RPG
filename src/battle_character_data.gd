extends Node
class_name battle_character_data
const divider : float = 8.4
@export var current_level : int = 1
@export var expereince_to_NL : int = 1

@export var max_health : int = 1
@export var health : int = 1
@export var max_stamina : int = 1
@export var stamina : int = 0
@export var extra_skills : Array[rpg_skill]

@export var strength : int = 1
@export var vitality : int = 1
@export var magic_pow : int = 1
@export var dexterity : int = 1
@export var agility : int = 1
@export var luck : int = 1

@export var strength_net : int:
	get:
		var str = strength
		for effect in status_effects:
			str += effect.stat_changes.strength
		return str
@export var vitality_net : int:
	get:
		var vit = vitality
		for effect in status_effects:
			vit += effect.stat_changes.vitality
		return vit	
@export var magic_pow_net : int:
	get:
		var mag = magic_pow
		for effect in status_effects:
			mag += effect.stat_changes.magic_pow
		return mag		
@export var dexterity_net : int:
	get:
		var dex = dexterity
		for effect in status_effects:
			dex += effect.stat_changes.dexterity
		return dex
@export var agility_net : int:
	get:
		var agi = agility
		for effect in status_effects:
			agi += effect.stat_changes.agility
		return agi
@export var luck_net : int:
	get:
		var luc = luck
		for effect in status_effects:
			luc += effect.stat_changes.luck
		return luc

var pass_turn : rpg_skill = preload("res://data/Skills/Misc/pass.tres")
@export var get_natural_skills : Array[rpg_skill]:
	get:
		var skills_arr : Array[rpg_skill]
		for original_skill : rpg_skill in assigned_data.skills:
			if original_skill.requirements_met(self)["req_met"]:
				skills_arr.push_back(original_skill)
		return skills_arr
		
@export var get_skills : Array[rpg_skill]:
	get:
		var skills_arr : Array[rpg_skill]
		for original_skill : rpg_skill in assigned_data.skills:
			if original_skill.requirements_met(self)["req_met"]:
				skills_arr.append(original_skill)
		for skill : rpg_skill in extra_skills:
			if skill.requirements_met(self)["req_met"]:
				skills_arr.append(skill)
		return skills_arr
		
@export var get_learnable_skills: Array[rpg_skill]:
	get:
		var skills_arr : Array[rpg_skill] = get_skills
		var skills_arr_new : Array[rpg_skill]
		for skill : rpg_skill in skills_arr:
			if skill.learnable:
				skills_arr_new.append(skill)
		return skills_arr_new

@export var status_effects : Array[status_effect]
@export var assigned_data : battle_character_base
@export var override_behaviour : Array[battle_move_behaviour]

#A dirty little hack for making it so that it displays a weak
var calculated_Press_Turn

signal play_damage()
signal increase_multiplier(amount)
signal add_status_effect(status_fx)
signal update_status_effect(status_fx)
signal remove_status_effect(status_fx)
signal miss_effect()
signal defeat_event()
signal on_character_start_turn()
signal on_character_end_turn()
signal put_damage_numbers(user,targ,dmg, pt)

func assign_add_status_signal(function : Callable):
	add_status_effect.connect(function)
	
func assign_remove_status_signal(function : Callable):
	remove_status_effect.connect(function)

func assign_update_status_signal(function : Callable):
	update_status_effect.connect(function)
	
func assign_signal(function : Callable):
	play_damage.connect(function)

func assign_start_turn_signal(function : Callable):
	on_character_start_turn.connect(function)

func assign_end_turn_signal(function : Callable):
	on_character_end_turn.connect(function)
	
func new_data(base_data : battle_character_base, level):
	assigned_data = base_data
	max_health = base_data.health
	health = max_health
	stamina = 0
	max_stamina = assigned_data.stamina
	expereince_to_NL = base_data.base_exp_to_NL
	strength = base_data.stats.strength
	vitality = base_data.stats.vitality
	magic_pow = base_data.stats.magic_pow
	dexterity = base_data.stats.dexterity
	agility = base_data.stats.agility
	luck = base_data.stats.luck
	for l in level - 1:
		level_up()

func assign_skill(move : rpg_skill):
	var met_requirements = move.requirements_met(self)
	var already_exists = assigned_data.skills.rfind(move) != -1
	if met_requirements && !already_exists:
		extra_skills.append(move)

func level_up():
	var skills_before : Array[rpg_skill] = get_skills
	current_level += 1
	for increase_stamina in assigned_data.stamina_increase_levels:
		if increase_stamina == current_level:
			max_stamina += 1
	max_health += assigned_data.stat_increase.health_min + randi() % assigned_data.stat_increase.health_max
	#print(fmod(assigned_data.stat_increase.strength * float(current_level), 1))
	strength += increase_stat(assigned_data.stat_increase.strength)#if fmod(assigned_data.stat_increase.strength * float(current_level), 1) == 0 else 0
	vitality += increase_stat(assigned_data.stat_increase.vitality)
	magic_pow += increase_stat(assigned_data.stat_increase.magic_pow)
	dexterity += increase_stat(assigned_data.stat_increase.dexterity)
	agility +=  increase_stat(assigned_data.stat_increase.agility)
	luck += increase_stat(assigned_data.stat_increase.luck)
	for move in assigned_data.skills:
		if move.requirements_met(self) && !skills_before.rfind(move):
			print(name + " learned " + move.name + "!")
	expereince_to_NL += expereince_to_NL * (assigned_data.exp_req_multipler * (0.8**current_level))
	health = max_health
	
func increase_stat(stat_increase : float) -> int:
	var prev =  floor(stat_increase * float(current_level - 1))
	var now = floor(stat_increase * float(current_level))
	var result = now - prev
	if result >= 1:
		return 1
	return 0

func get_element_potential_modifiers(skill :rpg_skill):
	var modifiers = {}
	modifiers["stamina_discount"] = 0
	modifiers["damage_multipler"] = 1.0
	modifiers["requirement_discount"] = 0
	var potential = get_elemental_potential(skill.skill_element)
	match potential:
		6:
			modifiers["stamina_discount"] = -3
			modifiers["damage_multipler"] = 1.7
			modifiers["requirement_discount"] = -6
		5:
			modifiers["stamina_discount"] = -2
			modifiers["damage_multipler"] = 1.6
			modifiers["requirement_discount"] = -5
		4:
			modifiers["stamina_discount"] = -2
			modifiers["damage_multipler"] = 1.55
			modifiers["requirement_discount"] = -4
		3:
			modifiers["stamina_discount"] = -1
			modifiers["damage_multipler"] = 1.35
			modifiers["requirement_discount"] = -3
		2:
			modifiers["stamina_discount"] = -1
			modifiers["damage_multipler"] = 1.2
			modifiers["requirement_discount"] = -2
		1:
			modifiers["stamina_discount"] = 0
			modifiers["damage_multipler"] = 1.1
			modifiers["requirement_discount"] = -1
		-1:
			modifiers["stamina_discount"] = 1
			modifiers["damage_multipler"] = 0.95
			modifiers["requirement_discount"] = 1
		-2:
			modifiers["stamina_discount"] = 1
			modifiers["damage_multipler"] = 0.8
			modifiers["requirement_discount"] = 2
		-3:
			modifiers["stamina_discount"] = 2
			modifiers["damage_multipler"] = 0.75
			modifiers["requirement_discount"] = 3
		-4:
			modifiers["stamina_discount"] = 2
			modifiers["damage_multipler"] = 0.6
			modifiers["requirement_discount"] = 4
		-5:
			modifiers["stamina_discount"] = 2
			modifiers["damage_multipler"] = 0.6
			modifiers["requirement_discount"] = 5
		-6:
			modifiers["stamina_discount"] = 3
			modifiers["damage_multipler"] = 0.55
			modifiers["requirement_discount"] = 6
	return modifiers


func damage_character(attacker: battle_character_data, skill :rpg_skill):
	var return_val = {}
	var damage_amount : int
	
	var modifiers = attacker.get_element_potential_modifiers(skill)
	print("Multiplier " + str(modifiers["damage_multipler"]))
	
	var str = (attacker.strength_net * skill.skill_element.stats.strength)
	var agi = (attacker.agility_net * skill.skill_element.stats.agility)
	var vit = (attacker.vitality_net * skill.skill_element.stats.vitality)
	var mag = (attacker.magic_pow_net * skill.skill_element.stats.magic_pow)
	var dex = (attacker.dexterity_net * skill.skill_element.stats.dexterity)
	var luc = (attacker.luck_net * skill.skill_element.stats.luck)
	var stat_element = ((str+ dex + luc + agi + mag + vit)/6) * (skill.power)
	
	damage_amount = ((stat_element * skill.power) / vitality_net) * modifiers["damage_multipler"]
	var dodge_chance : float = attacker.dexterity_net
	var will_hit = stat_chance(attacker.dexterity_net, agility_net, 0.95)
	if skill.power == 0 || skill.skill_element.name == "None":	#crude assumption of status move
		will_hit = 99
	var is_lucky = stat_chance(attacker.luck_net, luck_net, -0.8)
	var calculated_PT : PRESS_TURN.PT = PRESS_TURN.PT.NORMAL
	var el_affinity : float = get_elemental_affinity(skill.skill_element)
	if el_affinity >= 2:
		calculated_PT = PRESS_TURN.PT.WEAK
	else: if el_affinity < 2 && el_affinity > 0:
		calculated_PT = PRESS_TURN.PT.NORMAL
	else: if el_affinity == 0:
		damage_amount = 0
		calculated_PT = PRESS_TURN.PT.VOID
	else: if el_affinity < 0 && el_affinity > -2:
		calculated_PT = PRESS_TURN.PT.REFLECT
	else:
		calculated_PT = PRESS_TURN.PT.ABSORB
	if calculated_PT < PRESS_TURN.PT.VOID:
		if is_lucky:
			damage_amount *= 1.4
			calculated_PT = PRESS_TURN.PT.LUCKY
			put_damage_numbers.emit(attacker, self, damage_amount, calculated_PT)
	if !will_hit:
		damage_amount = 0
		calculated_PT = PRESS_TURN.PT.MISS
		put_damage_numbers.emit(attacker, self, damage_amount, calculated_PT)
	else:
		apply_status_effects(skill.skill_element.effects_to_add)
		remove_status_effects(skill.skill_element.effects_to_remove)
		apply_status_effects(skill.effects_to_add)
		remove_status_effects(skill.effects_to_remove)
		calculated_Press_Turn = calculated_PT
		if skill.power > 0:
			damage(damage_amount)
	return_val["Press_turn"] = calculated_PT
	return_val["Amount"] = damage_amount
	return return_val

func update_current_status_effects(function: String):
	calculated_Press_Turn = PRESS_TURN.PT.NORMAL
	for status in status_effects:
		match function:
			"after_action":
				status._on_after_action(self)
				update_status_effect.emit(status)
			"round_start":
				status._on_round_start(self)
				update_status_effect.emit(status)
			"turn_start":
				status._on_turn_start(self)
				update_status_effect.emit(status)
		if status.turn_duration == 0:
			remove_status_effect.emit(status)
			status_effects.remove_at(status_effects.rfind(status))
			
func apply_status_effects(effects : Array[status_effect_chance]):

	for status in effects:
		var inflict_chance = status.chance
		var will_inflcit : float = randf()
		if will_inflcit < inflict_chance:
			var found_existing_status = status_effects.filter(func(thing):return status.status.name == thing.name)
			if found_existing_status.size() == 0:
				var status_instance = status.status.duplicate()
				add_status_effect.emit(status_instance)
				status_effects.push_front(status_instance)
				if !GlobalVariables.is_player_team(self):
					if status.status.contribute_multipler:
						increase_multiplier.emit(0.25)
				await get_tree().create_timer(0.5).timeout
				print(name + " got " + status.status.name)
			
func remove_status_effects(effects : Array[status_effect]):
	for status in effects:
		var status_found = status_effects.rfind(status)
		if status_found != -1:
			status_effects.remove_at(status_found)

func has_status(status : status_effect) -> bool:
	for stat in status_effects:
		if stat.name == status.name:
			return true
	return false

func stat_chance(user_val : int, targ_val : int, connect_max : float):
	var total : int = user_val + targ_val
	var user_modify: float = user_val * (float)(user_val * connect_max)
	var attack_connect_chance : float = (user_modify/total)
	#print("Connection: " + str(attack_connect_chance))
	var will_hit : float = randf()
	#print("Roll: " + str(will_hit))
	if will_hit > attack_connect_chance:
		return false
	return true


func damage(dmg : int):
	health -= dmg
	put_damage_numbers.emit(null, self, dmg, calculated_Press_Turn)
	play_damage.emit()
	health = clampi(health,-999 , max_health)
	if health <= 0:
		defeat_event.emit()
	
func change_stamina(dmg : int):
	stamina += dmg
	stamina = clampi(stamina,0 , max_stamina)
	
func get_elemental_affinity(el : element) -> float:
	var elemental_aff : float = 1
	for elemental in assigned_data.elemental_affinities:
		var element_look = GlobalVariables.get_element(elemental.elementalName)
		if el == element_look:
			elemental_aff = elemental.affinity
	for eff in status_effects:
		elemental_aff += eff.find_elemental_change(el)
	return elemental_aff
	
func get_base_elemental_affinity(el : element) -> float:
	for elemental in assigned_data.elemental_affinities:
		var element_look = GlobalVariables.get_element(elemental.elementalName)
		if el == element_look:
			return elemental.affinity
	return 1.0
	
func get_elemental_potential(el : element) -> int:
	for elemental in assigned_data.elemental_potential:
		if el == elemental.elemental:
			return elemental.potential
	return 0
