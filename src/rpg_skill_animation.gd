extends Resource
class_name rpg_skill_animation

enum SKILL_ANIMATION_TYPE {
	CALCULATION,
	MOVE_TO,
	ANIMATION,
	WAIT
}
@export var skill_animation : SKILL_ANIMATION_TYPE
@export var time_amount : float = -1.0
@export var animation_name : String 
