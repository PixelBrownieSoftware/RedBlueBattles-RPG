extends Node
class_name global_variables

@export var debug_mode : bool = false
@export var expereince_score : int = 0
var multilplier: float = 1
var extra_skills_limit = 3
@export var strength_colour : Color
@export var vitality_colour : Color
@export var dexterity_colour : Color
@export var magic_colour : Color
@export var agility_colour : Color
@export var luck_colour : Color

func set_multiplier(mul):
	multilplier = mul
	
func reset_multipiler():
	multilplier = 1

@export var extra_skills : Array[rpg_skill]
@export var global_flags = {
	"greenler_defeated" : false,
	"beno_defeated" : false,
	"lord_red_defeated" : false,
	"malculus_defeated" : false,
	"greendori_defeated" : false,
	"daleth_defeated" : false,
	"blueler_unlocked" : false,
	"anne_unlocked" : false
}	#string and bool
@export var equipped_extra_skills = {}
@export var enabled_party_members = {}
@export var element_lookup = {}
@export var status_effect_lookup = {}
@export var skill_uid_lookup = {}	#This is specifically for save data
@export var character_uid_lookup = {}	#This is specifically for save data
var current_battle : battle_group_data

func _ready():
	#You have no idea how long it took for me to figure this out
	ProjectSettings.load_resource_pack("res://RB_Battles.pck")
	var elements
	if OS.is_debug_build():
		print("FUCK")
		elements = DirAccess.get_files_at("res://data/elements/")#elements = ResourceLoader.load("res://data/elements/")#
		for element_obj in elements:
			var el : element = ResourceLoader.load("res://data/elements/" + element_obj)
			element_lookup[el.name] = el
	else:
		elements = DirAccess.get_files_at("res://data/elements/")
		for element_obj in elements:
			print(element_obj)
			var el : element = ResourceLoader.load("res://data/elements/" + unfuck_file_name(element_obj))
			element_lookup[el.name] = el
	load_all_skills()
	load_all_charcters()
	load_all_status()

func set_flag(flag : global_flag) -> void:
	global_flags[flag.name] = flag.flag
func set_flag_raw(flag_name : String, flag : bool) -> void:
	global_flags[flag_name] = flag
func check_flag(flag : global_flag) -> bool:
	return global_flags[flag.name] == flag.flag

#godot likes to do this stupid .remap shit with the resource files when compiled
func unfuck_file_name(file_name : String) -> String:
	if file_name.matchn("*.tres.remap"):
		file_name = file_name.replace(".remap", "")
	return file_name
	
func load_all_status():
	var status_effects = DirAccess.get_files_at("res://data/status effects/")
	for status_name in status_effects:
		print(status_name)
		var status : status_effect = ResourceLoader.load("res://data/status effects/" + unfuck_file_name(status_name))
		status_effect_lookup[status.name] = status
					
func load_all_skills():
	var dir = DirAccess.get_directories_at("res://data/Skills/")
	for folder in dir:
		var moves = DirAccess.get_files_at("res://data/Skills/" + folder)
		for move_name in moves:
			var loc = "res://data/Skills/" + folder + "/" + unfuck_file_name(move_name)
			var loc_OG = "res://data/Skills/" + folder + "/" + move_name
			var move : rpg_skill = ResourceLoader.load(loc)
			var uid = ResourceLoader.get_resource_uid(loc_OG)
			skill_uid_lookup[move.name] = uid
			print("Filename " + "res://data/Skills/" + folder + "/" + unfuck_file_name(move_name))
			print("Loaded skill ID: " + str(skill_uid_lookup[move.name]))
			

func load_all_charcters():
	var dir = DirAccess.get_directories_at("res://data/characters/")
	for folder in dir:
		var characters = DirAccess.get_files_at("res://data/characters/" + folder)
		for character_name in characters:
			var loc = "res://data/characters/" + folder + "/" + unfuck_file_name(character_name)
			var character : battle_character_base = ResourceLoader.load(loc)
			#print(str(ResourceLoader.get_resource_uid(loc)))
			character_uid_lookup[character.name] = ResourceLoader.get_resource_uid(loc)
			print("Looaded character ID: " + str(character_uid_lookup[character.name]))
		

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

func stat_colour(stat_name : stats_name.STATS) -> String:
	match stat_name:
		stats_name.STATS.STRENGTH:
			return "[color=" + strength_colour.to_html() + "]Strength[/color]"
		stats_name.STATS.VITALITY:
			return "[color=" + vitality_colour.to_html() + "]Vitality[/color]"
		stats_name.STATS.DEXTERITY:
			return "[color=" + dexterity_colour.to_html() + "]Dexterity[/color]"
		stats_name.STATS.AGILITY:
			return "[color=" + agility_colour.to_html() + "]Agility[/color]"
		stats_name.STATS.MAGIC:
			return "[color=" + magic_colour.to_html() + "]Magic[/color]"
		stats_name.STATS.LUCK:
			return "[color=" + luck_colour.to_html() + "]Luck[/color]"
	return ""
