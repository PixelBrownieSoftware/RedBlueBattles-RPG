extends VBoxContainer
var current_character : battle_character_data

func load_character(character: battle_character_data):
	var button = $Skill_lvl/skill_menu_button
	current_character = character
	for lev in range(50):
		var unlearned_skills = character.simulate_level_up(lev)["unlearned_skills"]
		if unlearned_skills.size() > 0:
			var skill : rpg_skill = unlearned_skills[0]
			button.text = skill.name
			button.selected_skill = skill
			button.assign_skill(character)
			button.connect("load_skill",change_text)
			button.visible = true
			$Header/RichTextLabel.text = "Next skill: Lv." + str(lev)
			return
	$Header/RichTextLabel.text = "Next skill: None"
	button.visible = false
	
func change_text(skill: rpg_skill):
	$"../SkillsSectionH/SkillDesc".text = skill.get_desc(current_character)
