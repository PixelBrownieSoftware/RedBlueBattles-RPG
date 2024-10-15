extends ScrollContainer
var current_character : battle_character_data
var button_prefab = preload("res://objects/UI/skill_menu_button.tscn")
@export var move_description : RichTextLabel
@export var remove_button : Button
@export var assign_button : Button
var selected_skill
signal update_others()

func load_skill_buttons(character : battle_character_data):
	current_character = character
	$"../Header/RichTextLabel".text = "Equipped skills (Slots left: " + str(GlobalVariables.extra_skills_limit - current_character.extra_skills.size()) + ")"
	for button in $Skills.get_children():
		button.visible = false
	var index : int = 0
	for skill in character.extra_skills:
		var button = $Skills.get_child(index)
		if button == null:
			button = button_prefab.instantiate()
			$Skills.add_child(button)
		button.text = skill.name
		button.selected_skill = skill
		button.assign_skill(character)
		button.connect("load_skill",change_text)
		button.visible = true
		index += 1

func remove_skill():
	GlobalVariables.remove_skill(current_character, selected_skill)
	remove_button.visible = false
	load_skill_buttons(current_character)
	update_others.emit()

func change_text(skill: rpg_skill):
	remove_button.visible = true
	assign_button.visible = false
	selected_skill = skill
	move_description.text = skill.get_desc(current_character)
