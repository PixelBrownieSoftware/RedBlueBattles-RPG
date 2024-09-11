extends battle_group_reward
class_name reward_change_flag
@export var flag_change: global_flag

func give_reward():
	super()
	GlobalVariables.set_flag(flag_change)
