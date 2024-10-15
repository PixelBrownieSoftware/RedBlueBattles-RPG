extends HBoxContainer
var chara : battle_character_data
signal level_up_update(character : battle_character_data)

# Called when the node enters the scene tree for the first time.
func display_exp_req(character : battle_character_data):
	chara = character
	var exp = "[img=30]sprites/GUI/gui_luc.png[/img]"
	var able_to_level_up = character.expereince_to_NL <= GlobalVariables.expereince_score
	var enough = "Costs "+ exp + "[color=green]" + str(character.expereince_to_NL) + "[/color]"  if able_to_level_up else exp + "[color=red]" + str(character.expereince_to_NL - GlobalVariables.expereince_score) + " needed![/color]" 
	$ExpToNextLevel.text = enough
	$LevelUpButton.disabled = !able_to_level_up

func level_up():
	chara.level_up()
	display_exp_req(chara)
	level_up_update.emit(chara)
