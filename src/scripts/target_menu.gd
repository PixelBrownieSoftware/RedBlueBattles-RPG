extends Panel

@onready var globals : battle_variables = get_node("../Variables")
signal start_process_state()
signal back_to_attack_menu()
var to_next_state : bool = true

func show_targets():
	print(globals.targets.size())
	for button : button_character in get_child(0).get_children():
		button.visible = false
	if globals.targets.size() == 0:
		on_select_character(null)
		return
	$AnimationPlayer.play("menu_show")
		
func back():
	to_next_state = false
	$AnimationPlayer.play("menu_hide")

func on_select_character(character):
	to_next_state = true
	$"../Analyse".force_off()
	globals.target_character = character
	$AnimationPlayer.play("menu_hide")


func _on_animation_player_animation_finished(anim_name):
	if anim_name == "menu_show":
		var index = 0
		for targ in globals.targets:
			if targ.health > 0:
				var targ_button = get_child(0).get_child(index)
				targ_button.selected_character = targ
				targ_button.show_hp()
				targ_button.text = targ.name
				targ_button.show_anim()
			index += 1
		$"../Analyse".visible = true
		$"../Character stats".visible = false
	else: if anim_name == "menu_hide":
		if to_next_state:
			start_process_state.emit()
		else:
			back_to_attack_menu.emit()
