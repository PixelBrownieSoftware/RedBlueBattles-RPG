extends Node2D
@export var battle_scene : String
@export var starters : Array[battle_character_base]
@export var selected_group : battle_group_data
var party_member_menu = preload("res://objects/UI/party_member_menu.tscn")
var previous_menu : String


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
		tab.go_to_ex_skills.connect($MainMenu/ExtraSkillsMenu.open_menu)
		tab.load_skill_buttons()
		$MainMenu/PartyMemberTabs.add_child(tab)
	#debug_stuff()
	
func close_party_menu():
	previous_menu = "extra_menu"
	$MainMenu/AnimationPlayer.play("to_extra_skills")
	#$PartyMemberTabs.visible = false
	#$BackToMenu.visible = false
	
func debug_stuff():
	GlobalVariables.expereince_score = 1000000
	var chara : battle_character_data = PartyMembers.get_child(0)
	var dir = DirAccess.get_directories_at("res://data/Skills/")
	for folder in dir:
		var moves = DirAccess.get_files_at("res://data/Skills/" + folder)
		for move_name in moves:
			var move : rpg_skill = ResourceLoader.load("res://data/Skills/" + folder + "/" + move_name)
			if move.name == "Pass":
				var uid = ResourceLoader.get_resource_uid("res://data/Skills/" + folder + "/" + move_name)
				print(ResourceUID.id_to_text(uid))
			GlobalVariables.add_extra_skill(move)
	#GlobalVariables.get_all_chara_exsk(chara)
	
func load_encyclopedia_menu():
	$MainMenu/AnimationPlayer.play("to_info_menu")
	previous_menu = "info_menu"
	
func load_enemy_menu():
	$MainMenu/AnimationPlayer.play("to_enemy_menu")
	previous_menu = "enemy_menu"

func main_menu():
	#$MenuBar/HBoxContainer/Party.visible = true
	#$"MenuBar/HBoxContainer/To battle".visible = true
	#$MainMenu/PartyMemberTabs.visible = false
	$MainMenu/ExtraSkillsMenu.visible = false
	#$MainMenu/EnemySelectTabs.visible = true
	$MainMenu/AnimationPlayer.play_backwards("to_enemy_menu")
	$BackToMenu.visible = false
	#$MenuBar/HBoxContainer/Party.visible = true

func load_battle(selected_group):
	$"MenuBar/HBoxContainer".visible = false
	for battle_character_member : battle_group_member in selected_group.opponents:
		var rng = RandomNumberGenerator.new()
		rng.randomize()
		var level : int =  rng.randi_range(battle_character_member.min_level, battle_character_member.max_level)
		var character : battle_character_data = CharacterFactory.create_new_character(battle_character_member.character,EnemyMembers , level)
		for skill in battle_character_member.skills:
			character.assign_skill(skill)
	GlobalVariables.current_battle = selected_group
	await FadeScene.fade_bg(Color.BLACK, 0.7)
	get_tree().change_scene_to_file(battle_scene)

func _process(delta):
	var descOverall = "Expereince: " + str(GlobalVariables.expereince_score) + "\n\n"
	if PartyMembers.get_child_count() > 1:
		descOverall += "Active party members: " + "\n"
		for party_member_name in GlobalVariables.enabled_party_members:
			if GlobalVariables.enabled_party_members[party_member_name]:
				descOverall += "[color=" + party_member_name.assigned_data.character_colour.to_html() + "]" + party_member_name.name + "[/color] "
		descOverall +=  "\n"
	$"Exp count".text = descOverall

func load_party():
	#TODO: We should play an animation rather than crudely disabling and enabling menus
	#$EnemySelectTabs.visible = false
	#$PartyMemberTabs.visible = true
	for tab in $MainMenu/PartyMemberTabs.get_children():
		tab.load_skill_buttons()
		tab.toggle_party_member.connect($ActivePartyMembers.toggle_party_member)
	if previous_menu == "extra_menu":
		previous_menu = "player_menu"
		$MainMenu/AnimationPlayer.play_backwards("to_extra_skills")
	else:if previous_menu == "info_menu":
		previous_menu = "player_menu"
		$MainMenu/AnimationPlayer.play_backwards("to_info_menu")
	else:
		$MainMenu/AnimationPlayer.play_backwards("to_enemy_menu")
