extends Node2D
@export var battle_scene : String
@export var starters : Array[battle_character_base]
@export var selected_group : battle_group_data

func _ready():
	#print(preload("looney.tres"))
	main_menu()
	await FadeScene.fade_bg(Color(Color.BLACK, 0), 0.5)
	if PartyMembers.get_child_count() == 0:
		for ch in starters:
			CharacterFactory.create_new_character(ch,PartyMembers, 1)
	#debug_stuff()
	
func debug_stuff():
	var chara : battle_character_data = PartyMembers.get_child(0)
	GlobalVariables.assign_skill(chara,preload("res://data/Skills/icicle.tres"))
	GlobalVariables.assign_skill(chara,preload("res://data/Skills/double_smack.tres"))
	GlobalVariables.get_all_chara_exsk(chara)

func main_menu():
	$MenuBar/HBoxContainer/Party.visible = true
	$"MenuBar/HBoxContainer/To battle".visible = true
	$"PartyMember menu".visible = false
	$ExtraSkillsMenu.visible = false

func load_battle(selected_group):
	$"MenuBar/HBoxContainer".visible = false
	for battle_character_member : battle_group_member in selected_group.opponents:
		CharacterFactory.create_new_character(battle_character_member.character,EnemyMembers , battle_character_member.level)
	await FadeScene.fade_bg(Color.BLACK, 0.7)
	get_tree().change_scene_to_file(battle_scene)

func load_party():
	$MenuBar/HBoxContainer/Party.visible = false
	$"MenuBar/HBoxContainer/To battle".visible = false
	$"PartyMember menu".activate()
