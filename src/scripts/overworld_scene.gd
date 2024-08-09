extends Node2D
@export var battle_scene : String
@export var starters : Array[battle_character_base]
@export var selected_group : battle_group_data
var party_member_menu = preload("res://objects/UI/party_member_menu.tscn")

func _ready():
	#print(preload("looney.tres"))
	main_menu()
	await FadeScene.fade_bg(Color(Color.BLACK, 0), 0.5)
	if PartyMembers.get_child_count() == 0:
		for ch in starters:
			CharacterFactory.create_new_character(ch,PartyMembers, 1)
	for member : battle_character_data in PartyMembers.get_children():
		var tab : party_member_tab = party_member_menu.instantiate()
		tab.current_character = member
		tab.name = member.name
		tab.go_to_ex_skills.connect($ExtraSkillsMenu.open_menu)
		tab.load_skill_buttons()
		$PartyMemberTabs.add_child(tab)
	debug_stuff()
	
func close_party_menu():
	$PartyMemberTabs.visible = false
	$BackToMenu.visible = false
	
func debug_stuff():
	var chara : battle_character_data = PartyMembers.get_child(0)
	GlobalVariables.add_extra_skill(preload("res://data/Skills/icicle.tres"))
	GlobalVariables.add_extra_skill(preload("res://data/Skills/double_smack.tres"))
	#GlobalVariables.get_all_chara_exsk(chara)

func main_menu():
	$MenuBar/HBoxContainer/Party.visible = true
	#$"MenuBar/HBoxContainer/To battle".visible = true
	$PartyMemberTabs.visible = false
	$ExtraSkillsMenu.visible = false
	$EnemySelectTabs.visible = true
	$BackToMenu.visible = false
	$MenuBar/HBoxContainer/Party.visible = true

func load_battle(selected_group):
	$"MenuBar/HBoxContainer".visible = false
	for battle_character_member : battle_group_member in selected_group.opponents:
		var level : int =  randi() % battle_character_member.max_level + battle_character_member.min_level
		var character : battle_character_data = CharacterFactory.create_new_character(battle_character_member.character,EnemyMembers , level)
		for skill in battle_character_member.skills:
			character.assign_skill(skill)
	await FadeScene.fade_bg(Color.BLACK, 0.7)
	get_tree().change_scene_to_file(battle_scene)

func load_party():
	#TODO: We should play an animation rather than crudely disabling and enabling menus
	$EnemySelectTabs.visible = false
	$PartyMemberTabs.visible = true
	for tab in $PartyMemberTabs.get_children():
		tab.load_skill_buttons()
	$BackToMenu.visible = true
	$MenuBar/HBoxContainer/Party.visible = false
	$ExtraSkillsMenu.visible = false
