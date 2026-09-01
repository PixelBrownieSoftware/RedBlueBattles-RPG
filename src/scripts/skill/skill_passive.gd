@tool
extends rpg_skill
class_name skill_passive

@export var elemental_affinity_change : Array[elemental_affinity]
@export var stat_changes : rpg_stats
@export_range(0,2.0, 0.01) var life_percentage : float
