extends Button
class_name character_button

@export var selected_character : battle_character_data
signal load_character(character : battle_character_data)

func _pressed() -> void:
	ivoke_function()

func ivoke_function():
	load_character.emit(selected_character)
