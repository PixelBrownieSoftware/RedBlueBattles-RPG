extends TabBar
class_name party_member_tab
var current_character : battle_character_data
signal go_to_ex_skills(character)
signal toggle_party_member(member)
@export var in_battle : bool = false

func go_to_extra_skills():
	go_to_ex_skills.emit(current_character)
	load_skill_buttons()

func load_skill(skill):
	$SkillDesc.text = skill.get_desc(current_character)
	
func enable_disable_partymember():
	if GlobalVariables.get_enabled_party_members_count() > 1:
		GlobalVariables.enabled_party_members[current_character] = !GlobalVariables.enabled_party_members[current_character]
	else:
		if !GlobalVariables.enabled_party_members[current_character]:
			GlobalVariables.enabled_party_members[current_character] = !GlobalVariables.enabled_party_members[current_character]
	toggle_party_member.emit(current_character)

func check_party_member_enabled():
	if in_battle:
		return
	if GlobalVariables.enabled_party_members.find_key(current_character) != -1:
		var enabled_member = GlobalVariables.enabled_party_members[current_character]
		if enabled_member:
			$Panel/InBattle.modulate = Color.PALE_GREEN
			$Panel/InBattle.text = "Enabled"
		else:
			$Panel/InBattle.modulate = Color.PALE_VIOLET_RED
			$Panel/InBattle.text = "Disabled"

func load_skill_buttons():
	for button in $Panel/ScrollContainer/VBoxContainer.get_children():
		button.visible = false
	var index : int = 0
	for skill in current_character.get_skills:
		var button = $Panel/ScrollContainer/VBoxContainer.get_child(index)
		button.text = skill.name
		button.selected_skill = skill
		button.assign_skill(current_character)
		button.visible = true
		index += 1
		
func level_up():
	GlobalVariables.expereince_score -= current_character.expereince_to_NL
	current_character.level_up()
	load_skill_buttons()
	SaveSystem.save_game()

func set_elements():
	for potential in $Panel/PA/Potential.get_children():
		potential.character= current_character
		potential.set_potential()
	for affinity in $Panel/PA/Affinity.get_children():
		affinity.character= current_character
		affinity.set_affinity()
const max_stats = 50

func _process(delta):
	if current_character != null:
		$Panel/NLH/Name.text = "[center]" + current_character.name + "[/center]"
		var health_stamina = "[center]"+"Health: "+  str(current_character.max_health) + "[/center]\n"
		health_stamina += "[center]"+"Stamina: "+  str(current_character.max_stamina) + "[/center]"
		$Panel/NLH/Health.text = health_stamina
		if !in_battle:
			$Panel/Expereince/ExpToNextLevel.text = str(current_character.expereince_to_NL)
			$Panel/Expereince/LevelUpButton.disabled = current_character.expereince_to_NL > GlobalVariables.expereince_score
		$Panel/NLH/Level.text = "Lv." + str(current_character.current_level)
		$Panel/Stats/Stats/Strength.render_stamina_max(current_character.strength_net, current_character.strength_net)
		$Panel/Stats/Stats/Vitality.render_stamina_max(current_character.vitality_net, current_character.vitality_net)
		$Panel/Stats/Stats/Dexterity.render_stamina_max(current_character.dexterity_net, current_character.dexterity_net)
		$Panel/Stats/Stats/Magpow.render_stamina_max(current_character.magic_pow_net, current_character.magic_pow_net)
		$Panel/Stats/Stats/Agility.render_stamina_max(current_character.agility_net, current_character.agility_net)
		$Panel/Stats/Stats/Luck.render_stamina_max(current_character.luck_net, current_character.luck_net)
		check_party_member_enabled()
		set_elements()
			
func _on_tab_selected(tab):
	load_skill_buttons()
