extends ScrollContainer
var current_character : battle_character_data
@export var skill_description : RichTextLabel

func load_skill_buttons(character : battle_character_data):
	current_character = character
	for button in $VBoxContainer.get_children():
		button.visible = false
	var index : int = 0
	for skill in character.get_skills:
		var button = $VBoxContainer.get_child(index)
		button.text = skill.name
		button.selected_skill = skill
		button.assign_skill(character)
		button.connect("load_skill",change_text)
		button.visible = true
		index += 1

func change_text(skill: rpg_skill):
	skill_description.text = skill.get_desc(current_character)
