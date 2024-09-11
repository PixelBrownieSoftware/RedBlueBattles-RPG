extends Resource
class_name battle_group_reward

@export var flag_req : global_flag

func give_reward():
	if !GlobalVariables.check_flag(flag_req):
		return
func return_message() -> String:
	return ""
func display_reward() -> String:
	return ""
