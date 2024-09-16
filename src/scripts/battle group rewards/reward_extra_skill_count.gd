extends battle_group_reward
class_name reward_extra_skill_count

func give_reward():
	super()
	GlobalVariables.extra_skills_limit += 1

func return_message()-> String:
	return "You can now equip up to " + str(GlobalVariables.extra_skills_limit) + " extra skills!"

func display_reward()-> String:
	return "Be able to equip " + str(GlobalVariables.extra_skills_limit + 1) + " extra skills."
