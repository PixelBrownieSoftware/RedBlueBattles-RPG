extends Resource
class_name element
@export var name : String = "Blank"
@export var stats : rpg_stats_increase = rpg_stats_increase.new()
@export var icon : Texture2D	#I'll probably set a default
@export var colour : Color 
@export var effects_to_remove : Array[status_effect]
@export var effects_to_add : Array[status_effect_chance]

func get_coloured_name() -> String:
	return "[color=" + colour.to_html() + "]" + name + "[/color]"
