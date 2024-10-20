extends Node
class_name exp_watcher
@export var multiplier : float = 1
var local_exp_score : int = 0
signal set_multiplier(mult)
@export var score_GUI :RichTextLabel
@export var score_add_GUI:RichTextLabel

func _ready():
	set_multiplier.connect(GlobalVariables.set_multiplier)

func increase_multiplier(amount):
	multiplier += amount

func exp_points_calc(user : battle_character_data, target : battle_character_data, damage : int, press_turn: PRESS_TURN.PT):
	#TODO: make the fomrmula 
	# (dmg/target.max_health) * (user.level/target.level) * target.base_exp_score
	if !GlobalVariables.is_player_team(user):
		return
	match press_turn:
		PRESS_TURN.PT.LUCKY:
			multiplier += 1.5
		PRESS_TURN.PT.WEAK:
			multiplier += 1
	var dmg_perc : float = ((float)(damage)/(float)(target.max_health))
	var lvl_perc : float = ((float)(target.current_level)/(float)(user.current_level))
	var total : int = ((dmg_perc * lvl_perc) * target.assigned_data.base_exp_score)
	print(lvl_perc)
	print(dmg_perc)
	local_exp_score += total * multiplier
	set_multiplier.emit(multiplier)
	if multiplier > 1:
		score_add_GUI.text = "+ " + str(total) + " (" + str(total * multiplier) + ")"
	else:
		score_add_GUI.text = "+ " + str(total)
		
	score_GUI.text = "[img=45]sprites/GUI/gui_luc.png[/img]" + str(local_exp_score) + " x " + str(multiplier)
	
	
	
	
#TODO:
# - keep score of the actions of every party member
# - when the battle ends, make it so that the party members gain their scores
# - have a multiplier that is shared between party members and multiplies their score

#SCORE REWARDS:
# - exploiting weaknesses (1+ multiplier with each exploit)
# - doing damage
# - if a party member is alive in the end of a fight, they gain 2x more EXP
