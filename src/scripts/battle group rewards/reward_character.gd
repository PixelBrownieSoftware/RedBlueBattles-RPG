extends battle_group_reward
class_name reward_character
@export var character : battle_character_base
@export_range(1,30) var level : int = 1

func give_reward():
	super()
	CharacterFactory.create_new_character(character,PartyMembers, level)

func display_reward() -> String:
	return "[color=" + character.character_colour.to_html() + "]" + character.name + "[/color]"

func return_message() -> String:
	return "[color=" + character.character_colour.to_html() + "]" + character.name + "[/color] has joined the party!"
