extends Panel
var character_button = preload("res://objects/UI/character_button.tscn")
var has_selected_character : bool = false	#A kludge to not having an infinite recursion

func update_party():
	var contianer_childeren = $ScrollContainer/VBoxContainer.get_children()
	for member in PartyMembers.get_children():
		var button : character_button =$ScrollContainer/VBoxContainer.get_child(member.get_index())
		if button == null:
			var new_button : character_button = character_button.instantiate()
			$ScrollContainer/VBoxContainer.add_child(new_button)
			button = new_button
		button.text = member.name
		button.selected_character = member
		button.modulate= Color.WHITE
		if GlobalVariables.enabled_party_members[member]:
			button.text = member.name + " ✔️"
		else:
			button.text = member.name + " ❌"
		button.load_character.connect($"../StatsStuff/PartyMember/Stats/StatsOrder/Left side/Main Stats/StatVsplitter/StatSplitter/StatsContent".on_character_load)
		button.load_character.connect($"../StatsStuff/Panel/LevelName".on_character_load)
		button.load_character.connect($"../StatsStuff/PartyMember/Stats/StatsOrder/Left side/Main Stats/StatVsplitter/StatSplitter/Expereince".display_exp_req)
		button.load_character.connect($"../StatsStuff/PartyMember/Stats/StatsOrder/Left side/Affinities/Affinity".display_character_aff)
		button.load_character.connect($"../StatsStuff/PartyMember/Stats/StatsOrder/Right side/Potential/Potential".display_character_aff)
		button.load_character.connect($"../StatsStuff/PartyMember/Stats/StatsOrder/Right side/Skills/SkillsSectionH/SkillsSection/Skills".load_skill_buttons)
		button.load_character.connect($"../StatsStuff/PartyMember/Stats/StatsOrder/Right side/Skills/NextSkill".load_character)
		button.load_character.connect($"../StatsStuff/PartyMember/Extra skills/HBoxContainer/EquippedSkills/EqSkills".load_skill_buttons)
		button.load_character.connect($"../StatsStuff/PartyMember/Extra skills/HBoxContainer/ExSkills/VBoxContainer/ExtraSkills".open_menu)
		for stat in $"../StatsStuff//PartyMember/Stats/StatsOrder/Left side/Stats".get_children():
			if stat is stat_display:
				button.load_character.connect(stat.on_character_load)
	if !has_selected_character:
		has_selected_character = true
		$ScrollContainer/VBoxContainer.get_child(0).ivoke_function()
	
