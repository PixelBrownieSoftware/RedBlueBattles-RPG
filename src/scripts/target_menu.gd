extends Panel

@onready var globals : battle_variables = get_node("../../Variables")
signal start_process_state()
signal back_to_attack_menu()
signal show_character_stats(selected_charcter: battle_character_data)
var to_next_state : bool = true
var anim_backwards : bool = false

var is_selecting_characters : bool = false

func show_targets():
	$CharacterInfo.show_menu()
	print(globals.targets.size())
	for button : button_character in get_child(0).get_children():
		button.visible = false
	if globals.targets.size() == 0:
		is_selecting_characters = true
		on_select_character(null)
		return
	anim_backwards= false
	$AnimationPlayer.play("menu_show")
		
func back():
	$CharacterInfo.back()
	for targ in globals.targets:
		globals.get_actor(targ).toggle_highlight(false)
	$CharacterInfo.back()
	to_next_state = false
	anim_backwards= true
	$AnimationPlayer.play_backwards("menu_show")

func on_select_character(character):
	if !is_selecting_characters:
		return
	$CharacterInfo.back()
	
	if !GlobalVariables.check_flag_name("is_analyse_select"):
		for targ in globals.targets:
			globals.get_actor(targ).toggle_highlight(false)
		to_next_state = true
		globals.target_character = character
		anim_backwards= true
		$AnimationPlayer.play_backwards("menu_show")
	else:
		show_character_stats.emit(character)
		$"../Character stats".visible = true

func _on_animation_player_animation_finished(anim_name):
	if anim_name == "menu_show":
		if !anim_backwards:
			#var index = 0
			for targ in globals.targets:
				if targ.health > 0:
					#var targ_button : Button = get_child(0).get_child(index)
					#targ_button.selected_character = targ
					globals.get_actor(targ).toggle_highlight(true)
					#targ_button.position =  globals.get_actor(targ).position + Vector2(85,165) - $"../../BattleCamera2D".position + $"../../BattleCamera2D".offset
					#targ_button.show_hp()
					#targ_button.text = targ.name
					#targ_button.show_anim()
				#index += 1
			is_selecting_characters =  true
			$"../Character stats".visible = false
		else: 
			globals.selected_move.on_back()
			is_selecting_characters =  false
			if to_next_state:
				start_process_state.emit()
			else:
				back_to_attack_menu.emit()
