extends Node
@onready var globals : battle_variables = get_node("..")

func get_targets_from_move(skill : rpg_skill):
	var targets : Array[battle_character_data]
	#TODO: Check if the user is in the party memebers team
	var active_party_members = GlobalVariables.get_characters(PartyMembers)
	var active_enemy_members = GlobalVariables.get_characters(EnemyMembers)
	match skill.skill_scope:
		skill.SCOPE.SELF:
			targets.append(globals.current_character)
		skill.SCOPE.ALLY:
			if GlobalVariables.is_player_team(globals.current_character):
				targets.append_array(active_party_members)
			else:
				targets.append_array(active_enemy_members)
		skill.SCOPE.FOE:
			if GlobalVariables.is_player_team(globals.current_character):
				targets.append_array(active_enemy_members)
			else:
				targets.append_array(active_party_members)
		skill.SCOPE.ALL:
			targets.append_array(active_party_members)
			targets.append_array(active_enemy_members)
		-1:
			globals.targets.clear()
	if targets.size() > 0:
		for targ : battle_character_data in targets:
			if targ.health <= 0:
				targets.erase(targ)
	globals.targets = targets
