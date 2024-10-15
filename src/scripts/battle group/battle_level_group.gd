extends Resource
class_name battle_level_group
@export var name : String
@export var battle_groups : Array[battle_group_data]
@export var self_destruct_after_win = true	#if this is false, it's replayable
@export var battle_groups_unlock : Array[battle_level_group]
@export var battle_groups_remove : Array[battle_level_group]
@export var type_battle : battle_type

enum battle_type {
	BOSS,
	NORMAL,
	MINI_BOSS,
	HARD,
	MEDIUM,
	EASY
}