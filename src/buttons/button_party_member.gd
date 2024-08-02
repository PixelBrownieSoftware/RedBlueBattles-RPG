extends Button

@export var character : battle_character_data
signal load_character(chara)

func open_character():
	load_character.emit(character)
