extends Node
class_name battle_character_data
@export var current_level : int = 1
@export var expereince_to_NL : int = 1

@export var max_health : int = 1
@export var health : int = 1
@export var max_stamina : int:
	get:
		return assigned_data.stamina
@export var stamina : int = 1
@export var extra_skills : Array[rpg_skill]

@export var strength : int = 1
@export var vitality : int = 1
@export var magic_pow : int = 1
@export var dexterity : int = 1
@export var agility : int = 1
@export var luck : int = 1
var default_attack : rpg_skill = preload("res://data/Skills/attack.tres")
var pass_turn : rpg_skill = preload("res://data/Skills/pass.tres")

@export var get_skills : Array[rpg_skill]:
	get:
		var skills_arr : Array[rpg_skill]
		skills_arr.push_front(default_attack)
		for original_skill : rpg_skill in assigned_data.skills:
			if original_skill.requirements_met(self):
				skills_arr.push_back(original_skill)
		for skill : rpg_skill in GlobalVariables.get_all_chara_exsk(self):
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

@export var stats2 : rpg_stats
@export var assigned_data : battle_character_base

signal play_damage_sound()
signal defeat_event()

func assign_signal(function : Callable):
	play_damage_sound.connect(function)

func new_data(base_data : battle_character_base, level):
	assigned_data = base_data
	max_health = base_data.health
	health = max_health
	expereince_to_NL = base_data.base_exp_to_NL
	strength = base_data.stats.strength
	vitality = base_data.stats.vitality
	magic_pow = base_data.stats.magic_pow
	dexterity = base_data.stats.dexterity
	agility = base_data.stats.agility
	luck = base_data.stats.luck
	current_level = level
	for l in level:
		level_up()

func assign_skill(move : rpg_skill):
	extra_skills.append(move)

func level_up():
	var skills_before : Array[rpg_skill] = get_skills
	max_health += assigned_data.stat_increase.health_min + randi() % assigned_data.stat_increase.health_max
	strength += 1 if fmod(assigned_data.stat_increase.strength * float(current_level), 1) == 0 else 0
	vitality += 1 if fmod(assigned_data.stat_increase.vitality * float(current_level), 1) == 0 else 0
	magic_pow += 1 if fmod(assigned_data.stat_increase.magic_pow * float(current_level), 1) == 0 else 0
	dexterity += 1 if fmod(assigned_data.stat_increase.dexterity * float(current_level), 1) == 0 else 0
	agility +=  1 if fmod(assigned_data.stat_increase.agility * float(current_level), 1) == 0 else 0
	luck += 1 if fmod(assigned_data.stat_increase.luck * float(current_level), 1) == 0 else 0
	for move in assigned_data.skills:
		if move.requirements_met(self) && !skills_before.rfind(move):
			print(name + " learned " + move.name + "!")
	expereince_to_NL += expereince_to_NL * 1.3
	health = max_health

func damage_character(attacker: battle_character_data, skill :rpg_skill) -> int:
	var damage_amount : int
	damage_amount = (attacker.strength * skill.power) / vitality
	damage(damage_amount)
	return damage_amount

func damage(dmg : int):
	health -= dmg
	play_damage_sound.emit()
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
	
