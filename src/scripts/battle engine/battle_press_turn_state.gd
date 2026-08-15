extends battle_state
class_name battle_press_turn_state
 
signal turn_icon_handle(ind, type)
@export var queue_state : battle_state

func exploit_weakness():
	if battle_globals.turn > 0:
		battle_globals.pressed_turn += 1
		battle_globals.turn -= 1
		$PressTurnSounds.play()
		turn_icon_handle.emit(battle_globals.turn, "press")
	else:
		battle_globals.pressed_turn -= 1
		turn_icon_handle.emit(battle_globals.pressed_turn, "disappear")

func start_state():
	match battle_globals.final_press_turn_flag:
		PRESS_TURN.PT.NORMAL:
			use_turn()
		PRESS_TURN.PT.WEAK_LUCKY:
			exploit_weakness()
		PRESS_TURN.PT.LUCKY:
			exploit_weakness()
		PRESS_TURN.PT.WEAK:
			exploit_weakness()
		PRESS_TURN.PT.REFLECT:
			for i in range(3):
				if battle_globals.net_turn == 0:
					break
				use_turn()
		PRESS_TURN.PT.MISS:
			for i in range(2):
				if battle_globals.net_turn == 0:
					break
				use_turn()
		PRESS_TURN.PT.VOID:
			for i in range(2):
				if battle_globals.net_turn == 0:
					break
				use_turn()
				
	print("Press turn: " + str(battle_globals.net_turn))
	print("Normal turn: " + str(battle_globals.turn))
	print("Pressed turn: " + str(battle_globals.pressed_turn))
	await get_tree().create_timer(0.2).timeout
	change_state.emit(queue_state)
	
func use_turn():
	if battle_globals.pressed_turn > 0:
		battle_globals.pressed_turn -= 1
		turn_icon_handle.emit(battle_globals.net_turn, "disappear")
	else:if battle_globals.turn > 0:
		battle_globals.turn -= 1
		turn_icon_handle.emit(battle_globals.turn, "disappear")
