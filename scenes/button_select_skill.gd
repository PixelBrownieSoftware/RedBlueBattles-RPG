extends Button
class_name button_select_skill

var selected_skill : rpg_skill
var character : battle_character_data
signal load_skill(skill : rpg_skill)

func _on_pressed():
	load_skill.emit(selected_skill)

func _process(delta):
	if GlobalVariables.get_all_chara_exsk(character).find(selected_skill):
		modulate = Color.RED
	else:
		modulate = Color.AQUA
