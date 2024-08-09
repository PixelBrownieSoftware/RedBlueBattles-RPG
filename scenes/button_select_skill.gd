extends Button
class_name button_select_skill

var selected_skill : rpg_skill
var character : battle_character_data
signal load_skill(skill : rpg_skill)

func _on_pressed():
	load_skill.emit(selected_skill)

func _process(delta):
	if character != null:
		var already_equipped_by_someone_else =  GlobalVariables.equipped_extra_skills[selected_skill.name] != null
		
		if character.extra_skills.rfind(selected_skill) != -1 || already_equipped_by_someone_else:
			modulate = Color.RED
		else:
			modulate = Color.AQUA
