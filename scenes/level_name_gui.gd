extends HBoxContainer
@export var current_character : battle_character_data
@export var show_level_up : bool = true
signal update_party_members()

func update_level(character : battle_character_data):
	$Level.text = "[center]Lv." + str(character.current_level) + "[/center]"

func on_character_load(character : battle_character_data) -> void:
	current_character = character
	if GlobalVariables.is_player_team(current_character):
		$Name.text = "[center][color=" + character.assigned_data.character_colour.to_html() + "]" + character.name + "[/color][/center]"
	else:
		$Name.text = "[center]" + character.name + "[/center]"
	$Level.text = "[center]Lv." + str(character.current_level) + "[/center]"
	if show_level_up:
		$InBattle.visible = true
	else:
		$InBattle.visible = false
		
	if GlobalVariables.is_player_team(current_character):
		check_party_member_enabled()
	
func enable_disable_partymember():
	if GlobalVariables.get_enabled_party_members_count() > 1:
		GlobalVariables.enabled_party_members[current_character] = !GlobalVariables.enabled_party_members[current_character]
	else:
		if !GlobalVariables.enabled_party_members[current_character]:
			GlobalVariables.enabled_party_members[current_character] = !GlobalVariables.enabled_party_members[current_character]
	check_party_member_enabled()
	
func check_party_member_enabled():
	if GlobalVariables.enabled_party_members.find_key(current_character) != -1:
		var enabled_member = GlobalVariables.enabled_party_members[current_character]
		if enabled_member:
			$InBattle.modulate = Color.PALE_GREEN
			$InBattle.text = "Enabled"
		else:
			$InBattle.modulate = Color.PALE_VIOLET_RED
			$InBattle.text = "Disabled"
	update_party_members.emit()
