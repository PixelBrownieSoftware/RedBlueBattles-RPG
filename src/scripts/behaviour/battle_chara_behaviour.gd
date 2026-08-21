@tool
extends Resource
class_name battle_chara_behaviour
@export var condiitons : Array[battle_character_behaviour]
@export_range(0.0,1.0) var percentage : float
@export var priority : int = 0
