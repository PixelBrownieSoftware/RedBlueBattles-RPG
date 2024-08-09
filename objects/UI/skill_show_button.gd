extends Button
@export var selected_skill : rpg_skill
signal load_skill(skill : rpg_skill)

func _on_pressed():
	load_skill.emit(selected_skill)
