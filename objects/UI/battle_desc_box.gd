extends Panel
@export var desc : RichTextLabel
@export var button : Button

func load_battle_level(battle_level : battle_level_group):
	var unlock : Array[String]
	var battle_group = {
		"opp" : {},
		"unl" : unlock,
	}
	button.visible = true
	desc.text = ""
	for gr in battle_level.battle_groups:
		for member in gr.opponents:
			if !battle_group["opp"].find_key(member.character):
				var move_arr : Array[String]
				battle_group["opp"][member.character.name] = {
					"min_lvl": 99999,
					"max_lvl": -99999,
					"moves_to_learn": move_arr
				}
			for move in member.skills:
				if battle_group["opp"][member.character.name]["moves_to_learn"].rfind(move.name) == -1:
					var txt = "[color=" + move.skill_element.colour.to_html() + "]" + move.name + "[/color]"
					battle_group["opp"][member.character.name]["moves_to_learn"].append(txt)
			if battle_group["opp"][member.character.name]["min_lvl"] > member.min_level:
				battle_group["opp"][member.character.name]["min_lvl"] =member.min_level
			if battle_group["opp"][member.character.name]["max_lvl"] < member.max_level:
				battle_group["opp"][member.character.name]["max_lvl"] =member.max_level
		for member in gr.rewards:
			if GlobalVariables.check_flag(member.flag_req):
				var txt = member.display_reward()
				battle_group["unl"].append(txt)
					
	desc.text += "[u]" + battle_level.name + "[/u]\n"
	for gr in battle_group["opp"].keys():
		var obj =  battle_group["opp"][gr]
		if obj["min_lvl"] == obj["max_lvl"]:
			desc.text += gr + " Lv." + str(obj["min_lvl"]) + '\n'
		else:
			desc.text += gr + " Lv." + str(obj["min_lvl"]) + " - "+ str(obj["max_lvl"])+ '\n'
		if obj["moves_to_learn"].size() > 0:
			desc.text += "	[b][u]Extra skills[/u][/b]:\n"
			for move in obj["moves_to_learn"]:
				desc.text += "	 - " + move + "\n"
			desc.text += '\n'
	if battle_group["unl"].size() > 0:
		desc.text += '\n[u]Unlockables[/u]\n'
		for gr in battle_group["unl"]:
			desc.text += gr + '\n'
	desc.text +='\n' + "[u]Next level(s):" + '\n'
	for level in battle_level.battle_groups_unlock:
		var level_colour : Color = Color.WHITE
		match level.type_battle:
			battle_level_group.battle_type.NORMAL:
				level_colour = Color.WHITE
			battle_level_group.battle_type.EASY:
				level_colour = Color.ROSY_BROWN
			battle_level_group.battle_type.MEDIUM:
				level_colour = Color.SILVER
			battle_level_group.battle_type.HARD:
				level_colour = Color.GOLD
			battle_level_group.battle_type.BOSS:
				level_colour = Color.MEDIUM_PURPLE
			battle_level_group.battle_type.MINI_BOSS:
				level_colour = Color.ORANGE
		
		desc.text += "[color=" + level_colour.to_html() + "]" + level.name + '[/color]\n' 
