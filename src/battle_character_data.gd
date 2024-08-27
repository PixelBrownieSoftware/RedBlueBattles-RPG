extends Node
class_name battle_character_data
const divider : float = 8.4
@export var current_level : int = 1
@export var expereince_to_NL : int = 1

@export var max_health : int = 1
@export var health : int = 1
@export var max_stamina : int:
	get:
		return assigned_data.stamina
@export var stamina : int = 0
@export var extra_skills : Array[rpg_skill]

@export var strength : int = 1
@export var vitality : int = 1
@export var magic_pow : int = 1
@export var dexterity : int = 1
@export var agility : int = 1
@export var luck : int = 1
var pass_turn : rpg_skill = preload("res://data/Skills/Misc/pass.tres")

@export var get_skills : Array[rpg_skill]:
	get:
		var skills_arr : Array[rpg_skill]
		for original_skill : rpg_skill in assigned_data.skills:
			if original_skill.requirements_met(self):
				skills_arr.push_back(original_skill)
		for skill : rpg_skill in extra_skills:
			if skill.requirements_met(self):
				skills_arr.push_back(skill)
		print(skills_arr)
		return skills_arr
		
@export var get_learnable_skills: Array[rpg_skill]:
	get:
		var skills_arr : Array[rpg_skill] = get_skills
		var skills_arr_new : Array[rpg_skill]
		for skill : rpg_skill in skills_arr:
			if skill.learnable:
				skills_arr_new.append(skill)
		return skills_arr_new

#@export var stats2 : rpg_stats
@export var assigned_data : battle_character_base

signal play_damage()
signal miss_effect()
signal defeat_event()
signal on_character_start_turn()
signal on_character_end_turn()

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
	expereince_to_NL += expereince_to_NL * (2.5 * (0.85**current_level))
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
	
	var str = (attacker.strength * skill.skill_element.stats.strength)/divider
	var agi = (attacker.agility * skill.skill_element.stats.agility)/divider
	var vit = (attacker.vitality * skill.skill_element.stats.vitality)/divider
	var mag = (attacker.magic_pow * skill.skill_element.stats.magic_pow)/divider
	var dex = (attacker.dexterity * skill.skill_element.stats.dexterity)/divider
	var luc = (attacker.luck * skill.skill_element.stats.luck)/divider
	var stat_element = ((str+ dex + luc + agi + mag + vit)) * (skill.power)
	
	damage_amount = ((stat_element * skill.power) / vitality) * modifiers["damage_multipler"]
	var dodge_chance : float = attacker.dexterity
	var will_hit = stat_chance(attacker.dexterity, agility, 0.85)
	var is_lucky = stat_chance(attacker.luck, luck, -0.8)
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
	if !will_hit:
		damage_amount = 0
		calculated_PT = PRESS_TURN.PT.MISS
	else:
		damage(damage_amount)
	return_val["Press_turn"] = calculated_PT
	return_val["Amount"] = damage_amount
	return return_val
	
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
	play_damage.emit()
	health = clampi(health,0 , max_health)
	if health == 0:
		defeat_event.emit()
	
func change_stamina(dmg : int):
	stamina += dmg
	stamina = clampi(stamina,0 , max_stamina)
	
func get_elemental_affinity(el : element) -> float:
	for elemental in assigned_data.elemental_affinities:
		if el == elemental.elemental:
			return elemental.affinity
	return 1.0
	
func get_elemental_potential(el : element) -> int:
	for elemental in assigned_data.elemental_potential:
		if el == elemental.elemental:
			return elemental.potential
	return 0
