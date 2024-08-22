extends Node
@onready var globals : battle_variables = get_node("..")

func get_targets_from_move(skill : rpg_skill):
	var targets : Array[battle_character_data]
	#TODO: Check if the user is in the party memebers team
	match skill.skill_scope:
		skill.SCOPE.ALLY:
			if globals.is_player_team(globals.current_character):
				targets.append_array(PartyMembers.get_children())
			else:
				targets.append_array(EnemyMembers.get_children())
		skill.SCOPE.FOE:
			if GlobalVariables.is_player_team(globals.current_character):
				targets.append_array(EnemyMembers.get_children())
			else:
				targets.append_array(PartyMembers.get_children())
		skill.SCOPE.ALL:
			targets.append_array(PartyMembers.get_children())
			targets.append_array(EnemyMembers.get_children())
		-1:
			globals.targets.clear()
	if targets.size() > 0:
		for targ : battle_character_data in targets:
			if targ.health == 0:
				targets.erase(targ)
	globals.targets = targets
