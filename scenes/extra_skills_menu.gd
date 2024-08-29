extends Control
@export var chara : battle_character_data
var selected_skill : rpg_skill
var buttons : Array[Button]
signal close_party_menu()

func open_menu(character : battle_character_data):
	chara = character
	close_party_menu.emit()
	for button_horiz in get_child(0).get_children():
		for button in button_horiz.get_children():
			buttons.append(button)
			button.visible = false
	update_skills()
	visible = true
	
func update_skills():
	var skill_ind : int = 0
	$"Extra skills limit/limit".text = "Extra skills slots left: " + str(GlobalVariables.extra_skills_limit - chara.extra_skills.size())
	for skill in GlobalVariables.extra_skills:
		var button = buttons[skill_ind]
		if chara.get_natural_skills.rfind(skill) != -1:
			button.disabled = true
		else:
			button.disabled = false
		
		button.selected_skill = skill
		button.character = chara
		button.load_skill.connect(add_skill)
		button.text = skill.name
		button.visible = true
		skill_ind += 1
		
func display_skills():
	var description : String = ""
	description += "Name: " + selected_skill.name
	var character_skill_assigned : battle_character_data = GlobalVariables.equipped_extra_skills[selected_skill.name]
	if character_skill_assigned != null:
		var character_colour = character_skill_assigned.assigned_data.character_colour
		description += " ([color=" + character_colour.to_html()+ "]" + GlobalVariables.equipped_extra_skills[selected_skill.name].name+ "[/color])"
	description += "\n"
	description += "Stat requirements:" + "\n"
	var req_met = selected_skill.requirements_met(chara)

	if req_met["str_req"] > 0:
		description += display_stat("Strength",req_met["str_req"] , chara.strength)
	if req_met["vit_req"] > 0:
		description += display_stat("Vitality", req_met["vit_req"], chara.vitality)
	if req_met["dex_req"] > 0:
		description += display_stat("Dexterity", req_met["dex_req"], chara.dexterity)
	if req_met["agi_req"] > 0:
		description += display_stat("Agility", req_met["agi_req"], chara.agility)
	if req_met["mag_req"] > 0:
		description += display_stat("Magic power", req_met["mag_req"], chara.magic_pow)
	if req_met["luc_req"] > 0:
		description += display_stat("Luck", req_met["luc_req"], chara.luck)
	$"MoveDesc/move desk text".text = description
	if req_met["req_met"]:
		$"MoveDesc/Equip skill".disabled = false
	else:
		$"MoveDesc/Equip skill".disabled = true

func display_stat(stat_name, stat_req, user_stat) -> String:
	var disp = stat_name + ": " + str(stat_req) + " needed. Has: " + str(user_stat)
	var colour : Color = Color.RED
	if user_stat >= stat_req:
		colour = Color.GREEN 
	return "[color=" +str(colour.to_html())+"]" + disp + "[/color]"  + "\n"
	
func add_skill(move):
	selected_skill = move
	display_skills()

func assign_skill():
	var skill_limit_exceeded = GlobalVariables.extra_skills_limit == chara.extra_skills.size()
	if skill_limit_exceeded:
		if GlobalVariables.equipped_extra_skills[selected_skill.name] != chara:
			return
	GlobalVariables.assign_skill(chara,selected_skill)
	display_skills()
	update_skills()
