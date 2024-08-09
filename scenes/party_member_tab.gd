extends TabBar
class_name party_member_tab
var current_character : battle_character_data
signal go_to_ex_skills(character)

func go_to_extra_skills():
	go_to_ex_skills.emit(current_character)
	load_skill_buttons()

func load_skill(skill):
	$SkillDesc.text = skill.get_desc()
	
func load_skill_buttons():
	for button in $Panel/ScrollContainer/VBoxContainer.get_children():
		button.visible = false
	var index : int = 0
	for skill in current_character.get_skills:
		#Yeah, I know there are less crude ways to do this, but it's only one action!
		if skill.name == "Attack":
			continue
		var button = $Panel/ScrollContainer/VBoxContainer.get_child(index)
		button.text = skill.name
		button.selected_skill = skill
		button.visible = true
		index += 1
		
func level_up():
	GlobalVariables.expereince_score -= current_character.expereince_to_NL
	current_character.level_up()
	load_skill_buttons()

func _process(delta):
	if current_character != null:
		$Panel/Name.text = current_character.name
		$Panel/Health.text = "HP: "+  str(current_character.max_health)
		$Panel/Expereince/ExpToNextLevel.text = str(current_character.expereince_to_NL)
		$Panel/Expereince/LevelUpButton.disabled = current_character.expereince_to_NL > GlobalVariables.expereince_score
		$Panel/Level.text = "Lv." + str(current_character.current_level)
		$Panel/VBoxContainer/Strength.render_stamina_max(current_character.strength, 10)
		$Panel/VBoxContainer/Vitality.render_stamina_max(current_character.vitality, 10)
		$Panel/VBoxContainer/Dexterity.render_stamina_max(current_character.dexterity, 10)
		$Panel/VBoxContainer/Magpow.render_stamina_max(current_character.magic_pow, 10)
		$Panel/VBoxContainer/Agility.render_stamina_max(current_character.agility, 10)
	



func _on_tab_selected(tab):
	load_skill_buttons()
