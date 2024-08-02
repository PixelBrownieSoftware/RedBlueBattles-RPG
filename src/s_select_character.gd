extends battle_state
class_name select_character

func start_state():
	$"../../Target Menu".show()
	for button in $"../../Target Menu".get_children():
		pass#button.selected_character = 
	
