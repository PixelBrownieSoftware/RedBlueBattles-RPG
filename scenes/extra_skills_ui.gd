extends ScrollContainer

var current_character : battle_character_data
var selected_skill : rpg_skill
var buttons : Array[Button]
signal close_party_menu()
signal toggle_skill(current_character : battle_character_data)
var button_prefab = preload("res://objects/UI/skill_menu_button.tscn")
@export var move_description : RichTextLabel
@export var assign_button : Button
@export var remove_button : Button
@export var description : RichTextLabel

func open_menu(character : battle_character_data):
	current_character = character
	close_party_menu.emit()
	for button_horiz in get_child(0).get_children():
		for button in button_horiz.get_children():
			buttons.append(button)
			button.visible = false
	update_skills()
	reset_description()
	visible = true
	
func reset_description():
	assign_button.visible = false
	description.text = "Click a skill on the left and click the assign button to add it to [color=" + current_character.assigned_data.character_colour.to_html() + "]" + current_character.name + "[/color]'s equpped skills!"

func reset_description_remove():
	assign_button.visible = false
	remove_button.visible = false
	description.text = "Click a skill on the right and click the remove button if you want to remove it from [color=" + current_character.assigned_data.character_colour.to_html() + "]" + current_character.name + "[/color]'s equpped skills!"
	
func update_skills():
	var skill_ind : int = 0
	#$"Extra skills limit/limit".text = "Extra skills slots left: " + str(GlobalVariables.extra_skills_limit - chara.extra_skills.size())
	for button in get_child(0).get_children():
		button.visible = false
	for skill in GlobalVariables.extra_skills:
		if GlobalVariables.extra_skill_already_equipped(skill):
			continue
		if current_character.extra_skills.rfind(skill) != -1:
			continue
		var button = get_child(0).get_child(skill_ind)
		if button == null:
			var button_skill = button_prefab.instantiate()
			get_child(0).add_child(button_skill)
			button = button_skill
		if current_character.get_natural_skills.rfind(skill) != -1:
			button.disabled = true
		else:
			button.disabled = false
		
		button.selected_skill = skill
		#button.character = chara
		
		button.text = skill.name
		button.selected_skill = skill
		button.assign_skill(current_character)
		#button.connect("load_skill",change_text)
		button.load_skill.connect(add_skill)
		button.text = skill.name
		button.visible = true
		skill_ind += 1
		
func display_skills():
	var description : String = ""
	var character_skill_assigned : battle_character_data = GlobalVariables.equipped_extra_skills[selected_skill.name]
	#if character_skill_assigned != null:
		#var character_colour = character_skill_assigned.assigned_data.character_colour
		#description += " ([color=" + character_colour.to_html()+ "]" + GlobalVariables.equipped_extra_skills[selected_skill.name].name+ "[/color])"
	description += selected_skill.get_desc(current_character)
	description += "\n"
	description += "Stat requirements:" + "\n"
	var req_met = selected_skill.requirements_met(current_character)

	if req_met["str_req_og"] > 1:
		description += display_stat(
			GlobalVariables.stat_colour(stats_name.STATS.STRENGTH)
		,req_met["str_req"] , current_character.strength)
	if req_met["vit_req_og"] > 1:
		description += display_stat(
			GlobalVariables.stat_colour(stats_name.STATS.VITALITY), 
		req_met["vit_req"], current_character.vitality)
	if req_met["dex_req_og"] > 1:
		description += display_stat(
			GlobalVariables.stat_colour(stats_name.STATS.DEXTERITY), 
		req_met["dex_req"], current_character.dexterity)
	if req_met["agi_req_og"] > 1:
		description += display_stat(
			GlobalVariables.stat_colour(stats_name.STATS.AGILITY), 
			req_met["agi_req"], current_character.agility)
	if req_met["mag_req_og"] > 1:
		description += display_stat(
			GlobalVariables.stat_colour(stats_name.STATS.MAGIC), 
		req_met["mag_req"], current_character.magic_pow)
	if req_met["luc_req_og"] > 1:
		description += display_stat(
			GlobalVariables.stat_colour(stats_name.STATS.LUCK)
			, req_met["luc_req"], current_character.luck)
	move_description.text = description
	assign_button.visible = true
	remove_button.visible = false
	if req_met["req_met"]:
		assign_button.disabled = false
	else:
		assign_button.disabled = true
	if GlobalVariables.extra_skill_already_equipped(selected_skill):
		assign_button.visible = false

func display_stat(stat_name, stat_req, user_stat) -> String:
	var disp = stat_name + ": " + str(stat_req) + " needed. Has: " + str(user_stat)
	var colour : Color = Color.RED
	if user_stat >= stat_req:
		colour = Color.GREEN 
	return "[color=" +str(colour.to_html())+"]" + disp + "[/color]"  + "\n"
	
func add_skill(move):
	selected_skill = move
	display_skills()

func remove_skill():
	GlobalVariables.assign_skill(current_character,selected_skill)
	reset_description()

func assign_skill():
	var skill_limit_exceeded = GlobalVariables.extra_skills_limit == current_character.extra_skills.size()
	if skill_limit_exceeded:
		if GlobalVariables.equipped_extra_skills[selected_skill.name] != current_character:
			return
	GlobalVariables.assign_skill(current_character,selected_skill)
	reset_description_remove()
	update_skills()
	toggle_skill.emit(current_character)
