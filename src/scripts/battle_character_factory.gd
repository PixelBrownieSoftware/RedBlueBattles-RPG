extends Node
class_name battle_character_factory

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func create_new_character(base : battle_character_base, party, level):
	var chara = battle_character_data.new()
	chara.new_data(base, level)
	chara.name = base.name
	party.add_child(chara)
	
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
