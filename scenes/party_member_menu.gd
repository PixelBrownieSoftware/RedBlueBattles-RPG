extends Control
var current_character : battle_character_data
signal go_to_ex_skills(character)

func _ready():
	visible = false
	
func activate():
	current_character = PartyMembers.get_child(0)
	display_character()
	visible = true
	
func go_to_extra_skills():
	go_to_ex_skills.emit(current_character)
	visible = false

func next_character():
	var cur_ind = current_character.get_index()
	cur_ind += 1
	cur_ind = wrapi(cur_ind, 0, PartyMembers.get_child_count())
	current_character = PartyMembers.get_child(cur_ind)
	display_character()
	
func prev_character():
	var cur_ind = current_character.get_index()
	cur_ind -= 1
	cur_ind = wrapi(cur_ind, 0, PartyMembers.get_child_count())
	current_character = PartyMembers.get_child(cur_ind)
	display_character()

func level_up():
	GlobalVariables.expereince_score -= current_character.expereince_to_NL
	current_character.level_up()
	display_character()

func display_character():
	var cur_ind = current_character.get_index()
	if PartyMembers.get_child(cur_ind + 1) != null:
		$"Panel/->".visible = true
	if PartyMembers.get_child(cur_ind - 1) != null:
		$"Panel/<-".visible = true
	$Panel/Name.text = current_character.name
	$Panel/Expereince/ExpToNextLevel.text = str(current_character.expereince_to_NL)
	$Panel/Expereince/LevelUpButton.disabled = current_character.expereince_to_NL > GlobalVariables.expereince_score
	$Panel/Level.text = "Lv." + str(current_character.current_level)
	$Panel/VBoxContainer/Strength.render_stamina_max(current_character.strength, 10)
	$Panel/VBoxContainer/Vitality.render_stamina_max(current_character.vitality, 10)
	$Panel/VBoxContainer/Dexterity.render_stamina_max(current_character.dexterity, 10)
	$Panel/VBoxContainer/Magpow.render_stamina_max(current_character.magic_pow, 10)
	$Panel/VBoxContainer/Agility.render_stamina_max(current_character.agility, 10)
	
