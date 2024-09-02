extends Resource
class_name status_effect

@export var name : String
@export var turn_duration : int
@export var effects_to_remove : Array[status_effect]
@export var elemental_affinity_change : Array[elemental_affinity]
@export var stat_changes : rpg_stats
@export var icon : Texture2D

@export var round_start : bool = false
@export var after_action : bool = false
@export var turn_start : bool = false

func find_elemental_change(el : element) -> float:
	for elemental in elemental_affinity_change:
		if elemental.elemental == el:
			return elemental.affinity
	return 0

func _on_round_start(chara : battle_character_data):
	if !round_start:
		return
	turn_duration -= 1
	
func _on_after_action(chara : battle_character_data):
	if !after_action:
		return
	turn_duration -= 1
	
func _on_turn_start(chara : battle_character_data):
	if !turn_start:
		return
	turn_duration -= 1
