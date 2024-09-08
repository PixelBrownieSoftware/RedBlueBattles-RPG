extends Node
class_name global_variables

@export var debug_mode : bool = false
@export var expereince_score : int = 0
var multilplier: float = 1
var extra_skills_limit = 3

func set_multiplier(mul):
	multilplier = mul
	
func reset_multipiler():
	multilplier = 1

@export var extra_skills : Array[rpg_skill]
@export var equipped_extra_skills = {}
@export var enabled_party_members = {}
@export var element_lookup = {}
var current_battle : battle_group_data

func _ready():
	var elements = DirAccess.get_files_at("res://data/elements/")
	for element_obj in elements:
		var el : element = ResourceLoader.load("res://data/elements/" + element_obj)
		element_lookup[el.name] = el
		
func get_element(element_name : String):
	if element_lookup.find_key(element_name) != -1:
		return element_lookup[element_name]
	else:
		return element_lookup["None"]

func is_player_team(char_data : battle_character_data) -> bool:
	var list = PartyMembers.get_children()
	for char in list:
		if char == char_data:
			return true
	return false

func who_has_equippied_skill(skill : rpg_skill):
	return equipped_extra_skills[skill.name]
	
func get_enabled_party_members_count() -> int:
	var number = 0
	for member_enabled in enabled_party_members:
		if enabled_party_members[member_enabled]:
			number += 1
	return number

#Check whether the skill exists in the extra skills bit
func add_extra_skill(skill : rpg_skill) -> bool:
	if extra_skills.rfind(skill) != -1:
		return true
	print(extra_skills.size())
	extra_skills.append(skill)
	equipped_extra_skills[skill.name] = null
	print("Gained " + skill.name + "!")
	print(extra_skills.size())
	return false

#func get_all_chara_exsk(chara : battle_character_data) -> Array[rpg_skill]:
	#var skills : Array[rpg_skill] 
	#for skill in extra_skills:
		#if extra_skills[skill] == chara:
			#skills.append(skill)		
	#return skills
	
func save_data():
	#TODO: SAVE-
	#- party data (stats, level, members)
	#- experience
	#- which extra skills exist and which ones are equippied on who
	#- additional flags (NOT YET IMPLEMENTED)
	pass

func assign_skill(chara : battle_character_data, extra_skill : rpg_skill):
	var ind = chara.extra_skills.rfind(extra_skill)
	var chara_exists = equipped_extra_skills[extra_skill.name]
	if chara_exists:
		ind = chara_exists.extra_skills.rfind(extra_skill)
		chara_exists.extra_skills.remove_at(ind)
		equipped_extra_skills[extra_skill.name] = null
		return
	if ind == -1:
		chara.assign_skill(extra_skill)
		equipped_extra_skills[extra_skill.name] = chara
	else:
		chara.extra_skills.remove_at(ind)
		equipped_extra_skills[extra_skill.name] = null
