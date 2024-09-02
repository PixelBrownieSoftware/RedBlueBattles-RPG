extends battle_state

@export var select_move_state : battle_state
@export var queue : Array[battle_character_data]

signal turn_icon_handle(ind, type)

func start_character(character : battle_character_data):
	add_to_queue(character)
	print(character.name)
	if character.health > 0:
		turn_icon_handle.emit(battle_globals.turn, "appear")
		battle_globals.turn += 1
		character.change_stamina(2)
		character.update_current_status_effects("round_start")
		await get_tree().create_timer(0.2).timeout

func start_state():
	if battle_globals.net_turn == 0:
		queue.clear()
		battle_globals.is_player_turn = !battle_globals.is_player_turn
		if battle_globals.is_player_turn:
			for character in PartyMembers.get_children():
				await start_character(character)
		else:
			for character in EnemyMembers.get_children():
				await start_character(character)
	
	battle_globals.current_character = queue[0]
	use_turn()
	while battle_globals.current_character.health <= 0:
		battle_globals.current_character = queue[0]
		use_turn()
	battle_globals.current_character.update_current_status_effects("turn_start")
	change_state.emit(select_move_state)

func add_to_queue(character_data):
	queue.push_back(character_data)

func use_turn():
	var chara = queue.pop_front()
	add_to_queue(chara)
